import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as fln;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter/services.dart';
import '../../routes/navigation_service.dart';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../services/analytics_service.dart';
import '../utils/toast_utils.dart';
import 'app_exceptions.dart';
import 'error_severity.dart';

/// Centralized error handler responsible for logging and diagnostics.
class AppErrorHandler {
  static bool isTestMode = false;

  static fln.FlutterLocalNotificationsPlugin _notificationsPlugin =
      fln.FlutterLocalNotificationsPlugin();

  /// Sets a custom notifications plugin (for testing).
  @visibleForTesting
  static void setNotificationsPlugin(
      fln.FlutterLocalNotificationsPlugin plugin) {
    _notificationsPlugin = plugin;
    _notificationsInitialized = true; // Assume initialized if mocked
  }

  static bool _notificationsInitialized = false;

  static Future<void> _ensureNotificationsInitialized() async {
    if (_notificationsInitialized) return;
    const fln.AndroidInitializationSettings androidSettings =
        fln.AndroidInitializationSettings('@mipmap/ic_launcher');
    const fln.InitializationSettings initSettings = fln.InitializationSettings(
      android: androidSettings,
    );
    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse:
          (fln.NotificationResponse response) async {
        // Tapping the notification should bring the app to foreground.
        // We also close any active overlays to ensure the user sees the main app.
        try {
          if (await FlutterOverlayWindow.isActive()) {
            await FlutterOverlayWindow.closeOverlay();
          }

          // Launch main app if user tapped notification
          if (response.payload == 'error_notification') {
            await _launchMainApp();
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
                '⚠️ [ERROR_HANDLER] Failed to handle notification tap: $e');
          }
        }
      },
    );
    _notificationsInitialized = true;
  }

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
      return false;
    };
  }

  /// Logs a non-fatal error silently without interrupting the user.
  /// In debug mode, logs to console. In release mode, reports to Crashlytics.
  static void logSilentError(String error, String reason,
      {StackTrace? stackTrace}) {
    if (kDebugMode || isTestMode) {
      if (kDebugMode)
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

  /// Launches the main application using a platform channel.
  static Future<void> _launchMainApp() async {
    try {
      final result = await const MethodChannel('com.ewallet.manager/app')
          .invokeMethod('launchMainApp');
      if (kDebugMode) {
        debugPrint('🚀 [ERROR_HANDLER] Launched main app: $result');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [ERROR_HANDLER] Failed to launch main app: $e');
      }
    }
  }

  static Future<void> handle(
    Object error, {
    ErrorSeverity severity = ErrorSeverity.medium,
    String operation = 'unspecified',
    StackTrace? stackTrace,
    bool showToast = false,
  }) async {
    if (isTestMode) return;

    final message = error is AppException ? error.message : error.toString();
    _logDiagnostic(severity, operation, message, stackTrace);

    final context = NavigationService.navigatorKey.currentContext;

    // 1. Visible Surfacing (Context-Aware)
    if (context != null) {
      // Foreground UI context exists
      if (showToast) {
        try {
          ToastUtils.showError(message);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('⚠️ [ERROR_HANDLER] Failed to show toast: $e');
          }
        }
      }
    } else {
      // Background context — trigger Local Notification for critical issues
      try {
        await _ensureNotificationsInitialized();
        const fln.AndroidNotificationDetails androidDetails =
            fln.AndroidNotificationDetails(
          'error_channel',
          'Errors',
          channelDescription: 'Critical background errors',
          importance: fln.Importance.max,
          priority: fln.Priority.high,
          autoCancel: true,
        );
        const fln.NotificationDetails details = fln.NotificationDetails(
          android: androidDetails,
        );
        await _notificationsPlugin.show(
          999,
          '⚠️ SMS Processing Error',
          'Please open the app to verify your recent transactions.',
          details,
          payload: 'error_notification',
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ [ERROR_HANDLER] Failed to show notification: $e');
        }
      }
    }

    // 2. Report to Analytics & Crashlytics (Safeguarded)
    try {
      // Check if Firebase is truly initialized to avoid LateInitializationError
      if (Firebase.apps.isNotEmpty) {
        AnalyticsService.logError(
          message,
          severity: severity.name,
          operation: operation,
        ).catchError((e) {
          if (kDebugMode) {
            debugPrint('⚠️ [ERROR_HANDLER] Analytics failed: $e');
          }
        });

        if (!kDebugMode &&
            (severity == ErrorSeverity.critical ||
                severity == ErrorSeverity.medium)) {
          FirebaseCrashlytics.instance
              .recordError(
            error,
            stackTrace,
            reason: 'Operation: $operation',
            fatal: severity == ErrorSeverity.critical,
          )
              .catchError((e) {
            if (kDebugMode) {
              debugPrint('⚠️ [ERROR_HANDLER] Crashlytics failed: $e');
            }
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [ERROR_HANDLER] Firebase reporting check failed: $e');
      }
    }
  }

  static void _logDiagnostic(
    ErrorSeverity severity,
    String operation,
    String message,
    StackTrace? stackTrace,
  ) {
    if (kDebugMode) {
      final timestamp = DateTime.now().toUtc().toIso8601String();
      final stack = stackTrace?.toString() ?? 'No stack trace available';
      if (kDebugMode)
        debugPrint(
          '[ERROR] [${severity.name}] [$operation] $message\n'
          '  Stack: $stack\n'
          '  Timestamp: $timestamp',
        );
    }
  }
}
