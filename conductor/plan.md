# Implementation Plan: Firestore Cost Optimization & Architecture Refactor

## Phase 1: Eradicate Client-Side Aggregation [checkpoint: 290da2c]
- [x] Task: Write Failing Tests
    - [x] Create/Update tests for `TransactionRepository` to expect the absence of `getTransactionAggregates`.
    - [x] Create/Update tests for `StatsRepository` to expect the absence of `reconcileStatsFromWallets` and `reconcileStatsFromDebts`.
    - [x] Create/Update tests for `DebtRepository` to expect the absence of `getDebtAggregates`.
- [x] Task: Implement to Pass Tests (Delete Aggregations) [1c561f4]
    - [x] Delete `getTransactionAggregates` from `lib/data/repositories/transaction_repository.dart`.
    - [x] Delete `reconcileStatsFromWallets` from `lib/data/repositories/stats_repository.dart`.
    - [x] Delete `reconcileStatsFromDebts` from `lib/data/repositories/stats_repository.dart`.
    - [x] Delete `getDebtAggregates` from `lib/data/repositories/debt_repository.dart`.
    - [x] Refactor Providers/Controllers calling these methods.
- [x] Task: Refactor (Optional)
    - [x] Ensure clean code structure after deletions.
- [x] Task: Conductor - User Manual Verification 'Eradicate Client-Side Aggregation' (Protocol in workflow.md)

## Phase 2: Implement Cursor-Based Pagination
- [x] Task: Write Failing Tests
    - [x] Write tests verifying `getAllTransactions` and `getTransactionsByDateRange` accept a `DocumentSnapshot?` cursor and return a list limited to 20 documents along with the last cursor.
    - [x] Write tests for `getAllWallets` pagination limits.
    - [x] Write tests for `getDebtsByDateRange` pagination limits.
- [x] Task: Implement to Pass Tests (Pagination)
    - [x] Modify `getAllTransactions` and `getTransactionsByDateRange` in `transaction_repository.dart` with `limit(20)` and `startAfterDocument(lastDocument)`.
    - [x] Modify `getAllWallets` in `wallet_repository.dart` with `limit(20)` and `startAfterDocument(lastDocument)`.
    - [x] Modify `getDebtsByDateRange` in `debt_repository.dart` with `limit(20)` and `startAfterDocument(lastDocument)`.
    - [x] Implement Standard Spinner UI and "Show Error" logic for missing cursors in corresponding UI providers.
- [x] Task: Refactor (Optional)
    - [x] Refactor generic pagination logic if repetitive.
- [x] Task: Conductor - User Manual Verification 'Implement Cursor-Based Pagination' (Protocol in workflow.md)

## Phase 3: Single Source of Truth Subscription
- [x] Task: Write Failing Tests
    - [x] Write tests to verify the Dashboard UI Provider depends on `summary` and `daily_stats` streams instead of aggregation methods.
- [x] Task: Implement to Pass Tests (Dashboard Streams)
    - [x] Subscribe to `stores/{storeId}/stats/summary` in `StatisticsProvider`.
    - [x] Subscribe to `stores/{storeId}/daily_stats/{date}` in `StatisticsProvider`.
    - [x] Update Dashboard UI to read Total Balance, Total Commission, and Transaction counts from these streams.
- [x] Task: Refactor (Optional)
    - [x] Optimize stream handling and memory management.
- [x] Task: Conductor - User Manual Verification 'Single Source of Truth Subscription' (Protocol in workflow.md)

## Phase 4: Enforce Atomic Writes
- [ ] Task: Write Failing Tests
    - [ ] Write tests in `TransactionValidatorService` ensuring `FieldValue.increment()` is used within `WriteBatch` or `Transaction`.
- [ ] Task: Implement to Pass Tests (Atomic Increments)
    - [ ] Refactor `TransactionValidatorService` to strictly use `FieldValue.increment()` for all `summary` and `daily_stats` values (amounts and counts).
    - [ ] Remove any manual arithmetic reading existing fields first (e.g., `total = old + new`).
- [ ] Task: Refactor (Optional)
    - [ ] Run `flutter analyze` and resolve all issues to ensure 0 errors.
- [ ] Task: Conductor - User Manual Verification 'Enforce Atomic Writes' (Protocol in workflow.md)