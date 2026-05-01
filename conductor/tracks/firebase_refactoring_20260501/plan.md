# Implementation Plan: Firebase & Firestore Refactoring

## Phase 1: Financial Race Conditions [checkpoint: 14a33a8]
- [x] Task: TDD - `WalletRepository` and `stats_repository.dart` Math Operations [840ea34]
    - [x] Write failing test for concurrent balance/stats updates (using `fake_cloud_firestore`).
    - [x] Implement `FieldValue.increment()` for `debitWallet`, `totalWallets`, and `activeWallets`.
    - [x] Verify test passes.
- [x] Task: TDD - Atomic Initialization & Entity Creation [b1bedab]
    - [x] Write failing test for `DatabaseSyncService._createStoreAndUser` creation conflicts and `stats_repository.dart` initialization conflicts.
    - [x] Wrap `_storeRepository.createStore` and `_userRepository.createUser` in a single `WriteBatch`.
    - [x] Implement `SetOptions(merge: true)` for `initializeStats`.
    - [x] Verify test passes.
- [x] Task: Conductor - User Manual Verification 'Financial Race Conditions' (Protocol in workflow.md)

## Phase 2: Billing & Read Optimization
- [~] Task: TDD - Unbounded Queries
    - [ ] Write failing test verifying pagination/limits for `getUsersByStoreId` and `getEmployeesByStoreId`.
    - [ ] Implement `.limit(20)` and Firestore `count()` where applicable.
    - [ ] Verify test passes.
- [ ] Task: TDD - Client-Side Aggregation Removal
    - [ ] Write failing test verifying stats reading directly from `StatsSummaryModel`.
    - [ ] Refactor `statistics_provider.dart` and `transaction_provider.dart` to remove Dart `for loop` aggregations.
    - [ ] Verify test passes.
- [ ] Task: TDD - Client-Side Search Filtering
    - [ ] Write failing test for employee search via Firestore query parameters.
    - [ ] Delegate search filtering in `employee_provider.dart` to Firestore using `.where()` clauses.
    - [ ] Verify test passes.
- [ ] Task: Conductor - User Manual Verification 'Billing & Read Optimization' (Protocol in workflow.md)

## Phase 3: State Management & Architecture
- [ ] Task: TDD - Stale Cache Eviction
    - [ ] Write failing test for cache eviction behavior in `TransactionRepository` and `DebtRepository`.
    - [ ] Update regex to `startsWith('transactions_page_')` to clear all pages.
    - [ ] Verify test passes.
- [ ] Task: TDD - Stateless Pagination
    - [ ] Write failing test for stateless `getDebtsByDateRange` in `debt_repository.dart`.
    - [ ] Remove `_lastDocument` instance variable and refactor method signature.
    - [ ] Verify test passes.
- [ ] Task: TDD - Stream Pipeline Fixes
    - [ ] Write failing test for `watchStatsSummary` initialization and stream emission.
    - [ ] Remove `.asyncMap` from `watchStatsSummary` and move initialization to the provider/repository init phase.
    - [ ] Verify test passes.
- [ ] Task: Conductor - User Manual Verification 'State Management & Architecture' (Protocol in workflow.md)

## Phase 4: Technical Debt Cleanup
- [ ] Task: TDD - Path Constants and Dependency Injection
    - [ ] Write failing test verifying correct paths and singleton access.
    - [ ] Refactor `transaction_repository.dart` and `subscription_repository.dart` to use central path builders.
    - [ ] Replace `FirebaseFirestore.instance` in `employee_repository.dart` with `sl<FirebaseService>().firestore`.
    - [ ] Verify test passes.
- [ ] Task: Conductor - User Manual Verification 'Technical Debt Cleanup' (Protocol in workflow.md)