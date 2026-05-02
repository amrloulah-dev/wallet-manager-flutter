# Specification: Firebase & Firestore Refactoring

## 1. Overview
Refactor specific repositories and providers in Wallet Manager to fix financial race conditions, prevent billing explosions, and resolve architectural issues based on the Phase 4 blueprint. The project operates on a $0 budget (Firebase Spark Plan), so optimizing reads and ensuring data atomicity is critical.

## 2. Functional Requirements
### 2.1. Financial Race Conditions
*   **Transactions:** Refactor all math operations inside Firestore transactions to use `FieldValue.increment()` to ensure atomic updates. Apply this to `WalletRepository.debitWallet` and `stats_repository.dart` (`totalWallets`, `activeWallets`).
*   **Initialization Conflicts:** Wrap store and user creation in `DatabaseSyncService._createStoreAndUser` within a single `WriteBatch`. Use `SetOptions(merge: true)` in `stats_repository.dart` (`initializeStats`) to handle concurrent initializations.

### 2.2. Prevent Billing Explosions
*   **Unbounded Queries:** Add `.limit(20)` (or suitable pagination) to `getUsersByStoreId` and `getEmployeesByStoreId` in `UserRepository` and `EmployeeRepository`. Use Firestore `count()` if totals are needed.
*   **Client-Side Aggregation:** Remove Dart `for loop` aggregations in `statistics_provider.dart` and `transaction_provider.dart`. Read directly from `StatsSummaryModel` at `stores/{storeId}/stats/summary`.
*   **Search Filtering:** Delegate employee search filtering to Firestore using query parameters (`where` clauses) instead of filtering in Dart memory within `employee_provider.dart`.

### 2.3. State Management & Architecture
*   **Stale Cache:** Update cache eviction regex in `TransactionRepository` and `DebtRepository` to clear all pages (`startsWith('transactions_page_')`).
*   **Stateless Pagination:** Remove `_lastDocument` instance variable in `debt_repository.dart` and refactor methods to accept `DocumentSnapshot? lastDocument` as a parameter.
*   **Stream Pipelines:** Remove `.asyncMap` from `watchStatsSummary` in `stats_repository.dart` to prevent UI flashing, ensuring initialization is handled prior to watching the stream.

### 2.4. Technical Debt Cleanup
*   **Path Constants:** Refactor `transaction_repository.dart` and `subscription_repository.dart` to use central path builders (e.g., `FirebaseConstants.statsSubcollection`).
*   **Dependency Injection:** Replace `FirebaseFirestore.instance` constructor defaults in `employee_repository.dart` with singleton access (`sl<FirebaseService>().firestore`).

## 3. Non-Functional Requirements
*   **Scope:** Flexible. Primarily targeting the files listed above, but modifications to directly impacted related files are permitted.
*   **Performance:** Drastically reduce Firestore read operations.
*   **Atomicity:** 100% data accuracy for all financial transactions under concurrent loads.

## 4. Testing Strategy
*   Prioritize unit/integration tests using the existing `fake_cloud_firestore` package to verify transactions, atomic batches, and `FieldValue` updates without setting up a local emulator.

## 5. Rollback Strategy
*   **Git Revert:** Ensure all changes are isolated in a single branch/track to allow for an easy and clean `git revert` if structural database changes cause unforeseen issues.

## 6. Out of Scope
*   Adding new features or changing the overall application architecture.
*   Migrating away from Firebase/Firestore or utilizing Cloud Functions.