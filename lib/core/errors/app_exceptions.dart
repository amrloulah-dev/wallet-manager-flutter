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
  InvalidCredentialsException()
      : super('Invalid credentials', code: 'auth_error_invalid_credentials');
}

/// Thrown when a user tries to log in to an inactive store.
class StoreInactiveException extends AuthException {
  StoreInactiveException()
      : super('Store inactive', code: 'auth_error_store_not_active');
}

/// Thrown when trying to access a user that does not exist.
class UserNotFoundException extends AuthException {
  UserNotFoundException()
      : super('User not found', code: 'auth_error_user_not_found');
}

/// Thrown during registration if the email is already in use.
class EmailAlreadyInUseException extends AuthException {
  EmailAlreadyInUseException()
      : super('Email already in use', code: 'auth_error_email_already_in_use');
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
  InvalidLicenseException()
      : super('Invalid license key', code: 'auth_error_invalid_key');
}

/// Thrown when a license key has already been activated by another store.
class LicenseAlreadyUsedException extends LicenseException {
  LicenseAlreadyUsedException()
      : super('License already used', code: 'auth_error_key_already_used');
}

/// Thrown when the license has expired.
class LicenseExpiredException extends LicenseException {
  LicenseExpiredException() : super('License expired', code: 'license_expired');
}

// ===========================
// Network Exceptions
// ===========================
/// Thrown when there is a network connectivity issue.
class NetworkException extends AppException {
  NetworkException()
      : super('Network error', code: 'network_error_fetch_failed');
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

class InstaPayLimitWarningException extends AppException {
  InstaPayLimitWarningException([String message = 'instapay_limit_warning'])
      : super(message, code: 'instapay_limit_warning');
}

// ===========================
// Not Found Exceptions
// ===========================
/// Thrown when a specific entity (e.g., a document, a wallet) is not found.
class NotFoundException extends AppException {
  NotFoundException(String entity) : super('$entity not found');
}

// ===========================
// Permission Exceptions
// ===========================
/// Thrown when a user attempts an action they do not have permission for.
class PermissionDeniedException extends AppException {
  PermissionDeniedException()
      : super('permission_denied', code: 'permission_denied');
}

class PermissionException extends PermissionDeniedException {
  PermissionException() : super();
}

/// Thrown when the user has exceeded the maximum number of trials on a device.
class DeviceLimitExceededException extends AppException {
  DeviceLimitExceededException()
      : super('Device limit exceeded', code: 'device_limit_exceeded');
}

/// Thrown when the password provided is too weak.
class WeakPasswordException extends AuthException {
  WeakPasswordException() : super('Weak password', code: 'weak_password');
}

/// Thrown when the password provided is incorrect.
class WrongPasswordException extends AuthException {
  WrongPasswordException()
      : super('Incorrect password', code: 'auth_error_invalid_credentials');
}

// ===========================
// Domain Exceptions
// ===========================
/// Base class for domain-related logic errors.
class DomainException extends AppException {
  DomainException(super.message);
}

/// Thrown when a monetary amount is invalid (e.g., negative or exceeds limit).
class InvalidAmountException extends DomainException {
  InvalidAmountException([super.message = 'Invalid amount']);
}
