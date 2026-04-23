export interface FeatureFlag {
  id: string;
  societyId: string;
  moduleKey: string;
  featureKey: string;
  isEnabled: boolean;
  allowedRoles: string[] | null;
  configJson: Record<string, unknown>;
}

export interface ModuleConfiguration {
  id: string;
  societyId: string;
  moduleKey: string;
  displayName: string;
  isActive: boolean;
  displayOrder: number;
  icon: string | null;
}

export interface IFeatureFlagService {
  isEnabled(societyId: string, moduleKey: string, featureKey: string, userRole?: string): Promise<boolean>;
  getEnabledFeatures(societyId: string, userRole: string): Promise<FeatureFlag[]>;
  getModules(societyId: string): Promise<ModuleConfiguration[]>;
  updateFlag(flagId: string, isEnabled: boolean, updatedBy: string): Promise<FeatureFlag>;
  guard(societyId: string, moduleKey: string, featureKey: string, userRole: string): Promise<void>;
  invalidateCache(societyId: string): void;
}
