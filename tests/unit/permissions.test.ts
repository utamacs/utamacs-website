import { describe, it, expect } from 'vitest';
import {
  DEFAULT_ROLE_PERMISSIONS,
  hasFeature,
  requireFeature,
  requireAdmin,
} from '../../src/lib/permissions';
import type { ResolvedUser, PortalRole } from '../../src/lib/permissions';

// Helper to create a minimal ResolvedUser for testing pure functions
function makeUser(
  portalRole: PortalRole,
  features: string[],
  isAdmin = false,
): ResolvedUser {
  return {
    id: '00000000-0000-0000-0000-000000000001',
    email: 'test@utamacs.org',
    portalRole,
    committeeTitle: null,
    isAdmin,
    societyId: '00000000-0000-0000-0000-000000000001',
    permissions: new Set(features as any),
  };
}

describe('DEFAULT_ROLE_PERMISSIONS', () => {
  it('defines permissions for all 4 roles', () => {
    expect(DEFAULT_ROLE_PERMISSIONS).toHaveProperty('member');
    expect(DEFAULT_ROLE_PERMISSIONS).toHaveProperty('executive');
    expect(DEFAULT_ROLE_PERMISSIONS).toHaveProperty('secretary');
    expect(DEFAULT_ROLE_PERMISSIONS).toHaveProperty('president');
  });

  it('member has base read permissions', () => {
    const memberPerms = DEFAULT_ROLE_PERMISSIONS.member;
    expect(memberPerms).toContain('hoto.view');
    expect(memberPerms).toContain('snag.view');
    expect(memberPerms).toContain('vendor.view');
    expect(memberPerms).toContain('notice.view');
    expect(memberPerms).toContain('gallery.view');
    expect(memberPerms).toContain('maids.approve');
    expect(memberPerms).toContain('feedback.submit');
    expect(memberPerms).toContain('policies.view');
  });

  it('member does NOT have write/manage permissions', () => {
    const memberPerms = DEFAULT_ROLE_PERMISSIONS.member;
    expect(memberPerms).not.toContain('hoto.create');
    expect(memberPerms).not.toContain('notice.send');
    expect(memberPerms).not.toContain('snag.create');
    expect(memberPerms).not.toContain('gallery.manage');
    expect(memberPerms).not.toContain('maids.manage');
    expect(memberPerms).not.toContain('feedback.manage');
    expect(memberPerms).not.toContain('events.manage');
    expect(memberPerms).not.toContain('polls.manage');
    expect(memberPerms).not.toContain('finance.view');
  });

  it('executive has community.moderate and gallery.manage', () => {
    const execPerms = DEFAULT_ROLE_PERMISSIONS.executive;
    expect(execPerms).toContain('community.moderate');
    expect(execPerms).toContain('gallery.manage');
    expect(execPerms).toContain('events.manage');
    expect(execPerms).toContain('polls.manage');
    expect(execPerms).toContain('documents.manage');
    expect(execPerms).toContain('admin.registrations');
    expect(execPerms).toContain('admin.gates');
  });

  it('executive does NOT have finance.view (requires treasurer override)', () => {
    expect(DEFAULT_ROLE_PERMISSIONS.executive).not.toContain('finance.view');
    expect(DEFAULT_ROLE_PERMISSIONS.executive).not.toContain('finance.enter');
  });

  it('secretary has superset of executive permissions', () => {
    const execSet = new Set(DEFAULT_ROLE_PERMISSIONS.executive);
    const secPerms = DEFAULT_ROLE_PERMISSIONS.secretary;
    // Every exec permission should also be in secretary
    for (const perm of execSet) {
      expect(secPerms, `secretary should have ${perm}`).toContain(perm);
    }
  });

  it('secretary has finance permissions that executive lacks', () => {
    const secPerms = DEFAULT_ROLE_PERMISSIONS.secretary;
    expect(secPerms).toContain('finance.view');
    expect(secPerms).toContain('finance.enter');
    expect(secPerms).toContain('finance.approve_10k');
    expect(secPerms).toContain('notice.send');
    expect(secPerms).toContain('users.view_directory');
  });

  it('president has superset of secretary permissions', () => {
    const secSet = new Set(DEFAULT_ROLE_PERMISSIONS.secretary);
    const presPerms = DEFAULT_ROLE_PERMISSIONS.president;
    for (const perm of secSet) {
      expect(presPerms, `president should have ${perm}`).toContain(perm);
    }
  });

  it('president has all approval + admin permissions', () => {
    const presPerms = DEFAULT_ROLE_PERMISSIONS.president;
    expect(presPerms).toContain('hoto.approve_president');
    expect(presPerms).toContain('hoto.approve_secretary');
    expect(presPerms).toContain('hoto.bypass_required_docs');
    expect(presPerms).toContain('snag.delete');
    expect(presPerms).toContain('snag.verify_close');
    expect(presPerms).toContain('vendor.final_select');
    expect(presPerms).toContain('finance.approve_20k');
    expect(presPerms).toContain('users.change_role');
    expect(presPerms).toContain('admin.delegation');
    expect(presPerms).toContain('admin.elections');
    expect(presPerms).toContain('admin.permissions');
  });

  it('no duplicate features in any role', () => {
    for (const [role, perms] of Object.entries(DEFAULT_ROLE_PERMISSIONS)) {
      const unique = new Set(perms);
      expect(unique.size, `${role} has duplicate features`).toBe(perms.length);
    }
  });
});

describe('hasFeature', () => {
  it('returns true when feature is in permissions', () => {
    const user = makeUser('member', ['hoto.view', 'snag.view']);
    expect(hasFeature(user, 'hoto.view')).toBe(true);
    expect(hasFeature(user, 'snag.view')).toBe(true);
  });

  it('returns false when feature is NOT in permissions', () => {
    const user = makeUser('member', ['hoto.view']);
    expect(hasFeature(user, 'snag.create')).toBe(false);
    expect(hasFeature(user, 'finance.view')).toBe(false);
  });

  it('returns false for empty permission set', () => {
    const user = makeUser('member', []);
    expect(hasFeature(user, 'hoto.view')).toBe(false);
  });
});

describe('requireFeature', () => {
  it('does not throw when feature is present', () => {
    const user = makeUser('member', ['hoto.view']);
    expect(() => requireFeature(user, 'hoto.view')).not.toThrow();
  });

  it('throws 403 error when feature is missing', () => {
    const user = makeUser('member', []);
    expect(() => requireFeature(user, 'hoto.view')).toThrow();
    try {
      requireFeature(user, 'hoto.view');
    } catch (e: any) {
      expect(e.status).toBe(403);
      expect(e.code).toBe('FEATURE_FORBIDDEN');
      expect(e.feature).toBe('hoto.view');
    }
  });

  it('error message includes the feature name', () => {
    const user = makeUser('member', []);
    try {
      requireFeature(user, 'finance.view');
    } catch (e: any) {
      expect(e.message).toContain('finance.view');
    }
  });
});

describe('requireAdmin', () => {
  it('does not throw when isAdmin is true', () => {
    const user = makeUser('member', [], true);
    expect(() => requireAdmin(user)).not.toThrow();
  });

  it('throws 403 when isAdmin is false', () => {
    const user = makeUser('member', [], false);
    expect(() => requireAdmin(user)).toThrow();
    try {
      requireAdmin(user);
    } catch (e: any) {
      expect(e.status).toBe(403);
      expect(e.code).toBe('ADMIN_REQUIRED');
    }
  });

  it('even president is denied if isAdmin is false', () => {
    const user = makeUser('president', [], false);
    expect(() => requireAdmin(user)).toThrow();
  });
});
