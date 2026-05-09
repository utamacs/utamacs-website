import type { UserClaims } from '@lib/services/interfaces/IAuthService';

export type NavRole = 'admin' | 'executive' | 'member' | 'vendor' | 'guard';

// Numeric rank for each nav role. guard and vendor are negative so they never
// satisfy min_nav_role comparisons (they have separate nav branches entirely).
export const NAV_ROLE_RANK: Record<NavRole, number> = {
  guard:     -2,
  vendor:    -1,
  member:     1,
  executive:  2,
  admin:      3,
};

// Canonical sidebar group ordering. Groups not in this list appear last.
export const GROUP_ORDER = [
  'Community',
  'Services',
  'HOTO Platform',
  'Governance',
  'Administration',
] as const;

export function resolveNavRole(user: UserClaims): NavRole {
  if (user.role === 'security_guard') return 'guard';
  if (user.role === 'vendor') return 'vendor';
  if (user.isAdmin || user.role === 'admin') return 'admin';
  if (
    ['executive', 'secretary', 'president'].includes(user.portalRole) ||
    user.role === 'executive'
  ) return 'executive';
  return 'member';
}
