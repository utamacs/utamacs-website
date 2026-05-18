import 'package:flutter_test/flutter_test.dart';
import 'package:utamacs_portal/shared/models/profile.dart';

void main() {
  // ─── Factory helpers ─────────────────────────────────────────────────────────
  Profile _make({
    String portalRole = 'member',
    bool isAdmin = false,
    String? fullName,
    String? unitNumber,
    String? block,
  }) =>
      Profile(
        id: 'uid-1',
        societyId: 'soc-1',
        portalRole: portalRole,
        isAdmin: isAdmin,
        fullName: fullName,
        unitNumber: unitNumber,
        block: block,
      );

  // ─── isExec ───────────────────────────────────────────────────────────────────
  group('Profile.isExec', () {
    test('executive → true', () => expect(_make(portalRole: 'executive').isExec, isTrue));
    test('secretary → true', () => expect(_make(portalRole: 'secretary').isExec, isTrue));
    test('president → true', () => expect(_make(portalRole: 'president').isExec, isTrue));
    test('member → false', () => expect(_make(portalRole: 'member').isExec, isFalse));
    test('security_guard → false', () => expect(_make(portalRole: 'security_guard').isExec, isFalse));
    test('is_admin override → true regardless of portalRole', () =>
        expect(_make(portalRole: 'member', isAdmin: true).isExec, isTrue));
  });

  // ─── isGuard ──────────────────────────────────────────────────────────────────
  group('Profile.isGuard', () {
    test('security_guard → true', () =>
        expect(_make(portalRole: 'security_guard').isGuard, isTrue));
    test('member → false', () => expect(_make(portalRole: 'member').isGuard, isFalse));
    test('executive → false', () => expect(_make(portalRole: 'executive').isGuard, isFalse));
    test('isAdmin does not grant guard', () =>
        expect(_make(isAdmin: true).isGuard, isFalse));
  });

  // ─── isAdmin ──────────────────────────────────────────────────────────────────
  group('Profile.isAdmin', () {
    test('true when flag set', () => expect(_make(isAdmin: true).isAdmin, isTrue));
    test('false by default', () => expect(_make().isAdmin, isFalse));
  });

  // ─── displayName ─────────────────────────────────────────────────────────────
  group('Profile.displayName', () {
    test('returns fullName when set', () =>
        expect(_make(fullName: 'Suresh Kumar').displayName, 'Suresh Kumar'));
    test('falls back to Resident when fullName is null', () =>
        expect(_make(fullName: null).displayName, 'Resident'));
  });

  // ─── unitDisplay ─────────────────────────────────────────────────────────────
  group('Profile.unitDisplay', () {
    test('block + unit → B-201', () =>
        expect(_make(block: 'B', unitNumber: '201').unitDisplay, 'B-201'));
    test('unit only → 201', () =>
        expect(_make(unitNumber: '201').unitDisplay, '201'));
    test('no unit → empty string', () =>
        expect(_make().unitDisplay, ''));
  });

  // ─── fromJson ─────────────────────────────────────────────────────────────────
  group('Profile.fromJson', () {
    test('parses minimal JSON', () {
      final p = Profile.fromJson({
        'id': 'u1',
        'society_id': 's1',
        'portal_role': 'executive',
        'is_admin': false,
      });
      expect(p.id, 'u1');
      expect(p.portalRole, 'executive');
      expect(p.isExec, isTrue);
    });

    test('uses units join map for unit_number and block', () {
      final p = Profile.fromJson({
        'id': 'u1',
        'society_id': 's1',
        'units': {'unit_number': '305', 'block': 'C'},
      });
      expect(p.unitNumber, '305');
      expect(p.block, 'C');
      expect(p.unitDisplay, 'C-305');
    });

    test('falls back to member when portal_role absent', () {
      final p = Profile.fromJson({'id': 'u2', 'society_id': 's1'});
      expect(p.portalRole, 'member');
      expect(p.isExec, isFalse);
    });

    test('is_admin defaults to false', () {
      final p = Profile.fromJson({'id': 'u2', 'society_id': 's1'});
      expect(p.isAdmin, isFalse);
    });
  });

  // ─── copyWith ─────────────────────────────────────────────────────────────────
  group('Profile.copyWith', () {
    test('updates fullName, preserves other fields', () {
      final original = _make(portalRole: 'executive', fullName: 'Old Name');
      final updated = original.copyWith(fullName: 'New Name');
      expect(updated.fullName, 'New Name');
      expect(updated.portalRole, 'executive');
      expect(updated.id, original.id);
    });
  });
}
