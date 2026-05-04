# 🛠️ Wallet Manager - Background Services & OS Constraints Refactoring Blueprint (Phase 8: Deep Architecture)

## 📌 1. General Context & Strict System Prompt
**To the AI Agent (Antigravity / Gemini CLI):**
You are working on "Wallet Manager", a Flutter-based financial operations app. This track focuses on fixing critical architectural flaws in Background Isolates, OS constraints (Android Doze/Foreground Services), and headless UX.
**Core Constraints:**
1. **$0 Budget (Spark Plan):** No Cloud Functions.
2. **Context-Aware Refactoring:** Understand *why* you are making the change based on the provided context before modifying the code.
3. **GLOBAL AUDIT DIRECTIVE:** For every issue fixed, you MUST scan the entire codebase (especially `lib/core/services/` and `lib/presentation/overlays/`) for the exact same anti-pattern and apply the fix globally. Do not leave trailing issues.

---

## 📌 2. CRITICAL: Data Duplication & Stale State (C-001, M-005)

### Context
Currently, every incoming SMS is processed twice because both `background_service.dart` (Guardian Isolate) and `sms_service.dart` register a `listenInBackground` callback. Furthermore, if a user dismisses the Overlay without confirming, the old SMS data remains stuck in the local Vault.

### The Fix (Surgical + Global Audit)
1. **Remove Duplicate Listener:** In `lib/core/services/sms_service.dart`, completely REMOVE the `_telephony.listenIncomingSms` registration inside `init()`. The `SmsService` should only handle permission requests and starting the Guardian Isolate (`FlutterBackgroundService`).
2. **Clear Vault on Dismiss:** In `lib/presentation/overlays/overlay_provider.dart` (or wherever the overlay close/dismiss logic resides), explicitly add a call to `LocalStorageService().clearVault()` (or equivalent method) to wipe the stale SMS data when the overlay is closed without submission.
3. **Global Audit:** Scan the app for any other duplicate `telephony` or `BroadcastReceiver` registrations. Ensure only the Guardian Isolate listens to incoming SMS.

---

## 📌 3. CRITICAL: Isolate Crashes & UX Blindspots (C-002, C-003, M-004)

### Context
Background isolates (which have no UI context) crash instantly if they attempt to invoke UI elements (like `showDialog`). Additionally, if `Firebase.initializeApp()` fails inside the Overlay isolate, it swallows the error, leading to cascading crashes when Repositories try to use Firestore.

### The Fix (Surgical + Global Audit)
1. **Smart Error Handler (Background Context):** In `lib/core/errors/app_error_handler.dart`, modify `handle()`. Check if the app has a valid foreground UI context (`NavigationService.navigatorKey.currentContext != null`). 
   - If `true`: Show the usual `showDialog` or `BotToast`.
   - If `false` (Background Isolate): **DO NOT call UI.** Instead, trigger a Local Notification (using `flutter_local_notifications`) alerting the user: *"⚠️ SMS Processing Error: Please open the app to verify your recent transactions."* and log to Crashlytics.
2. **Overlay Firebase Failsafe:** In `lib/main.dart` (`overlayMain`), if `Firebase.initializeApp()` fails inside the `try/catch`, **DO NOT** proceed to `setupServiceLocator()`. Update the state to show an elegant Error UI inside the overlay (e.g., *"❌ Connection Error. Please use the main app."*) with a close button.
3. **Global Audit:** Scan the entire project. Ensure NO UI-bound functions (`showDialog`, `ScaffoldMessenger`, `BotToast`) are called directly from background services or cold-start callbacks without checking for a valid context first.

---

## 📌 4. HIGH: OS Constraints & Hybrid Kill-Switch (C-004, M-001)

### Context
The app runs a headless Foreground Service even if the user disables the SMS automation feature (or their subscription expires), violating Android policies and draining battery. Furthermore, the app gets killed by Android Doze because it never requests battery optimization exemptions.

### The Fix (Surgical + Global Audit)
1. **Hybrid Kill-Switch:** In `lib/core/services/background_service.dart`, locate the `_onStart` method. Where it checks `if (!storage.isSmsAutomationEnabled)`:
   - Remove the simple `return;`.
   - Add `service.stopSelf();` to forcefully kill the Android service and remove the persistent notification if the feature is disabled.
2. **Battery Optimization Request:** In `lib/core/services/sms_service.dart` (during the `init` permission flow), add a request for `Permission.ignoreBatteryOptimizations`.
3. **Global Audit:** Verify that any method starting a background task immediately checks the subscription/feature flag and calls `stopSelf()` or aborts if the feature is disabled.

---

## 📌 5. MEDIUM: Tech Debt & Hot Path Optimization (M-002, Q-002)

### Context
A dead top-level function prevents tree-shaking, and synchronous I/O operations (`debugPrint`) are slowing down the SMS processing pipeline in release mode.

### The Fix (Surgical + Global Audit)
1. **Remove Dead Code:** Delete `topLevelBackgroundSmsHandler` entirely from `lib/core/services/sms_service.dart`. It was overridden by the Guardian Isolate anyway.
2. **Optimize Hot Path:** In `lib/core/services/sms_processing_pipeline.dart` (and related files), wrap any `debugPrint` calls inside the high-frequency SMS processing logic with `if (kDebugMode)`.
3. **Global Audit:** Scan for any unused `@pragma('vm:entry-point')` functions and delete them. Audit all `lib/core/services/` for naked `debugPrint` statements and wrap them in `kDebugMode` to ensure zero I/O overhead in production.

---

## 📌 6. Acceptance Criteria
- [ ] No duplicate SMS listener exists. SMS messages trigger exactly one pipeline execution.
- [ ] Closing the overlay clears the transaction vault.
- [ ] Background critical errors trigger a System Notification, NOT a UI crash.
- [ ] Overlay gracefully shows an error screen if Firebase fails to initialize.
- [ ] The Foreground Service correctly calls `stopSelf()` if `isSmsAutomationEnabled` is false.
- [ ] Battery optimization permission is explicitly requested.
- [ ] Dead background handlers are removed, and `debugPrint` in the pipeline is restricted to debug mode.