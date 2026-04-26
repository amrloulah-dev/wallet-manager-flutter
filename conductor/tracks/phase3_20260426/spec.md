# Specification: Phase 3 - Business Logic & Domain Integrity

## Overview
Remediate financial validation deficits, silent stream failures, and domain model fragility as identified in the Phase 3 Audit. Transform "silent" data channels (Streams) into reactive, error-aware pipelines. Replace all "Magic Strings" with type-safe Enums to ensure long-term stability.

## Functional Requirements
1. **Financial Fortification:**
   - **Amount Validator:** Create `lib/core/utils/amount_validator.dart` with `ensurePositive(double value)` that throws a `DomainException` if <= 0. Apply as the first line in repository methods (`processPayment`, `addExpense`, etc.).
   - **Atomic Ceiling Checks:** Refactor `DebtRepository.processPayment` to use `FirebaseFirestore.instance.runTransaction`. Throw an `InvalidAmountException` if `paymentAmount > amountDue`.
   - **Counter Integrity:** Ensure statistics counters (e.g., employee count) never decrement below zero.
2. **Stream Reliability & Cost Optimization:**
   - **Error Propagation:** In `UserRepository`, `StoreRepository`, and `EmployeeRepository`, replace empty `.handleError` blocks with `.handleError((e) => AppErrorHandler.handle(e))` and re-emit via `Stream.error(e)`.
   - **Cost Capping:** Add `.limit(100)` to all employee-related snapshots to prevent unbounded reads.
   - **Listener Safety:** Update `SystemConfigProvider` and all other `.listen()` callers to include an explicit `onError` parameter.
3. **Domain Purity & Enum Migration:**
   - **Enhanced Enums:** Create Enums for `DebtStatus`, `WalletType`, `SubscriptionStatus`, plus additional Enums needed for `EmployeeModel` and `StoreModel`.
   - **Model Refactoring:** Update `WalletModel`, `DebtModel`, `TransactionModel`, `EmployeeModel`, and `StoreModel` to use Enums instead of raw Strings.
   - **Safe Serialization:** In `fromFirestore` methods, return null for missing timestamps (no fabricating `Timestamp.now()`). Replace hard casts with safe fallbacks (`data['field'] as String? ?? ''`). Log occurrences of corrupt data.
4. **UX Responsiveness & Handling:**
   - **Immediate Feedback:** All Provider actions must call `setLoading(true)` or `safeNotify()` immediately and reset `_errorMessage = null;` before starting async work.
   - **Error Display:** `DomainException` and `InvalidAmountException` must be shown as transient Toast/Snackbar messages via `AppErrorHandler` without blocking the user.
   - **UI Rounding:** Implement `.toStringAsFixed(2)` across the presentation layer to prevent double precision drift artifacts.

## Non-Functional Requirements
- **Security:** SHA-256 PIN hashing will remain as-is, supported by strict Firestore Security Rules.

## Acceptance Criteria
- Monetary fields strictly reject non-positive inputs.
- `processPayment` atomically prevents over-payment.
- Stream errors are properly surfaced to the UI via Toasts/Snackbars.
- `EmployeeModel`, `StoreModel`, `WalletModel`, `DebtModel`, and `TransactionModel` exclusively use Enums for statuses/types.
- Corrupt or missing Firestore data defaults gracefully and logs the issue.
- UI elements do not display floating-point artifacts (e.g., 10.00 instead of 10.0000000001).

## Out of Scope
- Changes to the authentication/PIN hashing mechanism.