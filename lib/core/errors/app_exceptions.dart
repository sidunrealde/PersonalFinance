/// Base exception for all app-specific errors.
class AppException implements Exception {
  const AppException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'AppException: $message';
}

class AuthException extends AppException {
  const AuthException(super.message, {super.cause});

  @override
  String toString() => 'AuthException: $message';
}

class DatabaseException extends AppException {
  const DatabaseException(super.message, {super.cause});

  @override
  String toString() => 'DatabaseException: $message';
}

class SyncException extends AppException {
  const SyncException(super.message, {super.cause});

  @override
  String toString() => 'SyncException: $message';
}
