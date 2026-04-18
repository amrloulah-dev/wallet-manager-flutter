# Implementation Plan: Error Handling Remediation

## Phase 1: AppErrorHandler Foundation [checkpoint: e6ba319]
- [x] Task: Implement AppErrorHandler class [40e115e]
    - [x] Write failing test for `AppErrorHandler.logSilentError` behavior (debug vs release mode).
    - [x] Implement `AppErrorHandler.logSilentError` in a new or existing utility file.
    - [x] Integrate `developer.log` for debug mode and `FirebaseCrashlytics.instance.recordError` for release mode.
    - [x] Ensure tests pass.
- [x] Task: Conductor - User Manual Verification 'AppErrorHandler Foundation' (Protocol in workflow.md)

## Phase 2: SMS Parser Resilience [checkpoint: d3245b3]
- [x] Task: Update VodafoneCashStrategy parser [6552a05]
    - [x] Write failing test for `VodafoneCashStrategy` parse logic with edge-case amounts (e.g., with commas).
    - [x] Replace `try-catch` blocks with `double.tryParse` and string sanitization (`replaceAll(',', '').replaceAll(' ', '')`).
    - [x] Call `AppErrorHandler.logSilentError` if `double.tryParse` returns null.
    - [x] Ensure tests pass.
- [x] Task: Update GenericBankStrategy parser [27caba9]
    - [x] Write failing test for `GenericBankStrategy` parse logic with edge-case amounts.
    - [x] Replace `try-catch` blocks with `double.tryParse` and string sanitization.
    - [x] Call `AppErrorHandler.logSilentError` if `double.tryParse` returns null.
    - [x] Ensure tests pass.
- [x] Task: Conductor - User Manual Verification 'SMS Parser Resilience' (Protocol in workflow.md)

## Phase 3: SIM Configuration Safe Access
- [ ] Task: Update _loadState in SettingsScreen
    - [ ] Write failing test for `SettingsScreen` or related SIM configuration logic to handle missing slots gracefully.
    - [ ] Replace `mappings.firstWhere(...)` wrapped in `catch(_)` with `mappings.where((m) => m.simSlotIndex == X).firstOrNull`.
    - [ ] Add conditional UI rendering for null states (e.g., "No saved wallets").
    - [ ] Ensure tests pass.
- [ ] Task: Update sms_processing_pipeline.dart
    - [ ] Write failing test for `SmsProcessingPipeline` slot parsing logic.
    - [ ] Replace empty `try-catch` block around `slotStr` assignment.
    - [ ] Ensure tests pass.
- [ ] Task: Conductor - User Manual Verification 'SIM Configuration Safe Access' (Protocol in workflow.md)

## Phase 4: Dashboard Dependency Injection Validation
- [ ] Task: Remove empty catch in MainDashboardScreen
    - [ ] Write failing test to ensure `MainDashboardScreen` requires `SubscriptionProvider`.
    - [ ] Remove `try-catch` wrapping `context.read<SubscriptionProvider>()` in `_checkPaymentSuccessModal`.
    - [ ] Ensure tests pass.
- [ ] Task: Conductor - User Manual Verification 'Dashboard Dependency Injection Validation' (Protocol in workflow.md)

## Phase 5: Global Remediation & Final Audit
- [ ] Task: Remediate remaining global anti-patterns
    - [ ] Review remaining instances of `catch (_)` or `catch (e) {}` and apply safe alternatives.
    - [ ] Write/update tests as necessary.
    - [ ] Ensure tests pass.
- [ ] Task: Final Code Audit
    - [ ] Run `flutter analyze` and ensure 0 issues are found.
    - [ ] Fix any remaining linting or static analysis errors.
- [ ] Task: Conductor - User Manual Verification 'Global Remediation & Final Audit' (Protocol in workflow.md)