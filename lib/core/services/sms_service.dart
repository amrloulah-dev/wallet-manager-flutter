import 'dart:isolate';
import 'package:another_telephony/telephony.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:walletmanager/core/errors/app_error_handler.dart';
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
// CRITICAL: Permission requests MUST ONLY originate from the
// main UI isolate. Background isolates will crash if they
// attempt to trigger OS permission dialogs.
// ============================================================

class SmsService {
  final Telephony _telephony;

  /// Used for testing to simulate background isolate environment.
  @visibleForTesting
  static bool? debugIsMainIsolateOverride;

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

  /// Returns true if the current isolate is the main UI isolate.
  bool get _isMainIsolate {
    if (debugIsMainIsolateOverride != null) return debugIsMainIsolateOverride!;
    // In Flutter, the main isolate usually has no name or 'main'
    final name = Isolate.current.debugName;
    return name == null || name == 'main' || name.contains('ui');
  }

  /// Ensures the current operation is running on the main isolate.
  void _guardIsolate() {
    if (!_isMainIsolate) {
      throw UnsupportedError(
        'Permission requests cannot be initiated from a background isolate. '
        'Ensure SmsService.init() is only called from the main UI thread.',
      );
    }
  }

  /// Initializes SMS automation: requests permissions and
  /// registers the foreground-only SMS listener.
  ///
  /// Returns true if critical permissions (SMS) are granted.
  Future<bool> init() async {
    _guardIsolate();

    // 1. Request SMS permissions
    final bool? result = await _telephony.requestPhoneAndSmsPermissions;

    if (result != true) {
      return false;
    }

    // 2. Request Overlay Permission if needed
    await requestOverlayPermission();

    // 3. Initialize LocalStorage if not already
    final storage = LocalStorageService();
    await storage.initialize();

    // 4. Request Battery Optimization and Notification permissions
    try {
      final results = await [
        Permission.ignoreBatteryOptimizations,
        Permission.notification,
      ].request();

      if (results[Permission.ignoreBatteryOptimizations]?.isDenied == true ||
          results[Permission.ignoreBatteryOptimizations]?.isPermanentlyDenied ==
              true) {
        ToastUtils.showWarning(
          'Background reliability may be reduced without battery optimization exemption.',
        );
      }
    } catch (e, stack) {
      if (kDebugMode) debugPrint('Error requesting additional permissions: $e');
      AppErrorHandler.logSilentError(
          e.toString(), 'SmsService.init_permissions',
          stackTrace: stack);
    }

    return true;
  }

  /// Requests SMS permissions (Receive & Read).
  /// Returns true if granted.
  Future<bool> requestSmsPermission() async {
    _guardIsolate();
    try {
      final bool? result =
          await Telephony.instance.requestPhoneAndSmsPermissions;
      return result ?? false;
    } catch (e, stack) {
      AppErrorHandler.logSilentError(
          e.toString(), 'SmsService.requestSmsPermission',
          stackTrace: stack);
      return false;
    }
  }

  /// Requests system alert window permission for the overlay.
  Future<void> requestOverlayPermission() async {
    _guardIsolate();
    final bool isGranted = await FlutterOverlayWindow.isPermissionGranted();
    if (!isGranted) {
      await FlutterOverlayWindow.requestPermission();
    }
  }
}
