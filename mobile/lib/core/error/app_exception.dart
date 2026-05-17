/// Typed exception hierarchy for UTA MACS mobile app.
/// Use these instead of plain Exception('string') so callers can
/// distinguish auth failures from network errors from validation errors.
sealed class AppException implements Exception {
  const AppException(this.message);
  final String message;

  @override
  String toString() => message;

  const factory AppException.unauthorized([String? msg]) = _UnauthorizedException;
  const factory AppException.forbidden([String? msg]) = _ForbiddenException;
  const factory AppException.notFound([String? msg]) = _NotFoundException;
  const factory AppException.network([String? msg]) = _NetworkException;
  const factory AppException.validation(String msg) = _ValidationException;
  const factory AppException.server([String? msg]) = _ServerException;
}

final class _UnauthorizedException extends AppException {
  const _UnauthorizedException([String? msg])
      : super(msg ?? 'You must be logged in to perform this action.');
}

final class _ForbiddenException extends AppException {
  const _ForbiddenException([String? msg])
      : super(msg ?? 'You do not have permission to perform this action.');
}

final class _NotFoundException extends AppException {
  const _NotFoundException([String? msg])
      : super(msg ?? 'The requested resource was not found.');
}

final class _NetworkException extends AppException {
  const _NetworkException([String? msg])
      : super(msg ?? 'Network error. Please check your connection and try again.');
}

final class _ValidationException extends AppException {
  const _ValidationException(super.msg);
}

final class _ServerException extends AppException {
  const _ServerException([String? msg])
      : super(msg ?? 'Server error. Please try again later.');
}

/// Convert unknown exceptions to AppException for consistent UI handling.
AppException wrapException(Object e) {
  if (e is AppException) return e;
  final msg = e.toString();
  if (msg.contains('JWT') || msg.contains('auth') || msg.contains('401')) {
    return const AppException.unauthorized();
  }
  if (msg.contains('403') || msg.contains('permission')) {
    return const AppException.forbidden();
  }
  if (msg.contains('404')) return const AppException.notFound();
  if (msg.contains('network') || msg.contains('socket') || msg.contains('timeout')) {
    return const AppException.network();
  }
  return AppException.server(msg);
}
