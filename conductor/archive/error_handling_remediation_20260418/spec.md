# Specification: Error Handling Remediation

## Overview
This track focuses on eliminating the "Silent Error Swallowing" anti-pattern across the entire WalletManager codebase. The primary objective is to replace blind `try-catch` blocks with context-aware, resilient logic, ensuring no unhandled exceptions are ignored without proper logging or fallback mechanisms.

## Functional Requirements
1.  **Phase 1: SMS Parser Resilience (Financial Data Protection)**
    *   **Target Files:** `lib/core/sms_automation/strategies/vodafone_cash_strategy.dart`, `lib/core/sms_automation/strategies/generic_bank_strategy.dart`, and any globally identified instances of similar logic.
    *   **Action:** Replace `double.parse` wrapped in an empty catch with `double.tryParse` combined with string sanitization (removing commas and spaces).
    *   **Error Logging:** If parsing fails, log the error using a newly implemented `AppErrorHandler.logSilentError` method.

2.  **Phase 2: SIM Configuration Safe Access**
    *   **Target File:** `lib/presentation/screens/settings/settings_screen.dart` (specifically `_loadState`), and any globally identified instances of similar collection lookup errors.
    *   **Action:** Replace `try { ... firstWhere(...) } catch (_) {}` with null-safe iterative lookup (`firstWhere` with `orElse` or `firstOrNull` from the `collection` package).
    *   **Fallback:** Handle the resulting `null` state appropriately in the UI layer.

3.  **Phase 3: Dashboard Dependency Injection Validation**
    *   **Target File:** `lib/presentation/screens/home/main_dashboard_screen.dart` (specifically `_checkPaymentSuccessModal`).
    *   **Action:** Remove the empty `catch` block wrapping `context.read<SubscriptionProvider>()`. If the provider is structurally missing, the app should throw a development exception.

4.  **Global Remediation**
    *   **Action:** Search the codebase for empty catch blocks (`catch (_) {}`, `catch (e) {}`) and naive print statements (`catch (e) { print(e); }`) and apply the appropriate safe logic and logging.

5.  **AppErrorHandler Implementation**
    *   **Action:** Create or update `AppErrorHandler.logSilentError` to use a hybrid mechanism:
        *   **Debug Mode (`kDebugMode`):** Use `developer.log` to print the error and context to the console.
        *   **Release Mode:** Integrate with Firebase Crashlytics (`FirebaseCrashlytics.instance.recordError`) to silently report non-fatal errors without interrupting the user experience.

## Acceptance Criteria
- [ ] Exactly 0 occurrences of `double.parse(` inside empty catch blocks in SMS parser strategies.
- [ ] Exactly 0 occurrences of `firstWhere` without `orElse` throwing ignored exceptions in SIM configuration logic.
- [ ] The empty `catch` block in `_checkPaymentSuccessModal` is completely removed.
- [ ] `AppErrorHandler.logSilentError` correctly differentiates between debug and release modes (Crashlytics).
- [ ] Global search confirms no empty `catch` blocks or raw `print` statements in catch blocks remain for the targeted anti-patterns.
- [ ] `flutter analyze` passes with 0 issues.

## Out of Scope
- Architectural changes to the SMS parsing logic beyond safe number extraction.
- Replacing the Provider state management solution entirely.