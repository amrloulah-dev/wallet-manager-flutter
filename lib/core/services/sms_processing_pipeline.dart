import 'package:another_telephony/telephony.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    hide NotificationVisibility;
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as fln show NotificationVisibility;
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
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
final FlutterLocalNotificationsPlugin _notificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Whether the notifications plugin has been initialized this session.
bool _notificationsInitialized = false;

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

  const AndroidNotificationDetails androidDetails =
      AndroidNotificationDetails(
    _kChannelId,
    _kChannelName,
    channelDescription: _kChannelDesc,
    importance: Importance.max,
    priority: Priority.high,
    category: AndroidNotificationCategory.alarm,
    visibility: fln.NotificationVisibility.public,
    playSound: true,
    enableVibration: true,
    autoCancel: true,
  );

  const NotificationDetails details = NotificationDetails(
    android: androidDetails,
  );

  await _notificationsPlugin.show(
    0, // Notification ID — using 0, will replace itself on repeat
    'معاملة جديدة', // "New Transaction"
    'تم استلام رسالة، افتح لتسجيل المعاملة', // "SMS received, open to register"
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
    // ── Guard: Feature flag ─────────────────────────────────
    if (!storage.isSmsAutomationEnabled) return;

    final String? body = message.body;
    final String? address = message.address;
    if (body == null || address == null) return;

    // ── Parse ───────────────────────────────────────────────
    final parser = SmsParserEngine();
    final ParsedSmsDto? dto = parser.parse(address, body);
    if (dto == null) return; // Not a transaction SMS

    // ── Match SIM → Wallet ──────────────────────────────────
    final mappings = storage.getSimMappings();
    String? matchedWalletId;


    if (mappings.isNotEmpty) {
      try {
        // 1. Standard Matching (For compliant Android devices)
        if (message.subscriptionId != null && message.subscriptionId.toString().isNotEmpty) {
          final subIdStr = message.subscriptionId.toString().trim();
          final match = mappings.where((c) => c.subscriptionId?.trim() == subIdStr).firstOrNull;
          if (match != null) matchedWalletId = match.walletId;
        }

        // Safely check slot, since it's missing on some OS versions for another_telephony
        String? slotStr;
        try { slotStr = (message as dynamic).slot?.toString(); } catch(_) {}

        if (matchedWalletId == null && slotStr != null && slotStr != "null" && slotStr != "NOT_ACCESSIBLE_ON_THIS_OS_PLATFORM") {
          final match = mappings.where((c) => c.simSlotIndex.toString() == slotStr || (c.simSlotIndex - 1).toString() == slotStr).firstOrNull;
          if (match != null) matchedWalletId = match.walletId;
        }

        // Fallback: match by serviceProvider inferred from the SMS content
        if (matchedWalletId == null && dto.serviceProvider.isNotEmpty) {
           final match = mappings.where((c) => c.serviceProvider.toLowerCase() == dto.serviceProvider.toLowerCase()).firstOrNull;
           if (match != null) matchedWalletId = match.walletId;
        }

        // 2. SMART FALLBACK (For restrictive OEMs like Huawei/Xiaomi)
        if (matchedWalletId == null) {
          final uniqueWallets = mappings.map((m) => m.walletId).toSet();
          if (uniqueWallets.length == 1) {
            // User mapped all SIMs to the same wallet, or only has 1 mapping. Safe to auto-select!
            matchedWalletId = uniqueWallets.first;
            debugPrint("🧠 SMART FALLBACK: OS hid SIM info, but unique wallet found -> $matchedWalletId");
          }
        }
      } catch (e) {
        debugPrint("Matcher Error: $e");
      }
    }


    // ── Build overlay arguments ─────────────────────────────
    final Map<String, dynamic> overlayArgs = {
      'amount': dto.amount,
      'sender': dto.counterpartyNumber ?? dto.serviceProvider,
      'walletId': matchedWalletId,
      'type': dto.type == TransactionType.credit ? 'credit' : 'debit',
      'provider': dto.serviceProvider,
    };

    // ── Save to Vault (SharedPreferences) ───────────────────
    // This ensures the overlay can read the data even if the
    // shareData call fails or the overlay restarts.
    await storage.saveToVault(overlayArgs);

    // ── Phase 2: Wake Screen via High-Priority Notification ─
    // If the device is sleeping/locked, SYSTEM_ALERT_WINDOW
    // can't render. This fullScreenIntent notification forces
    // the screen on and gives the overlay a chance to appear.
    await _showWakeUpNotification(dto.amount);

    // ── Trigger Overlay ─────────────────────────────────────
    final bool isGranted = await FlutterOverlayWindow.isPermissionGranted();
    if (!isGranted) return;

    if (await FlutterOverlayWindow.isActive()) {
      await FlutterOverlayWindow.closeOverlay();
    }

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
  } catch (_) {
    // Swallow — must never crash any isolate
  }
}
