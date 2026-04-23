import { SupabaseAuthService } from './providers/supabase/SupabaseAuthService';
import { SupabaseStorageService } from './providers/supabase/SupabaseStorageService';
import { SupabaseNotificationService } from './providers/supabase/SupabaseNotificationService';
import { AzureAuthService } from './providers/azure/AzureAuthService';
import { AzureStorageService } from './providers/azure/AzureStorageService';
import { AzureSignalRService } from './providers/azure/AzureSignalRService';
import { FeatureFlagService } from './FeatureFlagService';
import { PermissionService } from './PermissionService';
import { getSupabaseServiceClient } from './providers/supabase/SupabaseDB';
import type { IAuthService } from './interfaces/IAuthService';
import type { IStorageService } from './interfaces/IStorageService';
import type { INotificationService } from './interfaces/INotificationService';
import type { IFeatureFlagService } from './interfaces/IFeatureFlagService';

const PROVIDER = process.env.PROVIDER ?? 'supabase';

function makeSupabaseFeatureFlagDB() {
  return {
    async queryFlags(societyId: string) {
      const sb = getSupabaseServiceClient();
      const { data } = await sb.from('feature_flags').select('*').eq('society_id', societyId);
      return (data ?? []).map((r: Record<string, unknown>) => ({
        id: r['id'] as string,
        societyId: r['society_id'] as string,
        moduleKey: r['module_key'] as string,
        featureKey: r['feature_key'] as string,
        isEnabled: r['is_enabled'] as boolean,
        allowedRoles: r['allowed_roles'] as string[] | null,
        configJson: (r['config_json'] ?? {}) as Record<string, unknown>,
      }));
    },
    async queryModules(societyId: string) {
      const sb = getSupabaseServiceClient();
      const { data } = await sb.from('module_configurations').select('*').eq('society_id', societyId);
      return (data ?? []).map((r: Record<string, unknown>) => ({
        id: r['id'] as string,
        societyId: r['society_id'] as string,
        moduleKey: r['module_key'] as string,
        displayName: r['display_name'] as string,
        isActive: r['is_active'] as boolean,
        displayOrder: r['display_order'] as number,
        icon: r['icon'] as string | null,
      }));
    },
    async updateFlag(flagId: string, isEnabled: boolean, updatedBy: string) {
      const sb = getSupabaseServiceClient();
      const { data, error } = await sb
        .from('feature_flags')
        .update({ is_enabled: isEnabled, updated_by: updatedBy, updated_at: new Date().toISOString() })
        .eq('id', flagId)
        .select()
        .single();
      if (error || !data) throw new Error(error?.message ?? 'Update failed');
      return {
        id: data.id,
        societyId: data.society_id,
        moduleKey: data.module_key,
        featureKey: data.feature_key,
        isEnabled: data.is_enabled,
        allowedRoles: data.allowed_roles,
        configJson: data.config_json ?? {},
      };
    },
  };
}

export const authService: IAuthService =
  PROVIDER === 'azure' ? new AzureAuthService() : new SupabaseAuthService();

export const storageService: IStorageService =
  PROVIDER === 'azure' ? new AzureStorageService() : new SupabaseStorageService();

export const notificationService: INotificationService =
  PROVIDER === 'azure' ? new AzureSignalRService() : new SupabaseNotificationService();

export const featureFlagService: IFeatureFlagService = new FeatureFlagService(makeSupabaseFeatureFlagDB());

export const permissionService = new PermissionService();
