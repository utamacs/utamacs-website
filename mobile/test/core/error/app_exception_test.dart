import 'package:flutter_test/flutter_test.dart';
import 'package:utamacs_portal/core/error/app_exception.dart';

void main() {
  // ─── Default messages ─────────────────────────────────────────────────────────
  group('AppException default messages', () {
    test('unauthorized', () {
      const e = AppException.unauthorized();
      expect(e.message, contains('logged in'));
      expect(e.toString(), e.message);
    });

    test('forbidden', () {
      const e = AppException.forbidden();
      expect(e.message, contains('permission'));
    });

    test('notFound', () {
      const e = AppException.notFound();
      expect(e.message, contains('not found'));
    });

    test('network', () {
      const e = AppException.network();
      expect(e.message, contains('Network'));
    });

    test('server', () {
      const e = AppException.server();
      expect(e.message, contains('Server'));
    });
  });

  // ─── Custom messages ──────────────────────────────────────────────────────────
  group('AppException custom messages', () {
    test('unauthorized with custom message', () {
      const e = AppException.unauthorized('Session expired.');
      expect(e.message, 'Session expired.');
    });

    test('validation always requires message', () {
      const e = AppException.validation('Title is required');
      expect(e.message, 'Title is required');
    });
  });

  // ─── Type checks ──────────────────────────────────────────────────────────────
  group('AppException type identity', () {
    test('unauthorized is AppException', () {
      expect(const AppException.unauthorized(), isA<AppException>());
    });
    test('forbidden is AppException', () {
      expect(const AppException.forbidden(), isA<AppException>());
    });
    test('notFound is AppException', () {
      expect(const AppException.notFound(), isA<AppException>());
    });
    test('network is AppException', () {
      expect(const AppException.network(), isA<AppException>());
    });
    test('validation is AppException', () {
      expect(const AppException.validation('x'), isA<AppException>());
    });
    test('server is AppException', () {
      expect(const AppException.server(), isA<AppException>());
    });
  });

  // ─── wrapException ────────────────────────────────────────────────────────────
  group('wrapException', () {
    test('passes through AppException unchanged', () {
      const original = AppException.forbidden();
      expect(wrapException(original), same(original));
    });

    test('JWT string → unauthorized', () {
      final result = wrapException(Exception('JWT expired'));
      expect(result, isA<AppException>());
      expect(result.message, contains('logged in'));
    });

    test('401 string → unauthorized', () {
      final result = wrapException(Exception('Error 401'));
      expect(result, isA<AppException>());
    });

    test('403 string → forbidden', () {
      final result = wrapException(Exception('403 forbidden'));
      expect(result, isA<AppException>());
      expect(result.message, contains('permission'));
    });

    test('404 string → notFound', () {
      final result = wrapException(Exception('404 not found'));
      expect(result, isA<AppException>());
      expect(result.message, contains('not found'));
    });

    test('network/socket string → network', () {
      final result = wrapException(Exception('socket timeout'));
      expect(result, isA<AppException>());
      expect(result.message, contains('Network'));
    });

    test('unknown → server', () {
      final result = wrapException(Exception('Something went wrong'));
      expect(result, isA<AppException>());
      expect(result.message, contains('Something went wrong'));
    });
  });
}
