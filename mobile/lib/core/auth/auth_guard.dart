import '../../shared/models/profile.dart';
import '../error/app_exception.dart';

/// Centralised role-enforcement utility.
///
/// Call these at the top of any repository method or screen handler that
/// performs a privileged operation. Throws [AppException.forbidden] when
/// the caller's role is insufficient so that callers can catch it uniformly.
///
/// Why: UI guards are cosmetic (they hide buttons). AuthGuard enforces rules
/// in the method body, so the protection holds even if UI state is wrong.
class AuthGuard {
  AuthGuard._();

  /// Require the current user to be an executive, secretary, president or admin.
  static void requireExec(Profile? profile) {
    if (profile == null) {
      throw const AppException.unauthorized();
    }
    if (!profile.isExec) {
      throw const AppException.forbidden('Executive access required.');
    }
  }

  /// Require the current user to be a security guard.
  static void requireGuard(Profile? profile) {
    if (profile == null) {
      throw const AppException.unauthorized();
    }
    if (!profile.isGuard) {
      throw const AppException.forbidden('Security guard access required.');
    }
  }

  /// Require the current user to be an admin (is_admin = true).
  static void requireAdmin(Profile? profile) {
    if (profile == null) {
      throw const AppException.unauthorized();
    }
    if (!profile.isAdmin) {
      throw const AppException.forbidden('Admin access required.');
    }
  }

  /// Require the user to be authenticated (non-null profile).
  static void requireAuth(Profile? profile) {
    if (profile == null) {
      throw const AppException.unauthorized();
    }
  }
}
