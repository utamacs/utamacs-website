import type { IFeatureFlagService, FeatureFlag, ModuleConfiguration } from './interfaces/IFeatureFlagService';

// In-memory cache: societyId → Map<"module:feature", {enabled, roles, expiry}>
interface CacheEntry {
  flags: Map<string, { enabled: boolean; roles: string[] | null }>;
  modules: ModuleConfiguration[];
  expiresAt: number;
}
const CACHE_TTL_MS = 60_000;
const cache = new Map<string, CacheEntry>();

export class FeatureFlagService implements IFeatureFlagService {
  constructor(
    private readonly db: {
      queryFlags: (societyId: string) => Promise<FeatureFlag[]>;
      queryModules: (societyId: string) => Promise<ModuleConfiguration[]>;
      updateFlag: (flagId: string, isEnabled: boolean, updatedBy: string) => Promise<FeatureFlag>;
    },
  ) {}

  private getCache(societyId: string): CacheEntry | null {
    const entry = cache.get(societyId);
    if (!entry || Date.now() > entry.expiresAt) return null;
    return entry;
  }

  private async loadCache(societyId: string): Promise<CacheEntry> {
    const [flags, modules] = await Promise.all([
      this.db.queryFlags(societyId),
      this.db.queryModules(societyId),
    ]);
    const flagMap = new Map<string, { enabled: boolean; roles: string[] | null }>();
    for (const f of flags) {
      flagMap.set(`${f.moduleKey}:${f.featureKey}`, {
        enabled: f.isEnabled,
        roles: f.allowedRoles,
      });
    }
    const entry: CacheEntry = {
      flags: flagMap,
      modules,
      expiresAt: Date.now() + CACHE_TTL_MS,
    };
    cache.set(societyId, entry);
    return entry;
  }

  async isEnabled(societyId: string, moduleKey: string, featureKey: string, userRole?: string): Promise<boolean> {
    let entry = this.getCache(societyId);
    if (!entry) entry = await this.loadCache(societyId);
    const flag = entry.flags.get(`${moduleKey}:${featureKey}`);
    if (!flag || !flag.enabled) return false;
    if (flag.roles && userRole && !flag.roles.includes(userRole)) return false;
    return true;
  }

  async getEnabledFeatures(societyId: string, userRole: string): Promise<FeatureFlag[]> {
    const flags = await this.db.queryFlags(societyId);
    return flags.filter(
      (f) => f.isEnabled && (!f.allowedRoles || f.allowedRoles.includes(userRole)),
    );
  }

  async getModules(societyId: string): Promise<ModuleConfiguration[]> {
    let entry = this.getCache(societyId);
    if (!entry) entry = await this.loadCache(societyId);
    return entry.modules.filter((m) => m.isActive).sort((a, b) => a.displayOrder - b.displayOrder);
  }

  async updateFlag(flagId: string, isEnabled: boolean, updatedBy: string): Promise<FeatureFlag> {
    const updated = await this.db.updateFlag(flagId, isEnabled, updatedBy);
    cache.delete(updated.societyId);
    return updated;
  }

  async guard(societyId: string, moduleKey: string, featureKey: string, userRole: string): Promise<void> {
    const enabled = await this.isEnabled(societyId, moduleKey, featureKey, userRole);
    if (!enabled) {
      const err = Object.assign(new Error(`Feature '${moduleKey}:${featureKey}' is not enabled`), {
        status: 403,
        code: 'FEATURE_DISABLED',
      });
      throw err;
    }
  }

  invalidateCache(societyId: string): void {
    cache.delete(societyId);
  }
}
