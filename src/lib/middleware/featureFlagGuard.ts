import { featureFlagService } from '../services/index';

export async function guardFeature(
  societyId: string,
  moduleKey: string,
  featureKey: string,
  userRole: string,
): Promise<void> {
  return featureFlagService.guard(societyId, moduleKey, featureKey, userRole);
}
