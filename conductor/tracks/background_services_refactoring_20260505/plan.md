# Implementation Plan: Background Services & OS Constraints Refactoring

## Phase 1: Data Duplication & Stale State Fixes [checkpoint: 380f8ac]
- [x] Task: Write Failing Tests for Data Duplication & Stale State [079fce7]
    - [x] Write test verifying `SmsService.init()` does not register duplicate listener.
    - [x] Write test verifying overlay dismissal calls `LocalStorageService().clearVault()`.
- [x] Task: Implement Data Duplication & Stale State Fixes [23a8c2b]
    - [x] Remove `_telephony.listenIncomingSms` from `SmsService.init()`.
    - [x] Add `LocalStorageService().clearVault()` (or equivalent) when overlay closes without submission.
- [x] Task: Global Audit for Duplicate Listeners [2c8a7eb]
    - [x] Scan and ensure no other duplicate telephony/BroadcastReceiver registrations exist.
- [x] Task: Conductor - User Manual Verification 'Phase 1: Data Duplication & Stale State Fixes' (Protocol in workflow.md) [380f8ac]

## Phase 2: Isolate Crashes & UX Blindspots Fixes
- [x] Task: Write Failing Tests for Error Handler & Overlay Firebase Failsafe [6f9876f]
    - [ ] Write test verifying `AppErrorHandler.handle()` checks for foreground context.
    - [ ] Write test verifying background context errors trigger local notification and not UI.
    - [ ] Write test verifying `overlayMain` catches Firebase init failures and shows error UI.
- [ ] Task: Implement Smart Error Handler
    - [ ] Modify `AppErrorHandler.handle()` to check `NavigationService.navigatorKey.currentContext`.
    - [ ] Add logic to display `BotToast`/`showDialog` if context exists.
    - [ ] Add logic to trigger actionable local notification (opening Main App) and log to Crashlytics if context is null.
- [ ] Task: Implement Overlay Firebase Failsafe
    - [ ] Catch `Firebase.initializeApp()` in `overlayMain`.
    - [ ] Display Error UI in overlay ("❌ Connection Error. Please use the main app.") and skip service locator setup.
- [ ] Task: Global Audit for UI in Background
    - [ ] Scan for UI-bound functions in background services/cold starts.
- [ ] Task: Conductor - User Manual Verification 'Phase 2: Isolate Crashes & UX Blindspots Fixes' (Protocol in workflow.md)

## Phase 3: OS Constraints & Hybrid Kill-Switch Fixes
- [ ] Task: Write Failing Tests for OS Constraints
    - [ ] Write test verifying `BackgroundService._onStart()` calls `stopSelf()` when automation is disabled.
    - [ ] Write test verifying `SmsService.init()` requests battery optimization permission and handles denial.
- [ ] Task: Implement Hybrid Kill-Switch & Battery Optimization
    - [ ] Add `service.stopSelf()` in `BackgroundService._onStart()` if `isSmsAutomationEnabled` is false.
    - [ ] Request `Permission.ignoreBatteryOptimizations` in `SmsService.init()`.
    - [ ] Display warning if battery optimization permission is denied.
- [ ] Task: Global Audit for Feature Flag Enforcement
    - [ ] Ensure background tasks correctly abort/stop when respective features are disabled.
- [ ] Task: Conductor - User Manual Verification 'Phase 3: OS Constraints & Hybrid Kill-Switch Fixes' (Protocol in workflow.md)

## Phase 4: Tech Debt & Hot Path Optimization
- [ ] Task: Write Failing Tests for Tech Debt
    - [ ] Write test ensuring pipeline logic remains intact after removing dead code.
- [ ] Task: Implement Tech Debt & Optimization
    - [ ] Delete `topLevelBackgroundSmsHandler` from `sms_service.dart`.
    - [ ] Wrap `debugPrint` calls in `sms_processing_pipeline.dart` within `if (kDebugMode)`.
- [ ] Task: Global Audit for Tech Debt
    - [ ] Delete unused `@pragma('vm:entry-point')` functions.
    - [ ] Wrap naked `debugPrint` calls in `lib/core/services/` with `kDebugMode`.
- [ ] Task: Conductor - User Manual Verification 'Phase 4: Tech Debt & Hot Path Optimization' (Protocol in workflow.md)