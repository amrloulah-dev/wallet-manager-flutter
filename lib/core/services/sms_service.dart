import 'package:another_telephony/telephony.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:walletmanager/core/services/sms_processing_pipeline.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';
import 'package:walletmanager/core/utils/toast_utils.dart';

// ============================================================
//  SMS SERVICE — Permissions + Foreground Listener
// ============================================================
// Responsibilities:
//   1. Request SMS & Overlay permissions (UI flows)
//   2. Register a FOREGROUND-ONLY SMS listener so that incoming
//      SMS messages are processed while the app is actively open.
//
// The background listener is handled by the Guardian Isolate
// (background_service.dart). We intentionally do NOT pass
// `onBackgroundMessage` here to avoid overriding the Guardian's
// background handler registration.
//
// The core processing pipeline (Parse → Vault → Overlay) lives
// in sms_processing_pipeline.dart and is shared between both.
// ============================================================

class SmsService {
  final Telephony _telephony;

  // Singleton
  static final SmsService _instance = SmsService._internal();
  factory SmsService({Telephony? telephony}) {
    if (telephony != null) {
       return SmsService._withTelephony(telephony);
    }
    return _instance;
  }
  
  SmsService._internal() : _telephony = Telephony.instance;
  SmsService._withTelephony(this._telephony);

  /// Initializes SMS automation: requests permissions and
  /// registers the foreground-only SMS listener.
  Future<void> init() async {
    // Request SMS permissions
    final bool? result = await _telephony.requestPhoneAndSmsPermissions;

    if (result != true) {
      return;
    }

    // Request Overlay Permission if needed
    await requestOverlayPermission();

    // Initialize LocalStorage if not already (it should be, but safe to call)
    final storage = LocalStorageService();
    await storage.initialize();

    // Request Battery Optimization exemption for reliable background work
    final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
    if (!batteryStatus.isGranted) {
      final requested = await Permission.ignoreBatteryOptimizations.request();
      if (!requested.isGranted) {
        ToastUtils.showWarning(
          'Background reliability may be reduced without battery optimization exemption.',
        );
      }
    }

    // ── REMOVED DUPLICATE LISTENER ──────────
    // The Guardian Isolate (background_service.dart) handles all SMS events.
    // Registering here would cause double processing.
  }

  /// Requests SMS permissions (Receive & Read).
  /// Returns true if granted.
  Future<bool> requestSmsPermission() async {
    try {
      final bool? result =
          await Telephony.instance.requestPhoneAndSmsPermissions;
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Requests system alert window permission for the overlay.
  Future<void> requestOverlayPermission() async {
    final bool isGranted = await FlutterOverlayWindow.isPermissionGranted();
    if (!isGranted) {
      await FlutterOverlayWindow.requestPermission();
    }
  }
}
