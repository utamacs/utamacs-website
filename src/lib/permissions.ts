// Permission resolution for the HOTO platform.
// Implements the three-layer model: role defaults → role DB overrides → user overrides.
// Every API route must call resolveUserPermissions() and check the returned Set.
// UI uses hasFeature() for rendering decisions — these are UX-only; API checks are security.

import { getSupabaseServiceClient } from './services/providers/supabase/SupabaseDB';
import type { Feature } from './features';

export type PortalRole = 'member' | 'executive' | 'secretary' | 'president';

// Hardcoded defaults — authoritative when no DB override exists for a role+feature.
// Mirrors migration 025 seed data exactly. Any change here requires a matching migration.
export const DEFAULT_ROLE_PERMISSIONS: Record<PortalRole, Feature[]> = {
  member: [
    'hoto.view',
    'snag.view',
    'vendor.view', 'vendor.vote',
    'notice.view',
    'gallery.view', 'maids.approve', 'feedback.submit', 'policies.view',
  ],

  executive: [
    'hoto.view', 'hoto.create', 'hoto.upload', 'hoto.comment', 'hoto.advance_status',
    'snag.view', 'snag.create',
    'vendor.view', 'vendor.view_quotes', 'vendor.create', 'vendor.advance_status', 'vendor.vote',
    'notice.view',
    'audit.view',
    // finance.view / finance.enter: NOT included — granted as user_feature_overrides
    // when committee_title = 'Treasurer' or 'Joint Treasurer' is assigned.
    // hoto.approve_president / hoto.approve_secretary: NOT included — granted as
    // user_feature_overrides when delegation is active (§8.2 / §8.4).
    'community.moderate', 'gallery.view', 'gallery.manage',
    'maids.view', 'maids.manage', 'maids.approve',
    'feedback.submit', 'feedback.manage',
    'policies.view', 'policies.manage',
    'documents.manage', 'events.manage', 'polls.manage',
    'admin.registrations', 'admin.gates',
  ],

  secretary: [
    'hoto.view', 'hoto.create', 'hoto.upload', 'hoto.comment', 'hoto.advance_status',
    'hoto.approve_secretary', 'hoto.bypass_required_docs',
    'snag.view', 'snag.create', 'snag.verify_close',
    'vendor.view', 'vendor.view_quotes', 'vendor.create', 'vendor.advance_status', 'vendor.vote',
    'vendor.open_voting', 'vendor.final_select',
    'notice.view', 'notice.send',
    'audit.view',
    'finance.view', 'finance.enter', 'finance.approve_10k',
    // finance.open_board_vote: Secretary opens Board resolution vote (₹20K–₹50K) per §9.3
    'finance.open_board_vote',
    'finance.view_member_phones',
    'users.view_directory', 'users.invite_member', 'users.deactivate',
    'community.moderate', 'gallery.view', 'gallery.manage',
    'maids.view', 'maids.manage', 'maids.approve',
    'feedback.submit', 'feedback.manage',
    'policies.view', 'policies.manage',
    'documents.manage', 'events.manage', 'polls.manage',
    'admin.registrations', 'admin.gates',
  ],

  president: [
    'hoto.view', 'hoto.create', 'hoto.upload', 'hoto.comment', 'hoto.advance_status',
    'hoto.approve_secretary', 'hoto.approve_president', 'hoto.bypass_required_docs',
    'snag.view', 'snag.create', 'snag.verify_close', 'snag.delete',
    'vendor.view', 'vendor.view_quotes', 'vendor.create', 'vendor.advance_status', 'vendor.vote',
    'vendor.open_voting', 'vendor.final_select',
    'notice.view', 'notice.send',
    'audit.view',
    'finance.view', 'finance.enter', 'finance.approve_10k', 'finance.approve_20k',
    'finance.open_board_vote', 'finance.view_member_phones',
    'users.view_directory', 'users.invite_member', 'users.deactivate',
    'users.invite_committee', 'users.change_role',
    'admin.delegation', 'admin.elections', 'admin.permissions', 'admin.import',
    'community.moderate', 'gallery.view', 'gallery.manage',
    'maids.view', 'maids.manage', 'maids.approve',
    'feedback.submit', 'feedback.manage',
    'policies.view', 'policies.manage',
    'documents.manage', 'events.manage', 'polls.manage',
    'admin.registrations', 'admin.gates',
  ],
};

export interface ResolvedUser {
  id: string;
  email: string;
  portalRole: PortalRole;
  committeeTitle: string | null;
  isAdmin: boolean;
  societyId: string;
  permissions: Set<Feature>;
}

// Full permission resolution: role defaults → role DB overrides → user overrides.
// Call this once per request; pass the result to hasFeature().
export async function resolveUserPermissions(
  userId: string,
  societyId: string,
): Promise<ResolvedUser> {
  const sb = getSupabaseServiceClient();

  // 1. Fetch profile (role + title + admin flag) and user_roles in parallel
  const [{ data: profile, error: profileErr }, { data: userRole }] = await Promise.all([
    sb.from('profiles').select('portal_role, committee_title, is_admin').eq('id', userId).single(),
    sb.from('user_roles').select('role').eq('user_id', userId).single(),
  ]);

  if (profileErr || !profile) {
    throw Object.assign(new Error('User profile not found'), { status: 401 });
  }

  const portalRole = (profile.portal_role ?? 'member') as PortalRole;

  // 2. Role-level DB overrides (admin can enable/disable features per role)
  const { data: roleOverrides } = await sb
    .from('feature_permissions')
    .select('feature, enabled')
    .eq('society_id', societyId)
    .eq('role', portalRole);

  // 3. User-specific overrides (non-revoked, non-expired)
  const { data: userOverrides } = await sb
    .from('user_feature_overrides')
    .select('feature, enabled')
    .eq('society_id', societyId)
    .eq('user_id', userId)
    .is('revoked_at', null)
    .or(`expires_at.is.null,expires_at.gt.${new Date().toISOString()}`);

  // 4. Build Set: role defaults → role overrides → user overrides
  const permissions = new Set<Feature>(
    DEFAULT_ROLE_PERMISSIONS[portalRole] ?? [],
  );

  for (const p of roleOverrides ?? []) {
    if (p.enabled) {
      permissions.add(p.feature as Feature);
    } else {
      permissions.delete(p.feature as Feature);
    }
  }

  for (const p of userOverrides ?? []) {
    if (p.enabled) {
      permissions.add(p.feature as Feature);
    } else {
      permissions.delete(p.feature as Feature);
    }
  }

  // 5. Fetch email for the resolved user object (needed by callers)
  const { data: authUser } = await sb.auth.admin.getUserById(userId);

  return {
    id: userId,
    email: authUser?.user?.email ?? '',
    portalRole,
    committeeTitle: profile.committee_title ?? null,
    isAdmin: (profile.is_admin ?? false) || userRole?.role === 'admin',
    societyId,
    permissions,
  };
}

// Check a single feature against a resolved permission set.
export function hasFeature(user: ResolvedUser, feature: Feature): boolean {
  return user.permissions.has(feature);
}

// Throw 403 if the user doesn't have the feature. Use in API routes.
export function requireFeature(user: ResolvedUser, feature: Feature): void {
  if (!hasFeature(user, feature)) {
    throw Object.assign(
      new Error(`Forbidden: ${feature} is not enabled for your role`),
      { status: 403, code: 'FEATURE_FORBIDDEN', feature },
    );
  }
}

// Check if user is admin (is_admin flag, orthogonal to portal_role)
export function requireAdmin(user: ResolvedUser): void {
  if (!user.isAdmin) {
    throw Object.assign(
      new Error('Forbidden: admin access required'),
      { status: 403, code: 'ADMIN_REQUIRED' },
    );
  }
}

// Resolve permissions from a request's session cookie (for API routes).
// Returns null if the token is invalid/missing.
export async function resolveFromRequest(
  request: Request,
  societyId: string,
): Promise<ResolvedUser | null> {
  const cookieHeader = request.headers.get('cookie') ?? '';
  const tokenMatch = cookieHeader.match(/sb-access-token=([^;]+)/);
  if (!tokenMatch) return null;

  const token = tokenMatch[1];
  const sb = getSupabaseServiceClient();
  const { data, error } = await sb.auth.getUser(token);
  if (error || !data.user) return null;

  try {
    return await resolveUserPermissions(data.user.id, societyId);
  } catch {
    return null;
  }
}

// The default society ID for UTA MACS (single-tenant for now)
export const SOCIETY_ID = '00000000-0000-0000-0000-000000000001';
