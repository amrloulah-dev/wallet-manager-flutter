# 🌊 Phase 3: Business Logic & Domain Integrity Execution Plan (V2 - Complete 22 Fixes)

**System Directive:** Act as a Senior Flutter/Firebase Architect. Execute the following phases sequentially to resolve EXACTLY 22 identified architectural flaws.
**Rule:** Understand the "Why" (The Problem) before executing the "How" (The Execution). Do NOT modify UI layers unless explicitly instructed.

---

## Phase 1: Critical Crash Prevention & Error Decoupling

### 🎯 The Problem
The app risks background crashes due to UI dependencies in core error handlers. Unsafe null-bang operators (`!`) cause immediate red-screen crashes. String interpolation bugs swallow critical debug info. Catching network errors and returning `0.0` for balances falsifies financial states. Missing null-guards in usecases lead to immediate crashes.

### 📜 The Execution
1. **Decouple AppErrorHandler:** Refactor `lib/core/errors/app_error_handler.dart`. Remove direct UI imports (like `BotToast`). Make it responsible ONLY for logging. Pass errors to the UI layer to handle visual feedback.
2. **Fix String Interpolation:** In `wallet_repository.dart`, replace instances of `'...: e'` with `'...: $e'`.
3. **Purge Unsafe Null-Bangs:** * In `statistics_provider.dart`, replace `_dashboardSummary!.field` with safe coalescing `_dashboardSummary?.field ?? 0`.
   * In `wallet_provider.dart`, replace `_currentStoreId!` with `_currentStoreId ?? (throw ValidationException('Store ID missing'))`.
4. **Stop Silent Balance Falsification:** In `wallet_repository.dart` (`getTotalBalance` and `getWalletsCount`), remove `return 0.0;` inside the catch block. Re-throw the exception.
5. **Add Null Guards:** In `transaction_fee_calculator.dart`, add `if (wallet == null) return TransactionCalculationResult(..., willExceedLimits: true);` at the top of the method before accessing limits.

---

## Phase 2: Financial Logic & Boundary Fortification

### 🎯 The Problem
Financial methods accept negative values. Commission logic is ignored during receives. Race conditions exist when resetting limits. Strict floating-point comparisons reject valid transactions.

### 📜 The Execution
1. **Robust Amount Validator:** Update `lib/core/utils/amount_validator.dart`.
   * `ensurePositive(value)` must throw a `DomainException` if value is `<= 0`, `isNaN`, or `isInfinite`.
   * Add `ensurePositiveOrZero(value)` for optional fields like commission.
2. **Commission Logic Fix:** In `TransactionValidatorService`, update `balanceChange` logic for `isReceive` to correctly account for `commission` (add/deduct based on business rules).
3. **Guard Debt Payments:** In `DebtRepository.processPayment`, add `AmountValidator.ensurePositive(amountToPay)` to prevent negative payments.
4. **Atomic Limit Resets:** In `TransactionValidatorService`, move the check and reset logic for `needsDailyReset` / `needsMonthlyReset` into a single atomic Firestore `Transaction`.
5. **Floating-Point Epsilon:** In `TransactionValidatorService`, change strict balance checks (e.g., `balance < totalDeduction`) to include an epsilon tolerance (e.g., `(totalDeduction - balance) > 0.0001`) to prevent precision-based false rejections.
6. **Regex Number Parser:** In `NumberParser.toDouble()`, use `replaceAll(RegExp(r'[^0-9.]'), '')` to strip non-numeric characters.

---

## Phase 3: Domain Model Purity & Serialization Safety

### 🎯 The Problem
Models mask missing timestamps with `DateTime.now()`. `WalletModel` equality (`==`) is incomplete. Deserialization allows negative amounts. Mutable nested lists pose reference-mutation risks.

### 📜 The Execution
1. **Model Deserialization Guards:** In `TransactionModel.fromFirestore`, validate `amount` and `commission` using `AmountValidator`.
2. **Remove Timestamp Masking:** In `StatsSummaryModel` (and similar), parse missing `lastUpdated` or `createdAt` as `null` instead of generating `DateTime.now()`.
3. **Deep Copy Firestore Maps:** In `TransactionModel.toFirestore`, ensure nested lists/maps are deep-copied (e.g., `List.from()`).
4. **Complete Equality:** Update `WalletModel` `==` operator and `hashCode` to evaluate ALL fields (limits, dates, stats).

---

## Phase 4: State Logic & Pagination Fixes

### 🎯 The Problem
Mutable cursor states leak pagination across screens. Date ranges become stale. Statistics streams emit empty data while initializing.

### 📜 The Execution
1. **Pagination State:** In `TransactionRepository`, remove the global mutable `_lastDocument`. Require `_lastDocument` as a passed parameter.
2. **Dynamic Date Range:** In `TransactionProvider`, remove the static `DateTime.now()` initialization for `_dateRange`. Initialize it dynamically so it refreshes correctly across days.
3. **Await Stats Initialization:** In `StatsRepository.watchStatsSummary`, ensure `initializeStats()` is properly `await`ed and its result is emitted to the stream instead of emitting an empty model.
4. **Overlay Silent Catch:** In `WalletProvider`, add `AppErrorHandler.handle(e)` to the empty `catch (_)` block for the overlay listener.
5. **Dead Code Elimination:** Remove the unused `_walletRepository` field from `WalletUseCase`. Remove the redundant `setFilter` alias in `TransactionProvider`.

---

## Phase 5: Provider Error Transparency (Future<bool> Anti-Pattern)

### 🎯 The Problem
Providers return generic `Future<bool>` for operations (create, pay, send). If they fail, the UI receives `false` without knowing the specific error (e.g., network vs validation), leading to generic, unhelpful error messages.

### 📜 The Execution
1. **Refactor Provider Returns:** In `TransactionProvider`, `DebtProvider`, and `WalletProvider`, audit methods returning `Future<bool>`.
2. **Propagate Exceptions:** Instead of catching `AppException` internally and returning `false`, either:
   * Return a `Result<T, Exception>` wrapper.
   * OR allow the `DomainException` to propagate up so the UI layer can catch it and display the specific `e.message` to the user.