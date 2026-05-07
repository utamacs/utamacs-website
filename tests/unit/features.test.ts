import { describe, it, expect } from 'vitest';
import { FEATURES, ALL_FEATURES } from '../../src/lib/features';

describe('FEATURES registry', () => {
  it('every feature has a label string', () => {
    for (const [key, def] of Object.entries(FEATURES)) {
      expect(typeof def.label, `${key}.label`).toBe('string');
      expect(def.label.length, `${key}.label is non-empty`).toBeGreaterThan(0);
    }
  });

  it('every feature has a boolean locked field', () => {
    for (const [key, def] of Object.entries(FEATURES)) {
      expect(typeof def.locked, `${key}.locked`).toBe('boolean');
    }
  });

  it('ALL_FEATURES is the full list of feature keys', () => {
    expect(ALL_FEATURES.length).toBe(Object.keys(FEATURES).length);
    for (const key of ALL_FEATURES) {
      expect(FEATURES).toHaveProperty(key);
    }
  });

  it('ALL_FEATURES contains no duplicates', () => {
    const unique = new Set(ALL_FEATURES);
    expect(unique.size).toBe(ALL_FEATURES.length);
  });

  it('known locked features are actually locked', () => {
    // Byelaw-mandated — must always remain locked
    const mustBeLocked = [
      'hoto.approve_president',
      'hoto.approve_secretary',
      'hoto.bypass_required_docs',
      'vendor.final_select',
      'users.change_role',
      'users.invite_committee',
      'finance.approve_10k',
      'finance.approve_20k',
      'snag.verify_close',
      'snag.delete',
      'snag.view',
      'hoto.view',
      'vendor.view',
    ];
    for (const key of mustBeLocked) {
      expect((FEATURES as any)[key]?.locked, `${key} should be locked`).toBe(true);
    }
  });

  it('new Sprint 4 features are present in registry', () => {
    const sprint4Features = [
      'community.moderate',
      'gallery.view', 'gallery.manage',
      'maids.view', 'maids.manage', 'maids.approve',
      'feedback.submit', 'feedback.manage',
      'policies.view', 'policies.manage',
      'documents.manage', 'events.manage', 'polls.manage',
      'admin.registrations', 'admin.gates',
    ];
    for (const key of sprint4Features) {
      expect(FEATURES, `${key} should exist`).toHaveProperty(key);
    }
  });
});
