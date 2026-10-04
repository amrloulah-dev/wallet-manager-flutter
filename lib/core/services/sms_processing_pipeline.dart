import 'package:another_telephony/telephony.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    hide NotificationVisibility;
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as fln show NotificationVisibility;
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:walletmanager/core/errors/app_error_handler.dart';
import 'package:walletmanager/core/sms_automation/models/parsed_sms_dto.dart';
import 'package:walletmanager/core/sms_automation/sms_parser_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';

// ============================================================
//  SHARED SMS PROCESSING PIPELINE
// ============================================================
// This is the single source of truth for:
//   SMS → Parse → Vault → Wake Screen → Show Overlay → Share Data
//
// Called from:
//   • SmsService (Main Isolate — app is in foreground)
//   • background_service.dart (Guardian Isolate — app killed/minimized)
//   • _backgroundSmsCallback (cold-start when app is dead)
//
// IMPORTANT: This file must NOT import anything isolate-specific
// (no FlutterBackgroundService, no ServiceInstance).
// ============================================================

/// Notification channel ID for transaction alerts.
const String _kChannelId = 'transaction_alert_channel';
const String _kChannelName = 'تنبيهات المعاملات'; // Transaction Alerts
const String _kChannelDesc =
    'إشعارات عالية الأولوية للمعاملات الواردة عبر الرسائل القصيرة';

/// Singleton-ish plugin instance — safe to reuse across calls.
FlutterLocalNotificationsPlugin _notificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Whether the notifications plugin has been initialized this session.
bool _notificationsInitialized = false;

/// Sets a custom notifications plugin (for testing).
@visibleForTesting
void setNotificationsPlugin(FlutterLocalNotificationsPlugin plugin) {
  _notificationsPlugin = plugin;
  _notificationsInitialized = true;
}

/// [TEMP DIAGNOSTIC] Allows mocking DateTime.now for test determinism
@visibleForTesting
DateTime Function() clockNow = DateTime.now;


/// Initializes the local notifications plugin (idempotent).
Future<void> _ensureNotificationsInitialized() async {
  if (_notificationsInitialized) return;

  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initSettings = InitializationSettings(
    android: androidSettings,
  );

  await _notificationsPlugin.initialize(initSettings);
  _notificationsInitialized = true;
}

/// Fires a high-priority notification with fullScreenIntent to wake
/// the device from sleep/lockscreen so the overlay can render.
Future<void> _showWakeUpNotification(double amount) async {
  await _ensureNotificationsInitialized();

  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    _kChannelId,
    _kChannelName,
    channelDescription: _kChannelDesc,
    importance: Importance.max,
    priority: Priority.max,
    fullScreenIntent: true,
    category: AndroidNotificationCategory.alarm,
    visibility: fln.NotificationVisibility.public,
    playSound: true,
    enableVibration: true,
    autoCancel: true,
  );

  const NotificationDetails details = NotificationDetails(
    android: androidDetails,
  );

  // Unique ID so multiple pending notifications stack instead of replacing each other
  final int notificationId =
      DateTime.now().millisecondsSinceEpoch.hashCode.abs() % 99999;
  await _notificationsPlugin.show(
    notificationId,
    'معاملة جديدة', // "New Transaction"
    'تم استلام رسالة، افتح لتسجيل المعاملة', // "SMS received, open to register"
    details,
  );
}

/// Fires a notification when subscription sync data is >24h stale,
/// prompting the user to open the app to refresh.
Future<void> _showStaleSyncNotification() async {
  await _ensureNotificationsInitialized();

  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    _kChannelId,
    _kChannelName,
    channelDescription: _kChannelDesc,
    importance: Importance.max,
    priority: Priority.high,
    autoCancel: true,
  );

  const NotificationDetails details = NotificationDetails(
    android: androidDetails,
  );

  // Unique ID so multiple notifications stack gracefully as per Phase 8.1 requirements
  final int notificationId =
      DateTime.now().millisecondsSinceEpoch.hashCode.abs() % 99999;

  await _notificationsPlugin.show(
    notificationId,
    'تنبيه المزامنة', // "Sync Alert"
    '⚠️ انتهت صلاحية مزامنة الاشتراك. يرجى فتح التطبيق لتحديث بياناتك.',
    details,
  );
}

/// Processes an incoming SMS through the full pipeline:
/// Parse → Match Wallet → Save to Vault → Wake Screen → Trigger Overlay.
///
/// [storage] must be already initialized before calling this.
Future<void> handleIncomingSms(
  SmsMessage message,
  LocalStorageService storage,
) async {
  try {
    final String? body = message.body;
    final String? address = message.address;
    if (body == null ||
        address == null ||
        body.trim().isEmpty ||
        address.trim().isEmpty) {
      return;
    }

    // ── Guard: Feature flag ─────────────────────────────────
    if (!storage.isSmsAutomationEnabled) {
      // [TEMP DIAGNOSTIC]
      await storage.logRejectedSms(
        sender: address,
        rawBody: body,
        reason: 'SUBSCRIPTION_INACTIVE',
        failureStep: 'FEATURE_DISABLED',
      );
      return;
    }

    // ── Guard: Subscription Limits ───────────────────────────
    final isSuspended = storage.subIsSuspended;
    if (isSuspended) {
      // [TEMP DIAGNOSTIC]
      await storage.logRejectedSms(
        sender: address,
        rawBody: body,
        reason: 'SUBSCRIPTION_INACTIVE',
        failureStep: 'SUBSCRIPTION_SUSPENDED',
      );
      return;
    }

    final smsEnabled = storage.subSmsEnabled;
    if (!smsEnabled) {
      // [TEMP DIAGNOSTIC]
      await storage.logRejectedSms(
        sender: address,
        rawBody: body,
        reason: 'SUBSCRIPTION_INACTIVE',
        failureStep: 'SMS_DISABLED',
      );
      return;
    }

    final isLifetime = storage.isSubLifetime;
    if (!isLifetime) {
      final endDateMs = storage.subEndDateMs;
      if (endDateMs != null) {
        final endDate = DateTime.fromMillisecondsSinceEpoch(endDateMs);
        if (clockNow().isAfter(endDate)) {
          // [TEMP DIAGNOSTIC]
          await storage.logRejectedSms(
            sender: address,
            rawBody: body,
            reason: 'SUBSCRIPTION_INACTIVE',
            failureStep: 'SUBSCRIPTION_EXPIRED',
          );
          return;
        }
      }
    }

    // ── Guard: 24h Subscription Sync Staleness ───────────────
    // If the main app hasn't synced subscription data in >24 hours,
    // block processing and notify the user to open the app.
    if (!storage.isSubscriptionSyncFresh) {
      // [TEMP DIAGNOSTIC]
      await storage.logRejectedSms(
        sender: address,
        rawBody: body,
        reason: 'SUBSCRIPTION_INACTIVE',
        failureStep: 'SYNC_STALE_24H',
      );
      await _showStaleSyncNotification();
      return;
    }

    // ── Guard: Stale Message (>24h) ──────────────────────────
    if (message.date != null) {
      final messageDate = DateTime.fromMillisecondsSinceEpoch(message.date!);
      if (clockNow().difference(messageDate).inHours > 24) {
        // [TEMP DIAGNOSTIC]
        await storage.logRejectedSms(
          sender: address,
          rawBody: body,
          reason: 'STALE_SMS',
          failureStep: 'MESSAGE_OLDER_THAN_24H',
        );
        return;
      }
    }

    // ── Parse ───────────────────────────────────────────────
    final parser = SmsParserEngine();
    final ParsedSmsDto? dto = parser.parse(address, body);
    if (dto == null) {
      // [TEMP DIAGNOSTIC]
      final rejection = parser.lastRejection;
      if (rejection != null) {
        await storage.logRejectedSms(
          sender: address,
          rawBody: body,
          reason: rejection.reason,
          failureStep: rejection.failureStep,
        );
      }
      return; // Not a transaction SMS
    }

    // ── Build overlay arguments (Decoupled from SIM slot) ───
    final Map<String, dynamic> overlayArgs = {
      'amount': dto.amount,
      'sender': dto.counterpartyNumber ?? dto.serviceProvider,
      'walletId': null,
      'type': dto.type == TransactionType.credit ? 'credit' : 'debit',
      'provider': dto.serviceProvider,
    };

    // ── Save Current Active SMS (Single-Item / Instant-Kill) ─
    await storage.saveCurrentActiveSms(overlayArgs);

    // ── Phase 2: Wake Screen via High-Priority Notification ─
    // If the device is sleeping/locked, SYSTEM_ALERT_WINDOW
    // can't render. This fullScreenIntent notification forces
    // the screen on and gives the overlay a chance to appear.
    try {
      await _showWakeUpNotification(dto.amount);
    } catch (e, stack) {
      AppErrorHandler.logSilentError(
        'Failed to show wake-up notification: $e',
        'SMS_Pipeline_WakeUp',
        stackTrace: stack,
      );
    }

    // ── Trigger Overlay ─────────────────────────────────────
    final bool isGranted = await FlutterOverlayWindow.isPermissionGranted();
    if (!isGranted) return;

    if (await FlutterOverlayWindow.isActive()) {
      // Dynamic update: push new data to the existing overlay
      // instead of closing and reopening (avoids MIUI/EMUI race conditions).
      await FlutterOverlayWindow.shareData(overlayArgs);
    } else {
      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        overlayTitle: 'New Transaction',
        overlayContent: 'Amount: ${dto.amount} EGP',
        flag: OverlayFlag.focusPointer,
        alignment: OverlayAlignment.center,
        visibility: NotificationVisibility.visibilityPublic,
        positionGravity: PositionGravity.auto,
        height: WindowSize.matchParent,
        width: WindowSize.matchParent,
        startPosition: const OverlayPosition(0, 0),
      );

      // ── Share data with the overlay UI ──────────────────────
      await FlutterOverlayWindow.shareData(overlayArgs);
    }
  } catch (e, stack) {
    AppErrorHandler.logSilentError(
      e.toString(),
      'SmsProcessingPipeline_handleIncomingSms',
      stackTrace: stack,
    );
    // Swallow — must never crash any isolate
  }
}
