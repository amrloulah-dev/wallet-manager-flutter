# Implementation Plan: Business Logic & Domain Integrity Execution Plan (V2)

## Phase 1: Critical Crash Prevention & Error Decoupling [checkpoint: d8709ac]
- [x] Task: Decouple AppErrorHandler from UI components (d5fb222)
    - [ ] Update `lib/core/errors/app_error_handler.dart` to remove `BotToast` and `showDialog` dependencies.
    - [ ] Ensure `AppErrorHandler` only handles logging.
- [x] Task: Fix string interpolation bugs in WalletRepository (28f05dd)
    - [ ] Refactor `wallet_repository.dart` replacing `'...: e'` with `'...: $e'`.
- [x] Task: Purge unsafe null-bang operators (9915d8a)
    - [ ] Update `statistics_provider.dart` to use safe coalescing `??`.
    - [ ] Update `wallet_provider.dart` to throw `ValidationException` instead of using `!`.
- [x] Task: Stop silent balance falsification (4c497ef)
    - [ ] Update `wallet_repository.dart` (`getTotalBalance`, `getWalletsCount`) to re-throw exceptions instead of returning `0.0`.
- [x] Task: Add null-guards for TransactionFeeCalculator (37a6ed1)
    - [ ] Update `transaction_fee_calculator.dart` to early return if `wallet == null`.
- [x] Task: Conductor - User Manual Verification 'Phase 1: Critical Crash Prevention & Error Decoupling' (Protocol in workflow.md) (d8709ac)

## Phase 2: Financial Logic & Boundary Fortification [checkpoint: 58b1f8d]
- [x] Task: Write failing unit tests for AmountValidator and NumberParser (cf378b6)
    - [x] Create/update tests in `test/core/utils/amount_validator_test.dart` for negative, zero, NaN, and Infinity.
    - [x] Create/update tests in `test/core/utils/number_parser_test.dart` for regex logic.
- [x] Task: Implement robust AmountValidator and NumberParser (cf378b6)
    - [x] Update `AmountValidator` (`ensurePositive`, `ensurePositiveOrZero`).
    - [x] Update `NumberParser.toDouble()` to strip non-numeric characters using Regex.
- [x] Task: Write failing unit tests for TransactionValidatorService (3b5866d)
    - [x] Create/update tests in `test/data/services/transaction_validator_service_test.dart` for commission math and floating-point epsilon checks.
- [x] Task: Implement TransactionValidatorService financial boundary fixes (3b5866d)
    - [x] Correct `balanceChange` logic for `isReceive` to account for `commission`.
    - [x] Move `needsDailyReset`/`needsMonthlyReset` check and reset logic into atomic Firestore Transactions.
    - [x] Introduce floating-point epsilon tolerance for strict balance checks.
- [x] Task: Guard Debt Payments (cc57369)
    - [x] Update `DebtRepository.processPayment` with `AmountValidator.ensurePositive()`. (Verified already exists, added test)
- [x] Task: Conductor - User Manual Verification 'Phase 2: Financial Logic & Boundary Fortification' (Protocol in workflow.md) (58b1f8d)

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