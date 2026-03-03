import 'dart:ui';
import 'package:another_telephony/telephony.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import 'package:walletmanager/core/sms_automation/sms_parser_engine.dart';
import 'package:walletmanager/core/sms_automation/models/parsed_sms_dto.dart';
import 'package:walletmanager/data/models/sim_wallet_config.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';

// Top-level function for background SMS handling
@pragma('vm:entry-point')
void backgroundSmsHandler(SmsMessage message) async {
  debugPrint("🔥 BACKGROUND HANDLER: Woken up by Android! 🔥");

  try {
    // 1. Initialize Bindings for background execution
    debugPrint("Step 1: Init Bindings & Storage...");
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    // 2. Initialize Local Storage
    final storage = LocalStorageService();
    await storage.initialize();

    // 3. Debug Log
    debugPrint(
        "Step 2: Checking Switch... Enabled? ${storage.isSmsAutomationEnabled}");

    // 4. Check Feature Flag
    if (!storage.isSmsAutomationEnabled) {
      debugPrint('SMS Automation Disabled. Ignoring background message.');
      return;
    }

    final String? body = message.body;
    final String? address = message.address;
    debugPrint("Step 3: Parsing Message from $address...");

    if (body == null || address == null) {
      debugPrint('Invalid SMS: Body or Address is null.');
      return;
    }

    // 4. Parse Message
    final parser = SmsParserEngine();
    final dto = parser.parse(address, body);
    debugPrint("Step 4: Parser Result: $dto");

    // 5. Filter (Spam/Irrelevant)
    if (dto == null) {
      // Message not parsed as a transaction
      debugPrint("Message ignored (not a valid transaction transaction).");
      return;
    }

    // 6. Match Wallet
    debugPrint("Step 5: Sim Mapping forslot ${message.subscriptionId}...");
    // Retrieve all mappings to find a match by subscriptionId
    final mappings = storage.getSimMappings();
    SimWalletConfig? matchedConfig;

    // Try to find by subscriptionId if available in message
    if (message.subscriptionId != null) {
      final subIdStr = message.subscriptionId.toString();
      try {
        matchedConfig = mappings.firstWhere(
          (config) => config.subscriptionId == subIdStr,
        );
      } catch (_) {
        // No match found by subscriptionId
      }
    }

    // Fallback: If no match by subscriptionId, we relies on it being missing or user interaction.
    final String? walletId = matchedConfig?.walletId;
    final String walletName = matchedConfig?.walletName ?? 'Unknown';

    debugPrint(
        '>>> DETECTED VALID TRANSACTION: Amount: ${dto.amount}, Wallet: $walletId ($walletName), SubID: ${message.subscriptionId}');

    // 7. Trigger Overlay
    debugPrint("Step 6: Triggering Overlay...");
    final bool isGranted = await FlutterOverlayWindow.isPermissionGranted();
    if (!isGranted) {
      debugPrint('Overlay permission not granted. Cannot show overlay.');
      return;
    }

    // Prepare Arguments
    final overlayArgs = {
      'amount': dto.amount,
      'sender': dto.counterpartyNumber ??
          dto.serviceProvider, // Fallback to provider name if number is hidden
      'walletId': walletId,
      'type': dto.type == TransactionType.credit ? 'credit' : 'debit',
      'provider': dto.serviceProvider,
    };

    if (await FlutterOverlayWindow.isActive()) {
      await FlutterOverlayWindow.closeOverlay();
    }

    await FlutterOverlayWindow.showOverlay(
      enableDrag: true,
      overlayTitle: "New Transaction",
      overlayContent: 'Amount: ${dto.amount} EGP',
      flag:
          OverlayFlag.focusPointer, // <--- CRITICAL FIX: Allows Keyboard Focus
      alignment: OverlayAlignment.center,
      visibility: NotificationVisibility.visibilityPublic,
      positionGravity: PositionGravity.auto,
      height: WindowSize.matchParent,
      width: WindowSize.matchParent,
      startPosition: const OverlayPosition(0, 0),
    );

    // Pass date sharing method is via shareData usually or arguments if supported
    // The package `flutter_overlay_window` uses `shareData` to pass generic objects
    await FlutterOverlayWindow.shareData(overlayArgs);
    debugPrint("✅ Overlay Shown Successfully!");
  } catch (e, stack) {
    debugPrint("🔥 BACKGROUND ERROR: $e");
    debugPrint(stack.toString());
  }
}

class SmsService {
  // Singleton
  static final SmsService _instance = SmsService._internal();
  factory SmsService() => _instance;
  SmsService._internal();

  final Telephony _telephony = Telephony.instance;

  /// Initializes the SMS listener.
  Future<void> init() async {
    // Request SMS permissions
    final bool? result = await _telephony.requestPhoneAndSmsPermissions;

    if (result != true) {
      debugPrint('SMS Permissions denied.');
      return;
    }

    // Request Overlay Permission if needed
    await requestOverlayPermission();

    // Initialize LocalStorage if not already (it should be, but safe to call)
    await LocalStorageService().initialize();

    // Listen to incoming SMS
    // We pass both foreground and background handlers
    _telephony.listenIncomingSms(
      onNewMessage: _onForegroundMessage,
      onBackgroundMessage: backgroundSmsHandler,
    );

    debugPrint('SMS Service Initialized and Listening.');
  }

  /// Requests SMS permissions (Receive & Read).
  /// Returns true if granted.
  Future<bool> requestSmsPermission() async {
    try {
      final bool? result =
          await Telephony.instance.requestPhoneAndSmsPermissions;
      return result ?? false;
    } catch (e) {
      debugPrint("Error requesting SMS permission: $e");
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

  /// Handles SMS messages when the app is in the foreground.
  void _onForegroundMessage(SmsMessage message) async {
    // For foreground, we can just use the background handler logic
    // or trigger a standard in-app dialog.
    // To keep it consistent and test the overlay easily, let's delegate to the background handler logic
    // or run it directly since it is static/top-level.

    // However, since backgroundSmsHandler is designed for background isolate,
    // let's just call it. It works in foreground too (main isolate).
    backgroundSmsHandler(message);
  }
}
