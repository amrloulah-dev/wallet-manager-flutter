import '../core/state/safe_change_notifier.dart';
import '../core/errors/app_error_handler.dart';
import '../core/errors/error_severity.dart';

/// Base class for all providers to centralize common functionality.
abstract class BaseProvider extends SafeChangeNotifier {
  /// Centralized error handling for providers.
  ///
  /// Logs the error and surfaces it to UI via [showToast].
  void setError(String errorCode,
      [Object? error,
      StackTrace? stack,
      bool showToast = false,
      String operation = 'unspecified']) {
    // Defense-in-depth: If the errorCode contains spaces or colons, it's likely
    // a raw message, not a localization key. Fall back to a generic key.
    final safeCode =
        errorCode.contains(RegExp(r'[\s:]')) && !errorCode.startsWith('auth_')
            ? 'error_unexpected'
            : errorCode;
    if (error != null) {
      AppErrorHandler.handle(
        error,
        severity: ErrorSeverity.medium,
        operation: operation,
        stackTrace: stack,
        showToast: showToast,
      );
    } else {
      AppErrorHandler.logSilentError(
        safeCode,
        operation,
        stackTrace: stack,
      );
    }
  }
}
