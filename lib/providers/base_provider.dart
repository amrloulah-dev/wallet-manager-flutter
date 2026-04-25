import '../core/state/safe_change_notifier.dart';
import '../core/errors/app_error_handler.dart';

/// Base class for all providers to centralize common functionality.
abstract class BaseProvider extends SafeChangeNotifier {
  /// Centralized error handling for providers.
  /// 
  /// Logs the error and can be overridden to provide custom error state management.
  void setError(String errorCode, [dynamic error, StackTrace? stack]) {
    AppErrorHandler.logSilentError(
      error?.toString() ?? errorCode,
      errorCode,
      stackTrace: stack,
    );
  }
}
