import 'package:flutter_test/flutter_test.dart';
import 'package:utamacs_portal/shared/models/portal_role.dart';

void main() {
  // ─── fromString ───────────────────────────────────────────────────────────────
  group('PortalRole.fromString', () {
    test('executive', () => expect(PortalRole.fromString('executive'), PortalRole.executive));
    test('secretary', () => expect(PortalRole.fromString('secretary'), PortalRole.secretary));
    test('president', () => expect(PortalRole.fromString('president'), PortalRole.president));
    test('security_guard', () =>
        expect(PortalRole.fromString('security_guard'), PortalRole.securityGuard));
    test('vendor', () => expect(PortalRole.fromString('vendor'), PortalRole.vendor));
    test('admin', () => expect(PortalRole.fromString('admin'), PortalRole.admin));
    test('member', () => expect(PortalRole.fromString('member'), PortalRole.member));
    test('unknown string → member', () =>
        expect(PortalRole.fromString('superuser'), PortalRole.member));
    test('null → member', () => expect(PortalRole.fromString(null), PortalRole.member));
  });

  // ─── isExec ───────────────────────────────────────────────────────────────────
  group('PortalRole.isExec', () {
    test('executive', () => expect(PortalRole.executive.isExec, isTrue));
    test('secretary', () => expect(PortalRole.secretary.isExec, isTrue));
    test('president', () => expect(PortalRole.president.isExec, isTrue));
    test('admin', () => expect(PortalRole.admin.isExec, isTrue));
    test('member → false', () => expect(PortalRole.member.isExec, isFalse));
    test('securityGuard → false', () => expect(PortalRole.securityGuard.isExec, isFalse));
    test('vendor → false', () => expect(PortalRole.vendor.isExec, isFalse));
  });

  // ─── isGuard ──────────────────────────────────────────────────────────────────
  group('PortalRole.isGuard', () {
    test('securityGuard → true', () => expect(PortalRole.securityGuard.isGuard, isTrue));
    test('executive → false', () => expect(PortalRole.executive.isGuard, isFalse));
    test('admin → false', () => expect(PortalRole.admin.isGuard, isFalse));
  });

  // ─── value (round-trip) ───────────────────────────────────────────────────────
  group('PortalRole.value round-trip', () {
    for (final role in PortalRole.values) {
      test('${role.name} round-trips', () {
        expect(PortalRole.fromString(role.value), role);
      });
    }
  });
}
