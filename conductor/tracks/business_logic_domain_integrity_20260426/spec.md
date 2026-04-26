# Specification: Business Logic & Domain Integrity Execution Plan (V2)

## Overview
This track addresses exactly 22 identified architectural flaws within the Wallet Manager application, focusing on critical crash prevention, financial logic boundary fortification, domain model purity, state logic fixes, and provider error transparency.

## Functional Requirements
The implementation is broken down into 5 phases:

1.  **Phase 1: Critical Crash Prevention & Error Decoupling**
    *   Refactor `AppErrorHandler` to be strictly responsible for logging and decoupled from UI components.
    *   Fix string interpolation errors in `wallet_repository.dart`.
    *   Replace unsafe null-bang operators (`!`) with safe coalescing operators (`??`) in `statistics_provider.dart` and `wallet_provider.dart`.
    *   Remove silent balance falsification (`return 0.0;`) in `wallet_repository.dart` catch blocks.
    *   Add null-guards in `transaction_fee_calculator.dart`.

2.  **Phase 2: Financial Logic & Boundary Fortification**
    *   Update `AmountValidator` (`ensurePositive` and `ensurePositiveOrZero`) to throw `DomainException` for invalid values.
    *   Correct the balance change logic in `TransactionValidatorService` for `isReceive` to account for `commission`.
    *   Prevent negative payments in `DebtRepository.processPayment` using `AmountValidator`.
    *   Consolidate `needsDailyReset`/`needsMonthlyReset` into atomic Firestore transactions in `TransactionValidatorService`.
    *   Introduce floating-point epsilon checks in `TransactionValidatorService` for strict balance checks.
    *   Use Regex in `NumberParser.toDouble()` to strip non-numeric characters.

3.  **Phase 3: Domain Model Purity & Serialization Safety**
    *   Validate `amount` and `commission` in `TransactionModel.fromFirestore` via `AmountValidator`.
    *   Replace `DateTime.now()` with `null` parsing for missing timestamps in models (e.g., `StatsSummaryModel`).
    *   Deep copy nested maps/lists in `TransactionModel.toFirestore`.
    *   Enhance `WalletModel` equality (`==`) and `hashCode` to evaluate all fields.

4.  **Phase 4: State Logic & Pagination Fixes**
    *   Remove global mutable `_lastDocument` in `TransactionRepository` and require it as a parameter.
    *   Dynamically initialize `_dateRange` in `TransactionProvider`.
    *   Properly await `initializeStats()` in `StatsRepository.watchStatsSummary`.
    *   Handle silent catch blocks in overlay listeners by explicitly logging via `AppErrorHandler`.
    *   Remove unused/redundant code (e.g., `_walletRepository` in `WalletUseCase`, `setFilter` alias).

5.  **Phase 5: Provider Error Transparency**
    *   Refactor methods returning `Future<bool>` in `TransactionProvider`, `DebtProvider`, and `WalletProvider`.
    *   Propagate `DomainException` to the UI layer instead of internally catching and returning `false`.

## Non-Functional Requirements
*   **Testing:** Focus exclusively on Unit Tests for core domain logic. Write exhaustive unit tests for `AmountValidator` (testing negative, zero, NaN, and Infinity), `NumberParser` regex logic, and `TransactionValidatorService` (focusing on commission math and floating-point epsilon checks). No UI or Integration tests are required for error handlers or providers. Ensure Firestore transaction logic is testable with mocks.
*   **Rollout Strategy:** Implement changes via Phase-by-phase PRs to minimize risk and simplify review.