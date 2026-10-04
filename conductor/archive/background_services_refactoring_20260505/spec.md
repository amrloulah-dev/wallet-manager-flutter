# Specification: Background Services & OS Constraints Refactoring

## Overview
This track addresses critical architectural flaws in Background Isolates, OS constraints (Android Doze/Foreground Services), and headless UX in the Wallet Manager app.

## Target Environment
- **Primary Target:** Android 12+ (API 31+) and aggressive OEM skins (e.g., MIUI, ColorOS, OneUI).
- **Fallback:** General backwards compatibility must be maintained.
- **Constraints:** $0 Budget (Spark Plan) - No Cloud Functions.

## Functional Requirements

### 1. Data Duplication & Stale State Fixes
- **Remove Duplicate Listener:** Ensure `SmsService.init()` does not register `listenIncomingSms`. Only the Guardian Isolate (`FlutterBackgroundService`) should listen for SMS.
- **Clear Vault on Dismiss:** When the overlay is dismissed without confirmation, call `LocalStorageService().clearVault()` (or equivalent) to clear stale SMS data.
- **Global Audit:** Ensure only the Guardian Isolate registers `BroadcastReceiver` or telephony listeners.

### 2. Isolate Crashes & UX Blindspots Fixes
- **Smart Error Handler:** In `AppErrorHandler.handle()`, check for foreground UI context.
  - If valid context: Display standard `showDialog` or `BotToast`.
  - If background context: Trigger a Local Notification stating *"⚠️ SMS Processing Error: Please open the app to verify your recent transactions."*, log to Crashlytics, and DO NOT call UI.
  - **Notification Action:** The local notification must be actionable; tapping it opens the Main App.
- **Overlay Firebase Failsafe:** In `overlayMain` (main.dart), catch `Firebase.initializeApp()` failures. Display an elegant Error UI in the overlay (*"❌ Connection Error. Please use the main app."*) with a close button, skipping `setupServiceLocator()`.
- **Global Audit:** Prevent any UI-bound functions from executing in background services/cold starts without context checks.

### 3. OS Constraints & Hybrid Kill-Switch Fixes
- **Hybrid Kill-Switch:** In `BackgroundService._onStart()`, if `isSmsAutomationEnabled` is false, call `service.stopSelf()` to aggressively kill the Android service and persistent notification.
- **Battery Optimization:** In `SmsService.init()`, request `Permission.ignoreBatteryOptimizations`.
  - **Permission Denied Behavior:** If denied, proceed with a warning to the user about potential background reliability issues.
- **Global Audit:** Ensure background tasks are aborted with `stopSelf()` when features are disabled.

### 4. Tech Debt & Hot Path Optimization
- **Remove Dead Code:** Delete `topLevelBackgroundSmsHandler` from `sms_service.dart`.
- **Optimize Hot Path:** Wrap `debugPrint` calls in `sms_processing_pipeline.dart` and related hot paths in `if (kDebugMode)`.
- **Global Audit:** Delete unused `@pragma('vm:entry-point')` functions and restrict naked `debugPrint` calls in `lib/core/services/` to `kDebugMode`.

## Acceptance Criteria
- [ ] No duplicate SMS listener exists. SMS triggers exactly one pipeline execution.
- [ ] Closing the overlay clears the transaction vault.
- [ ] Background critical errors trigger an actionable System Notification (opens Main App), NOT a UI crash.
- [ ] Overlay gracefully shows an error screen if Firebase fails to initialize.
- [ ] The Foreground Service correctly calls `stopSelf()` if `isSmsAutomationEnabled` is false.
- [ ] Battery optimization permission is explicitly requested; if denied, a warning is shown.
- [ ] Dead background handlers are removed, and `debugPrint` in the pipeline is restricted to debug mode.