# Implementation Plan: Business Logic & Domain Integrity Execution Plan (V2)

## Phase 1: Critical Crash Prevention & Error Decoupling
- [ ] Task: Decouple AppErrorHandler from UI components
    - [ ] Update `lib/core/errors/app_error_handler.dart` to remove `BotToast` and `showDialog` dependencies.
    - [ ] Ensure `AppErrorHandler` only handles logging.
- [ ] Task: Fix string interpolation bugs in WalletRepository
    - [ ] Refactor `wallet_repository.dart` replacing `'...: e'` with `'...: $e'`.
- [ ] Task: Purge unsafe null-bang operators
    - [ ] Update `statistics_provider.dart` to use safe coalescing `??`.
    - [ ] Update `wallet_provider.dart` to throw `ValidationException` instead of using `!`.
- [ ] Task: Stop silent balance falsification
    - [ ] Update `wallet_repository.dart` (`getTotalBalance`, `getWalletsCount`) to re-throw exceptions instead of returning `0.0`.
- [ ] Task: Add null-guards for TransactionFeeCalculator
    - [ ] Update `transaction_fee_calculator.dart` to early return if `wallet == null`.
- [ ] Task: Conductor - User Manual Verification 'Phase 1: Critical Crash Prevention & Error Decoupling' (Protocol in workflow.md)

## Phase 2: Financial Logic & Boundary Fortification
- [ ] Task: Write failing unit tests for AmountValidator and NumberParser
    - [ ] Create/update tests in `test/core/utils/amount_validator_test.dart` for negative, zero, NaN, and Infinity.
    - [ ] Create/update tests in `test/core/utils/number_parser_test.dart` for regex logic.
- [ ] Task: Implement robust AmountValidator and NumberParser
    - [ ] Update `AmountValidator` (`ensurePositive`, `ensurePositiveOrZero`).
    - [ ] Update `NumberParser.toDouble()` to strip non-numeric characters using Regex.
- [ ] Task: Write failing unit tests for TransactionValidatorService
    - [ ] Create/update tests in `test/data/services/transaction_validator_service_test.dart` for commission math and floating-point epsilon checks.
- [ ] Task: Implement TransactionValidatorService financial boundary fixes
    - [ ] Correct `balanceChange` logic for `isReceive` to account for `commission`.
    - [ ] Move `needsDailyReset`/`needsMonthlyReset` check and reset logic into atomic Firestore Transactions.
    - [ ] Introduce floating-point epsilon tolerance for strict balance checks.
- [ ] Task: Guard Debt Payments
    - [ ] Update `DebtRepository.processPayment` with `AmountValidator.ensurePositive()`.
- [ ] Task: Conductor - User Manual Verification 'Phase 2: Financial Logic & Boundary Fortification' (Protocol in workflow.md)

## Phase 3: Domain Model Purity & Serialization Safety
- [ ] Task: Write failing unit tests for Model Deserialization Guards
    - [ ] Create/update tests in `test/data/models/transaction_model_test.dart` and `wallet_model_test.dart`.
- [ ] Task: Implement Domain Model Purity & Serialization Safety
    - [ ] Add `AmountValidator` to `TransactionModel.fromFirestore` for `amount` and `commission`.
    - [ ] Update `StatsSummaryModel` (and similar) to parse missing timestamps as `null` instead of `DateTime.now()`.
    - [ ] Deep copy nested maps/lists in `TransactionModel.toFirestore`.
    - [ ] Update `WalletModel` `==` operator and `hashCode` to evaluate all fields.
- [ ] Task: Conductor - User Manual Verification 'Phase 3: Domain Model Purity & Serialization Safety' (Protocol in workflow.md)

## Phase 4: State Logic & Pagination Fixes
- [ ] Task: Write failing unit tests for State Logic & Pagination Fixes
    - [ ] Create/update tests in `test/data/repositories/transaction_repository_test.dart`, `test/providers/transaction_provider_test.dart`, and `test/data/repositories/stats_repository_test.dart`.
- [ ] Task: Implement State Logic & Pagination Fixes
    - [ ] Remove global mutable `_lastDocument` in `TransactionRepository` and require it as a parameter.
    - [ ] Dynamically initialize `_dateRange` in `TransactionProvider`.
    - [ ] Add `await` to `initializeStats()` in `StatsRepository.watchStatsSummary`.
    - [ ] Add `AppErrorHandler.handle(e)` to empty catch blocks in `WalletProvider` overlay listener.
    - [ ] Remove unused `_walletRepository` field in `WalletUseCase` and redundant `setFilter` alias in `TransactionProvider`.
- [ ] Task: Conductor - User Manual Verification 'Phase 4: State Logic & Pagination Fixes' (Protocol in workflow.md)

## Phase 5: Provider Error Transparency
- [ ] Task: Write failing unit tests for Provider Error Transparency
    - [ ] Create/update tests in `test/providers/transaction_provider_test.dart`, `debt_provider_test.dart`, and `wallet_provider_test.dart` to verify exception propagation.
- [ ] Task: Implement Provider Error Transparency
    - [ ] Refactor methods returning `Future<bool>` in `TransactionProvider`, `DebtProvider`, and `WalletProvider` to propagate `DomainException` to the UI layer instead of returning false.
- [ ] Task: Conductor - User Manual Verification 'Phase 5: Provider Error Transparency' (Protocol in workflow.md)