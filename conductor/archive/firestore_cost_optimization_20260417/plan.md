# Implementation Plan: Firestore Cost Optimization & Architecture Refactor

## Phase 1: Eradicate Client-Side Aggregation
- [ ] Task: Write Failing Tests
    - [ ] Create/Update tests for `TransactionRepository` to expect the absence of `getTransactionAggregates`.
    - [ ] Create/Update tests for `StatsRepository` to expect the absence of `reconcileStatsFromWallets` and `reconcileStatsFromDebts`.
    - [ ] Create/Update tests for `DebtRepository` to expect the absence of `getDebtAggregates`.
- [ ] Task: Implement to Pass Tests (Delete Aggregations)
    - [ ] Delete `getTransactionAggregates` from `lib/data/repositories/transaction_repository.dart`.
    - [ ] Delete `reconcileStatsFromWallets` from `lib/data/repositories/stats_repository.dart`.
    - [ ] Delete `reconcileStatsFromDebts` from `lib/data/repositories/stats_repository.dart`.
    - [ ] Delete `getDebtAggregates` from `lib/data/repositories/debt_repository.dart`.
    - [ ] Refactor Providers/Controllers calling these methods.
- [ ] Task: Refactor (Optional)
    - [ ] Ensure clean code structure after deletions.
- [ ] Task: Conductor - User Manual Verification 'Eradicate Client-Side Aggregation' (Protocol in workflow.md)

## Phase 2: Implement Cursor-Based Pagination
- [ ] Task: Write Failing Tests
    - [ ] Write tests verifying `getAllTransactions` and `getTransactionsByDateRange` accept a `DocumentSnapshot?` cursor and return a list limited to 20 documents along with the last cursor.
    - [ ] Write tests for `getAllWallets` pagination limits.
    - [ ] Write tests for `getDebtsByDateRange` pagination limits.
- [ ] Task: Implement to Pass Tests (Pagination)
    - [ ] Modify `getAllTransactions` and `getTransactionsByDateRange` in `transaction_repository.dart` with `limit(20)` and `startAfterDocument(lastDocument)`.
    - [ ] Modify `getAllWallets` in `wallet_repository.dart` with `limit(20)` and `startAfterDocument(lastDocument)`.
    - [ ] Modify `getDebtsByDateRange` in `debt_repository.dart` with `limit(20)` and `startAfterDocument(lastDocument)`.
    - [ ] Implement Standard Spinner UI and "Show Error" logic for missing cursors in corresponding UI providers.
- [ ] Task: Refactor (Optional)
    - [ ] Refactor generic pagination logic if repetitive.
- [ ] Task: Conductor - User Manual Verification 'Implement Cursor-Based Pagination' (Protocol in workflow.md)

## Phase 3: Single Source of Truth Subscription
- [ ] Task: Write Failing Tests
    - [ ] Write tests to verify the Dashboard UI Provider depends on `summary` and `daily_stats` streams instead of aggregation methods.
- [ ] Task: Implement to Pass Tests (Dashboard Streams)
    - [ ] Subscribe to `stores/{storeId}/stats/summary` in `StatisticsProvider`.
    - [ ] Subscribe to `stores/{storeId}/daily_stats/{date}` in `StatisticsProvider`.
    - [ ] Update Dashboard UI to read Total Balance, Total Commission, and Transaction counts from these streams.
- [ ] Task: Refactor (Optional)
    - [ ] Optimize stream handling and memory management.
- [ ] Task: Conductor - User Manual Verification 'Single Source of Truth Subscription' (Protocol in workflow.md)

## Phase 4: Enforce Atomic Writes
- [ ] Task: Write Failing Tests
    - [ ] Write tests in `TransactionValidatorService` ensuring `FieldValue.increment()` is used within `WriteBatch` or `Transaction`.
- [ ] Task: Implement to Pass Tests (Atomic Increments)
    - [ ] Refactor `TransactionValidatorService` to strictly use `FieldValue.increment()` for all `summary` and `daily_stats` values (amounts and counts).
    - [ ] Remove any manual arithmetic reading existing fields first (e.g., `total = old + new`).
- [ ] Task: Refactor (Optional)
    - [ ] Run `flutter analyze` and resolve all issues to ensure 0 errors.
- [ ] Task: Conductor - User Manual Verification 'Enforce Atomic Writes' (Protocol in workflow.md)
