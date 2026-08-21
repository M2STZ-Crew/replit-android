sealed class AppException implements Exception {
  const AppException(this.message, [this.originalError]);

  final String message;
  final Object? originalError;

  @override
  String toString() => message;
}

final class AuthException extends AppException {
  const AuthException(super.message, [super.originalError]);
}

final class NetworkException extends AppException {
  const NetworkException(super.message, [super.originalError]);
}

final class StorageException extends AppException {
  const StorageException(super.message, [super.originalError]);
}

final class ValidationException extends AppException {
  const ValidationException(super.message, [super.originalError]);
}

final class LocationException extends AppException {
  const LocationException(super.message, [super.originalError]);
}

final class PermissionException extends AppException {
  const PermissionException(super.message, [super.originalError]);
}

final class ServerException extends AppException {
  const ServerException(super.message, [super.originalError]);
}
