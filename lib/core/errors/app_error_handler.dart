import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:bot_toast/bot_toast.dart';
import '../../routes/navigation_service.dart';
import '../services/analytics_service.dart';
import 'error_severity.dart';

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

  static void handle(
    Object error, {
    ErrorSeverity severity = ErrorSeverity.medium,
    String operation = 'unspecified',
    StackTrace? stackTrace,
  }) {
    if (isTestMode) return;
    
    final message = error.toString();
    _logDiagnostic(severity, operation, message, stackTrace);

    // Report to Analytics
    AnalyticsService.logError(
      message,
      severity: severity.name,
      operation: operation,
    );

    switch (severity) {
      case ErrorSeverity.low:
        BotToast.showText(text: message);
        break;
      case ErrorSeverity.medium:
        BotToast.showNotification(
          title: (_) => const Text('تنبيه'),
          subtitle: (_) => Text(message),
        );
        break;
      case ErrorSeverity.critical:
        final context = NavigationService.navigatorKey.currentContext;
        if (context != null) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('خطأ حرج'),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('حسناً'),
                ),
              ],
            ),
          );
        } else {
          // Fallback if no context
          BotToast.showText(text: "خطأ حرج: $message");
        }
        break;
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
