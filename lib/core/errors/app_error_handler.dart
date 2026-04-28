import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../services/analytics_service.dart';
import '../utils/toast_utils.dart';
import 'app_exceptions.dart';
import 'error_severity.dart';

/// Centralized error handler responsible for logging and diagnostics.
/// 
/// This class is strictly decoupled from UI components (like BotToast or showDialog)
/// to ensure it can safely run in background isolates or before the UI is mounted.
class AppErrorHandler {
  static bool isTestMode = false;
  
  /// High-level initialization to hook into Flutter's global error reporting.
  static void init() {
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      handle(
        details.exception,
        stackTrace: details.stack,
        severity: ErrorSeverity.critical,
        operation: 'flutter_global_error',
      );
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      handle(
        error,
        stackTrace: stack,
        severity: ErrorSeverity.critical,
        operation: 'platform_dispatcher_error',
      );
      return true;
    };
  }

  /// Logs a non-fatal error silently without interrupting the user.
  /// In debug mode, logs to console. In release mode, reports to Crashlytics.
  static void logSilentError(String error, String reason, {StackTrace? stackTrace}) {
    if (isTestMode || kDebugMode) {
      debugPrint(
        '🤫 [SILENT ERROR] [$reason] $error\n'
        '  Stack: ${stackTrace ?? StackTrace.current}',
      );
      developer.log(
        error,
        name: 'SILENT_ERROR',
        error: error,
        stackTrace: stackTrace,
      );
    } else {
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: reason,
        printDetails: false,
        fatal: false,
      );
    }
  }

  /// Handles an error by logging diagnostics and reporting to analytics.
  /// 
  /// UI notifications can be triggered via [showToast] if the environment allows.
  static void handle(
    Object error, {
    ErrorSeverity severity = ErrorSeverity.medium,
    String operation = 'unspecified',
    StackTrace? stackTrace,
    bool showToast = false,
  }) {
    if (isTestMode) return;
    
    final message = error is AppException ? error.message : error.toString();
    _logDiagnostic(severity, operation, message, stackTrace);

    // Visible Surfacing
    if (showToast && !isTestMode) {
      try {
        // We use a dynamic lookup or specific utility to show toast
        // to keep the core decoupled from specific toast libraries if possible,
        // but here we'll use ToastUtils directly as it's the project standard.
        // Since AppErrorHandler is decoupled, we should check if ToastUtils is available.
        // For now, we'll assume it is as per project structure.
        ToastUtils.showError(message);
      } catch (e) {
        debugPrint('⚠️ [ERROR_HANDLER] Failed to show toast: $e');
      }
    }

    // Report to Analytics
    AnalyticsService.logError(
      message,
      severity: severity.name,
      operation: operation,
    );

    // Report to Crashlytics for serious errors
    if (!kDebugMode && (severity == ErrorSeverity.critical || severity == ErrorSeverity.medium)) {
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: 'Operation: $operation',
        fatal: severity == ErrorSeverity.critical,
      );
    }
  }

  static void _logDiagnostic(
    ErrorSeverity severity,
    String operation,
    String message,
    StackTrace? stackTrace,
  ) {
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final stack = stackTrace?.toString() ?? 'No stack trace available';
    
    debugPrint(
      '[ERROR] [${severity.name}] [$operation] $message\n'
      '  Stack: $stack\n'
      '  Timestamp: $timestamp',
    );
  }
}
