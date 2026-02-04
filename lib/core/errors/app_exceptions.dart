/// A structured hierarchy of custom exceptions for the application.
library;

// ===========================
// Base Exception
// ===========================
/// Base class for all custom exceptions in the app.
/// Implements [Exception] and provides a user-friendly [message] and an optional [code].
class AppException implements Exception {
  final String message;
  final String? code;

  AppException(this.message, {this.code});

  @override
  String toString() => code != null ? '[$code] $message' : message;
}

// ===========================
// Auth Exceptions
// ===========================
/// Base class for authentication-related exceptions.
class AuthException extends AppException {
  AuthException(super.message, {super.code});
}

/// Thrown when login credentials (e.g., password) are incorrect.
class InvalidCredentialsException extends AuthException {
  InvalidCredentialsException() : super('بيانات الدخول غير صحيحة');
}

/// Thrown when a user tries to log in to an inactive store.
class StoreInactiveException extends AuthException {
  StoreInactiveException() : super('هذا الحساب غير نشط، يرجى التواصل مع الإدارة.');
}

/// Thrown when trying to access a user that does not exist.
class UserNotFoundException extends AuthException {
  UserNotFoundException() : super('المستخدم غير موجود');
}

/// Thrown during registration if the email is already in use.
class EmailAlreadyInUseException extends AuthException {
  EmailAlreadyInUseException() : super('البريد الإلكتروني مستخدم بالفعل');
}

// ===========================
// License Exceptions
// ===========================
/// Base class for license key and subscription-related exceptions.
class LicenseException extends AppException {
  LicenseException(super.message, {super.code});
}

/// Thrown when the provided license key is invalid or doesn't exist.
class InvalidLicenseException extends LicenseException {
  InvalidLicenseException() : super('مفتاح الترخيص غير صحيح');
}

/// Thrown when a license key has already been activated by another store.
class LicenseAlreadyUsedException extends LicenseException {
  LicenseAlreadyUsedException() : super('مفتاح الترخيص مستخدم بالفعل');
}

/// Thrown when the license has expired.
class LicenseExpiredException extends LicenseException {
  LicenseExpiredException() : super('مفتاح الترخيص منتهي الصلاحية');
}

// ===========================
// Network Exceptions
// ===========================
/// Thrown when there is a network connectivity issue.
class NetworkException extends AppException {
  NetworkException() : super('خطأ في الاتصال بالإنترنت، يرجى التحقق من اتصالك');
}

// ===========================
// Server Exceptions
// ===========================
/// Thrown for general server-side errors (e.g., 5xx status codes).
/// The [message] can be customized based on server response.
class ServerException extends AppException {
  ServerException(super.message, {super.code});
}

// ===========================
// Validation Exceptions
// ===========================
/// Thrown when user input fails validation rules.
class ValidationException extends AppException {
  ValidationException(super.message);
}

// ===========================
// Not Found Exceptions
// ===========================
/// Thrown when a specific entity (e.g., a document, a wallet) is not found.
class NotFoundException extends AppException {
  NotFoundException(String entity) : super('$entity غير موجود');
}

// ===========================
// Permission Exceptions
// ===========================
/// Thrown when a user attempts an action they do not have permission for.
class PermissionDeniedException extends AppException {
  PermissionDeniedException() : super('ليس لديك صلاحية للقيام بهذا الإجراء');
}
