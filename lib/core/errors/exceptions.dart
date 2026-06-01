/// Excepción base para la aplicación
abstract class AppException implements Exception {
  final String message;
  final String? code;

  AppException(this.message, [this.code]);

  @override
  String toString() => message;
}

/// Excepción de autenticación
class AuthException extends AppException {
  AuthException(super.message, [super.code]);
}

/// Excepción de red
class NetworkException extends AppException {
  NetworkException(super.message, [super.code]);
}

/// Excepción de servidor
class ServerException extends AppException {
  ServerException(super.message, [super.code]);
}

/// Excepción de caché
class CacheException extends AppException {
  CacheException(super.message, [super.code]);
}

/// Excepción de validación
class ValidationException extends AppException {
  ValidationException(super.message, [super.code]);
}