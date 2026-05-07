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
        errorCode,
        operation,
        stackTrace: stack,
      );
    }
  }
}
