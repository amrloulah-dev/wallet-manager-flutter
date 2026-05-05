import 'dart:ui';

import 'package:another_telephony/telephony.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import 'package:walletmanager/core/errors/app_error_handler.dart';
import 'package:walletmanager/core/services/sms_processing_pipeline.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';

// ============================================================
//  GUARDIAN ISOLATE — Background Service Configuration
// ============================================================
// This module is the single, persistent background Isolate.
// It is completely self-sufficient and does NOT communicate
// with the main UI isolate. Its sole job is:
//   Listen SMS → Parse → Save to Vault (SharedPreferences) → Show Overlay
//
// The core processing logic lives in sms_processing_pipeline.dart
// and is shared with the Main Isolate's foreground handler.
// ============================================================

/// Call this once from `main()` to configure the background service.
/// It does NOT start the service — `autoStart: true` handles that.
Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    iosConfiguration: IosConfiguration(
      autoStart: false, // iOS is not our target for this feature
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      autoStartOnBoot: true,
      // Notification shown while the foreground service is alive
      initialNotificationTitle: 'Wallet Manager',
      initialNotificationContent: 'SMS monitoring is active',
      foregroundServiceNotificationId: 9999,
    ),
  );
}

/// iOS background stub — not used, but required by the API.
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

// ============================================================
//  THE CORE: Background Isolate Entry Point
// ============================================================
@pragma('vm:entry-point')
Future<void> onStart(ServiceInstance service) async {
  // ── 1. Bootstrap the Isolate ──────────────────────────────
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  // ── 2. Initialize Local Storage (SharedPreferences) ───────
  final storage = LocalStorageService();
  await storage.initialize();

  // ── 3. Handle "stop" command from the UI isolate ──────────
  service.on('stop').listen((event) {
    service.stopSelf();
  });

  // ── 4. Guard: Only listen if SMS automation is enabled ────
  if (!storage.isSmsAutomationEnabled) {
    if (kDebugMode) debugPrint('🛑 [BACKGROUND] SMS automation is disabled. Stopping service.');
    service.stopSelf();
    return;
  }

  // ── 5. Register SMS Listener inside THIS Isolate ──────────
  final telephony = Telephony.instance;

  telephony.listenIncomingSms(
    onNewMessage: (SmsMessage message) async {
      await handleIncomingSms(message, storage);
    },
    onBackgroundMessage: backgroundSmsCallback,
    listenInBackground: true,
  );
}

// ============================================================
//  BACKGROUND SMS CALLBACK (cold-start / killed-app fallback)
// ============================================================
/// This top-level function is called by `another_telephony`'s
/// native BroadcastReceiver when the app is completely killed.
/// It runs in a fresh Isolate spun up by the plugin.
@pragma('vm:entry-point')
void backgroundSmsCallback(SmsMessage message) async {
  // ── Safe Firebase Init (cold-start isolate) ────────────
  // Firebase must be initialized before any Crashlytics usage.
  // This isolate has its own memory space — Firebase.apps will be empty.
  try {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (e) {
    // If Firebase itself fails, we can only debugPrint — no Crashlytics available
    if (kDebugMode) debugPrint('[CRITICAL] [backgroundSmsCallback] Firebase init failed: $e');
  }

  try {
    final storage = LocalStorageService();
    await storage.initialize();

    if (!storage.isSmsAutomationEnabled) {
      if (kDebugMode) debugPrint('ℹ️ [BACKGROUND] SMS callback ignored: Automation disabled.');
      return;
    }

    await handleIncomingSms(message, storage);
  } catch (e, stack) {
    AppErrorHandler.logSilentError(
      e.toString(),
      'backgroundSmsCallback',
      stackTrace: stack,
    );
    // Swallow — background isolate must never crash
  }
}

