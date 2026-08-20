# Implementation Plan: Data Drift & Stats Aggregation Patch

## Phase 1: Transaction Pipeline Total Balance Patch (FR-1)
- [ ] Task 1.1: Write failing unit tests for `TransactionValidatorService` verifying `totalBalance` increment/decrement in `stores/{storeId}/stats/summary` during send, receive, and deposit transactions (Red Phase).
- [ ] Task 1.2: Inject `FirebaseConstants.totalBalance: FieldValue.increment(balanceChange)` into `summaryUpdates` in `TransactionValidatorService.validateAndSave` (Green Phase).
- [ ] Task 1.3: Run test suite to verify tests pass and refactor if needed.
- [ ] Task: Phase Verification & Checkpoint (Refer to workflow.md)

## Phase 2: Wallet Deactivation Idempotency Guard (FR-2)
- [ ] Task 2.1: Write failing unit tests for `WalletRepository.setWalletActiveStatus` testing that duplicate calls with identical status do not re-apply stats increments/decrements (Red Phase).
- [ ] Task 2.2: Implement `if (wallet.isActive == isActive) return;` guard in `WalletRepository.setWalletActiveStatus` before `_statsRepository.updateStatsOnWalletChange` (Green Phase).
- [ ] Task 2.3: Run test suite to verify tests pass and refactor if needed.
- [ ] Task: Phase Verification & Checkpoint (Refer to workflow.md)

## Phase 3: Optimistic UI Service Fee Parity (FR-3)
- [ ] Task 3.1: Write failing unit tests for `StatisticsProvider` verifying that optimistic debit transaction deductions correctly subtract `amount + serviceFee` from `totalBalance` (Red Phase).
- [ ] Task 3.2: Update `StatisticsProvider` (`updateLocalStats`, `applyTransactionLocally`, and `addTransactionOptimistically`) to accept `double serviceFee = 0.0` and calculate `newTotalBalance -= (amount + serviceFee)` for debits (Green Phase).
- [ ] Task 3.3: Update `TransactionProvider.createTransaction` to pass `serviceFee: serviceFee` to `sl<StatisticsProvider>().updateLocalStats(...)`.
- [ ] Task 3.4: Run test suite to verify tests pass and refactor if needed.
- [ ] Task: Phase Verification & Checkpoint (Refer to workflow.md)

## Phase 4: Full Suite Regression & Integration Verification
- [ ] Task 4.1: Run full static analysis (`flutter analyze`) and test suite (`flutter test`) to verify zero regressions across all modules.
- [ ] Task: Phase Verification & Checkpoint (Refer to workflow.md)
