# Specification: Error Handling Master Blueprint

## Overview
This track involves a high-stakes error handling and networking refactor. The goal is to eliminate silent error swallowing, fix broken error propagation chains, and enforce Clean Architecture boundaries between repositories and the UI. It includes a surgical fix on specific files and a global audit across the entire `lib/` directory.

## Functional Requirements
1. **Zero Silent Swallows:** Every `catch` block MUST call `AppErrorHandler.handle()` or `AppErrorHandler.logSilentError()`. Empty catch blocks, blocks with only `debugPrint`, or blocks that only return a value must be remediated.
2. **Mandatory StackTraces:** All generic `catch (e)` must be changed to `catch (e, stack)` and the stack trace must be forwarded.
3. **Platform Boundaries:** `PlatformDispatcher.instance.onError` must explicitly await `Crashlytics.recordError(error, stack, fatal: true)` before returning false.
4. **Isolate Pipelines:** SMS pipeline logging in `handleIncomingSms` must use `logSilentError`. `_showWakeUpNotification` must be in a separate `try/catch` to avoid aborting the pipeline on `PlatformException`.
5. **Clean Architecture Boundaries:** Remove all hardcoded Arabic strings from repositories (e.g., `WalletRepository`). Throw `AppException` or `ServerException` instead.
6. **UI Feedback:** Ensure `isLoading = false` (or equivalent status resets) are strictly placed in `finally` blocks for `StoreRegistrationScreen`, `EmployeeLoginScreen`, `LoginLandingScreen`, and `AuthProvider.findStoreByEmail`. Ensure proper error presentation instead of "Not Found" state in `TransactionDetailsScreen`. Standardize UI fallbacks to use Toasts/Snackbars with `l10n.unexpectedError` instead of exposing raw `$e`.
7. **Tech Debt & Configs:**
    - Fix incorrect error code in `transaction_provider.dart` (`'auth_operation_failed'`).
    - Remove overridden `safeNotify()` in `transaction_provider.dart` to inherit from `SafeChangeNotifier`.
    - Fix clock drift in `TransactionProvider._initializeDateRange` by replacing `DateTime.now()` with `TimeService.now()`.
    - Ensure batch commits in `WalletRepository.resetLimitsForWallets` are wrapped in `try/catch`.
    - Add missing `try/catch` to `AuthProvider.updateEmployeeStats`.
    - Fix bare `throw Exception(...)` in `SubscriptionProvider.submitSubscriptionRequest`.

## Acceptance Criteria
- [ ] `PlatformDispatcher` logs to Crashlytics before returning `false`.
- [ ] ALL `catch` blocks globally across `lib/` use `catch (e, stack)`.
- [ ] Zero hardcoded Arabic strings exist inside `data/repositories/`.
- [ ] `handleIncomingSms` reports errors via `logSilentError` without crashing the isolate.
- [ ] Every async UI flow that mutates `isLoading` resets it in a `finally` block.
- [ ] No `ToastUtils.showError` exposes raw `$e` objects to the user; Toasts/Snackbars use `l10n.unexpectedError`.
- [ ] All overridden `safeNotify()` methods breaking microtask safety are removed.
- [ ] `AuthProvider.updateEmployeeStats` has proper error handling.
- [ ] `SubscriptionProvider.submitSubscriptionRequest` uses typed `AppException`.
- [ ] `TransactionDetailsScreen` correctly displays network errors.

## Out of Scope
- Introducing new features or unrelated UI revamps.
- Refactoring components outside of error handling, logging, and architectural boundary enforcement.