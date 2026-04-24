import 'package:flutter/material.dart';
import '../core/errors/app_error_handler.dart';

/// Base class for all providers to centralize common functionality.
abstract class BaseProvider extends ChangeNotifier {
  bool _isDisposed = false;

  /// Returns true if the provider has been disposed.
  bool get isDisposed => _isDisposed;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  /// Safely notifies listeners if the provider is not disposed and has listeners.
  void safeNotify() {
    if (!_isDisposed && hasListeners) {
      notifyListeners();
    }
  }

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
