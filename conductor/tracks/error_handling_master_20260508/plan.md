# Implementation Plan: Error Handling Master Blueprint

## Phase 1: Surgical Fixes - Error Propagation & Architecture
- [x] Task: AuthProvider Overhaul [6baa4e6]
    - [ ] Write failing test for `AuthProvider` error propagation
    - [ ] Update 9 methods in `auth_provider.dart` to use `catch (e, stack)` and forward to `setError(code, e, stack)`
    - [ ] Ensure no `rethrow` is used in these methods
    - [ ] Add `try/catch` block to `AuthProvider.updateEmployeeStats` to handle errors properly
- [ ] Task: Provider Fallbacks and Stream Signatures
    - [ ] Write failing test for `EmployeeProvider` error propagation
    - [ ] Add generic `catch (e, stack)` fallback to `deactivateEmployee` and `resetEmployeePIN` in `employee_provider.dart`
    - [ ] Update `_listenToEmployees` stream `onError: (error)` to `onError: (error, stack)` and forward both
- [ ] Task: Infinite Loading Fixes
    - [ ] Write failing test for loading states
    - [ ] Ensure `_isLoading = false` (or equivalent) is strictly inside `finally` blocks for `StoreRegistrationScreen`, `EmployeeLoginScreen`, `LoginLandingScreen`, and `AuthProvider.findStoreByEmail`
    - [ ] Fix broken `.handleError` callback in `WalletRepository.watchWallet`
    - [ ] Fix `TransactionDetailsScreen` and `TransactionProvider.selectTransaction` to ensure UI explicitly checks for errors and shows actual errors instead of "Not Found" state
    - [ ] Fix missing UI feedback: Add a fallback `ToastUtils.showError(l10n.unexpectedError)` to `EmployeeLoginScreen`'s catch block (C-07), and add a final `else` branch in `LoginLandingScreen._handleFindStore` to handle unknown null states (C-09).
- [ ] Task: Platform Boundaries & Isolate Pipelines
    - [ ] Update `PlatformDispatcher.instance.onError` to explicitly await `Crashlytics.recordError(error, stack, fatal: true)` before returning `false`
    - [ ] Replace silent swallow `// Swallow` in `handleIncomingSms` with `AppErrorHandler.logSilentError(e.toString(), 'SMS_Pipeline', stackTrace: stack, fatal: false)`
    - [ ] Wrap `_showWakeUpNotification` in its own isolated `try/catch` and log `PlatformException` silently without aborting
- [ ] Task: Conductor - User Manual Verification 'Surgical Fixes - Error Propagation & Architecture' (Protocol in workflow.md)

## Phase 2: Surgical Fixes - Tech Debt & Configs
- [ ] Task: Fix Tech Debt in Providers and Repositories
    - [ ] Fix incorrect error code `'auth_operation_failed'` in `transaction_provider.dart`
    - [ ] Delete overridden `safeNotify()` method in `transaction_provider.dart`
    - [ ] Replace `DateTime.now()` with `TimeService.now()` in `TransactionProvider._initializeDateRange`
    - [ ] Wrap batch commits in `WalletRepository.resetLimitsForWallets` in `try/catch` block and throw a typed `AppException`
    - [ ] Fix `SubscriptionProvider.submitSubscriptionRequest` by replacing bare `throw Exception(...)` with typed `throw AppException(...)`
- [ ] Task: Conductor - User Manual Verification 'Surgical Fixes - Tech Debt & Configs' (Protocol in workflow.md)

## Phase 3: Global Audit - Error Handling & StackTraces
- [ ] Task: Global Audit for `catch (e)` and unhandled catches
    - [ ] Scan entire `lib/` directory for `catch (e) {` (missing stack parameter) and convert to `catch (e, stack)`
    - [ ] Scan EVERY `catch` block across `lib/` to guarantee that either `AppErrorHandler.handle()` or `AppErrorHandler.logSilentError()` is called. Fix any block that only returns a value without reporting.
- [ ] Task: Conductor - User Manual Verification 'Global Audit - Error Handling & StackTraces' (Protocol in workflow.md)

## Phase 4: Global Audit - Clean Architecture & UI Feedback
- [ ] Task: Global Audit for Architecture Boundaries
    - [ ] Scan `lib/data/repositories/` and remove ALL hardcoded Arabic strings, replacing them with `AppException('localization_key')` or `ServerException('internal_code')`
    - [ ] Scan for `ToastUtils.showError` containing raw `$e` or `e.toString()` and replace with `l10n.unexpectedError`
    - [ ] Scan async UI flows that mutate `isLoading` to ensure a corresponding `finally` block exists
- [ ] Task: Conductor - User Manual Verification 'Global Audit - Clean Architecture & UI Feedback' (Protocol in workflow.md)