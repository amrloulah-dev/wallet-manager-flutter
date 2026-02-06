/// Defines structured `Failure` classes to represent user-facing error states
/// in the UI layer, corresponding to handled exceptions from the data layer.
library;

// ===========================
// Base Failure
// ===========================
/// Abstract base class for all failures in the application.
/// A `Failure` is a user-friendly error representation for the UI layer.
abstract class Failure {
  final String message;

  const Failure(this.message);

  @override
  String toString() => message;
}

// ===========================
// Auth Failures
// ===========================
/// Represents failures related to authentication (e.g., invalid credentials).
class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

// ===========================
// License Failures
// ===========================
/// Represents failures related to license key validation or status.
class LicenseFailure extends Failure {
  const LicenseFailure(super.message);
}

// ===========================
// Network Failures
// ===========================
/// Represents a failure due to network connectivity issues.
class NetworkFailure extends Failure {
  const NetworkFailure()
      : super('خطأ في الاتصال بالإنترنت، يرجى التحقق من اتصالك');
}

// ===========================
// Server Failures
// ===========================
/// Represents a failure due to a server-side error.
class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

// ===========================
// Validation Failures
// ===========================
/// Represents a failure due to invalid user input.
class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

// ===========================
// Not Found Failures
// ===========================
/// Represents a failure when a requested entity is not found.
class NotFoundFailure extends Failure {
  const NotFoundFailure(String entity) : super('$entity غير موجود');
}

// ===========================
// Permission Failures
// ===========================
/// Represents a failure due to insufficient user permissions.
class PermissionDeniedFailure extends Failure {
  const PermissionDeniedFailure()
      : super('ليس لديك صلاحية للقيام بهذا الإجراء');
}

// ===========================
// Unknown Failures
// ===========================
/// Represents an unexpected or unknown error.
class UnknownFailure extends Failure {
  const UnknownFailure() : super('حدث خطأ غير متوقع، يرجى المحاولة مرة أخرى');
}
