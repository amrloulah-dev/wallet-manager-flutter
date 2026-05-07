# 🚀 Wallet Manager - Error Handling Master Blueprint (Phase 5)

## 📌 1. General Context & Strict System Prompt
**To the AI Agent (Antigravity / Gemini CLI):**
You are performing a high-stakes error handling and networking refactoring for "Wallet Manager". The goal is to eliminate silent error swallowing, fix broken error propagation chains, and enforce Clean Architecture boundaries between repositories and the UI.
**Core Constraints:**
1. **Zero Silent Swallows:** Every `catch` MUST call `AppErrorHandler.handle()` or `AppErrorHandler.logSilentError()`.
2. **Mandatory StackTraces:** Change all generic `catch (e)` to `catch (e, stack)` and forward the stack trace.
3. **GLOBAL AUDIT DIRECTIVE:** For every issue fixed, you MUST scan the entire `lib/` directory for the same anti-pattern and apply the fix globally.

---

## 📌 2. CRITICAL: AuthProvider & StackTrace Propagation (Axis 1)

### Context
Static analysis identified severe error swallowing where `AuthProvider` methods and data streams fail to capture or forward `StackTrace` objects, leaving Crashlytics completely blind to critical authentication failures.

### The Fix (Surgical + Global Audit)
1. **AuthProvider Overhaul:** In `lib/providers/auth_provider.dart`, fix the 9 methods (e.g., `tryAutoLogin`, `loginWithGoogleOrNull`) lacking stack traces. Update them to `catch (e, stack)` and pass `stack` to `setError(code, e, stack)`. Do NOT `rethrow`; allow state updates to handle UI feedback.
2. **Provider Fallbacks:** In `lib/providers/employee_provider.dart`, add a generic `catch (e, stack)` fallback to `deactivateEmployee` and `resetEmployeePIN` below the `ServerException` catches.
3. **Stream Signatures:** In `employee_provider.dart`, update the `_listenToEmployees` stream `onError: (error)` to `onError: (error, stack)` and forward both parameters.
4. **Global Audit:** Scan `lib/providers/` and `lib/core/` for any instance of `catch (e) {` (missing the stack parameter) and convert it to `catch (e, stack)`.

---

## 📌 3. HIGH: Platform Boundaries & Isolate Pipelines (Axis 2)

### Context
Fatal exceptions are improperly masked by `PlatformDispatcher`, and the background SMS pipeline completely swallows failures to avoid isolate crashes, leaving automation failures completely untracked.

### The Fix (Surgical + Global Audit)
1. **PlatformDispatcher Failsafe:** In `lib/core/errors/app_error_handler.dart`, refactor `PlatformDispatcher.instance.onError`. Before returning `false` (to allow fatal memory resets), it MUST explicitly await `Crashlytics.recordError(error, stack, fatal: true)`.
2. **SMS Pipeline Logging:** In `lib/core/services/sms_processing_pipeline.dart`, replace the silent swallow `// Swallow` in `handleIncomingSms` with `AppErrorHandler.logSilentError(e.toString(), 'SMS_Pipeline', stackTrace: stack, fatal: false)`.
3. **Wake-up Isolation:** In `sms_processing_pipeline.dart`, wrap `_showWakeUpNotification` in its own isolated `try/catch`. If `PlatformException` is thrown (e.g., permissions revoked), log it silently but DO NOT abort the rest of the SMS pipeline.
4. **Global Audit:** Scan for any empty `catch` blocks or blocks that only contain `debugPrint` and replace them with `AppErrorHandler.logSilentError`.

---

## 📌 4. HIGH: Clean Architecture & UI Feedback (Axis 3)

### Context
Repositories leak hardcoded Arabic strings and raw Firebase exceptions (`$e`) directly to the UI, while missing `finally` blocks leave users trapped in infinite loading states when errors occur.

### The Fix (Surgical + Global Audit)
1. **Repository Localization Purge:** In `lib/data/repositories/wallet_repository.dart` (and all other repositories), remove ALL hardcoded Arabic strings (e.g., `'فشل إنشاء المحفظة'`). Throw `AppException('localization_key')` or `ServerException('internal_code')` instead.
2. **Infinite Loading Fix:** In `StoreRegistrationScreen`, `EmployeeLoginScreen`, `LoginLandingScreen`, and `AuthProvider.findStoreByEmail`, ensure `_isLoading = false` (or `_setStatus(AuthStatus.idle)`) is strictly placed inside `finally` blocks.
3. **Broken Stream Handler:** In `WalletRepository.watchWallet`, fix the broken `.handleError` callback. Ensure the error is correctly transformed and emitted downstream rather than discarded.
4. **Global Audit:** Scan the entire codebase for `ToastUtils.showError` containing raw `$e` or `e.toString()` and replace with `l10n.unexpectedError`. Ensure all `_isLoading = true` flows have a corresponding `finally` block.

---

## 📌 5. MEDIUM: Tech Debt & Configs (Axis 4)

### Context
Incorrect error codes, unsafe microtask overrides, unhandled batch operations, and reliance on the device clock instead of an NTP service.

### The Fix (Surgical + Global Audit)
1. **Error Code Fix:** In `lib/providers/transaction_provider.dart`, fix the incorrect error code `'auth_operation_failed'` inside `createTransaction` to a transaction-specific code.
2. **Microtask Override:** In `transaction_provider.dart`, delete the overridden `safeNotify()` method entirely so it inherits the microtask-safe version from `SafeChangeNotifier`.
3. **Clock Drift Fix:** In `TransactionProvider._initializeDateRange`, replace `DateTime.now()` with `TimeService.now()`.
4. **Global Audit:** Scan `WalletRepository.resetLimitsForWallets` and any other batch operations. Wrap batch commits in a `try/catch` block and throw a typed `AppException` if the batch fails.

---

## 📌 acceptance Criteria
- [ ] `PlatformDispatcher` logs to Crashlytics before returning `false`.
- [ ] ALL `catch` blocks globally use `catch (e, stack)`.
- [ ] Zero hardcoded Arabic strings exist inside `data/repositories/`.
- [ ] `handleIncomingSms` reports errors via `logSilentError` without crashing the isolate.
- [ ] Every async UI flow that mutates `isLoading` resets it in a `finally` block.
- [ ] No `ToastUtils.showError` exposes raw `$e` objects to the user.
- [ ] All overridden `safeNotify()` methods breaking microtask safety are removed.