import 'package:flutter_test/flutter_test.dart';
import 'package:utamacs_portal/core/auth/auth_guard.dart';
import 'package:utamacs_portal/core/error/app_exception.dart';
import 'package:utamacs_portal/shared/models/profile.dart';

// Helper to build a minimal Profile for testing.
Profile _profile({String portalRole = 'member', bool isAdmin = false}) => Profile(
      id: 'uid',
      societyId: 'soc',
      portalRole: portalRole,
      isAdmin: isAdmin,
    );

void main() {
  // ─── requireAuth ──────────────────────────────────────────────────────────────
  group('AuthGuard.requireAuth', () {
    test('passes when profile is non-null', () {
      expect(() => AuthGuard.requireAuth(_profile()), returnsNormally);
    });

    test('throws unauthorized when profile is null', () {
      expect(
        () => AuthGuard.requireAuth(null),
        throwsA(isA<AppException>()),
      );
    });
  });

  // ─── requireExec ──────────────────────────────────────────────────────────────
  group('AuthGuard.requireExec', () {
    test('executive passes', () =>
        expect(() => AuthGuard.requireExec(_profile(portalRole: 'executive')), returnsNormally));

    test('secretary passes', () =>
        expect(() => AuthGuard.requireExec(_profile(portalRole: 'secretary')), returnsNormally));

    test('president passes', () =>
        expect(() => AuthGuard.requireExec(_profile(portalRole: 'president')), returnsNormally));

    test('admin flag passes', () =>
        expect(() => AuthGuard.requireExec(_profile(isAdmin: true)), returnsNormally));

    test('member throws forbidden', () {
      expect(
        () => AuthGuard.requireExec(_profile(portalRole: 'member')),
        throwsA(isA<AppException>()),
      );
    });

    test('security_guard throws forbidden', () {
      expect(
        () => AuthGuard.requireExec(_profile(portalRole: 'security_guard')),
        throwsA(isA<AppException>()),
      );
    });

    test('null profile throws unauthorized', () {
      expect(
        () => AuthGuard.requireExec(null),
        throwsA(isA<AppException>()),
      );
    });
  });

  // ─── requireGuard ─────────────────────────────────────────────────────────────
  group('AuthGuard.requireGuard', () {
    test('security_guard passes', () =>
        expect(() => AuthGuard.requireGuard(_profile(portalRole: 'security_guard')),
            returnsNormally));

    test('member throws', () {
      expect(
        () => AuthGuard.requireGuard(_profile(portalRole: 'member')),
        throwsA(isA<AppException>()),
      );
    });

    test('executive throws (guards are not execs)', () {
      expect(
        () => AuthGuard.requireGuard(_profile(portalRole: 'executive')),
        throwsA(isA<AppException>()),
      );
    });

    test('null profile throws', () {
      expect(
        () => AuthGuard.requireGuard(null),
        throwsA(isA<AppException>()),
      );
    });
  });

  // ─── requireAdmin ─────────────────────────────────────────────────────────────
  group('AuthGuard.requireAdmin', () {
    test('isAdmin=true passes', () =>
        expect(() => AuthGuard.requireAdmin(_profile(isAdmin: true)), returnsNormally));

    test('executive without admin flag throws', () {
      expect(
        () => AuthGuard.requireAdmin(_profile(portalRole: 'executive')),
        throwsA(isA<AppException>()),
      );
    });

    test('null throws', () {
      expect(
        () => AuthGuard.requireAdmin(null),
        throwsA(isA<AppException>()),
      );
    });
  });
}
