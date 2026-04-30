# Specification: Firestore Architecture & Billing Optimization

## Overview
This track addresses "silent bleeding" of Firestore billing and critical financial race conditions. It optimizes queries from $O(N)$ document reads to $O(1)$ aggregations, implements native index counting, and wraps multi-step financial updates in atomic transactions to guarantee data integrity. Additionally, tech debt such as silent error swallowing and hardcoded strings will be eradicated.

## Scope
- **Strictly as planned:** Modifications will be strictly limited to the repositories explicitly listed in the execution plan (`wallet_repository.dart`, `employee_repository.dart`, `subscription_repository.dart`, `stats_repository.dart`, `TransactionValidatorService`, `SystemConfigRepository`).

## Functional Requirements
1. **Wallet Aggregation Optimization:** Replace unbounded reads for balance/counts with reads from the single `stats/summary` document in `wallet_repository.dart`.
2. **Employee Count Optimization:** Utilize Firestore native index counting (`.count()`) in `employee_repository.dart` instead of retrieving all user documents.
3. **Atomic TOCTOU Prevention:** Wrap the `verifyDevice` logic in `subscription_repository.dart` with a `runTransaction` block to prevent duplicate timestamp overwrites.
4. **Atomic Stats Sync:** Refactor `toggleWalletStatus` in `wallet_repository.dart` and `stats_repository.dart` to update both wallet state and stats atomically, eliminating the dual-write to legacy root fields.
5. **Batch Operation Chunking:** Implement chunking (max 450 items per batch) in `resetLimitsForWallets` to bypass the Firestore 500-operation limit.
6. **Error Handling Remediation:** Remove empty catch blocks and default success returns on failure. Propagate `DomainException` using `AppErrorHandler` for UI visibility.
7. **Timestamp and String Standardization:** Replace client-side `Timestamp.now()` with `FieldValue.serverTimestamp()`. Move hardcoded strings to `FirebaseConstants`.
8. **Method Deduplication:** Delete `updateStatsOnTransactionCreate` from `StatsRepository` to force usage of the secure `TransactionValidatorService`.
9. **Repository Testability:** Inject `FirebaseFirestore` via the constructor into `SystemConfigRepository`.

## Non-Functional Requirements
1. **Performance:** Substantially reduce document read latency and billing costs.
2. **Data Integrity:** Eliminate race conditions in balance calculations and device registrations.
3. **Testability:** Refactored repositories must be testable via dependency injection.

## Acceptance Criteria
1. All targeted optimizations are implemented as specified.
2. All modified logic passes automated tests running against the local **Firebase Emulator**.
3. No unhandled `FirebaseException` escapes during concurrent testing.
4. System Config repository can be successfully instantiated with a mocked/injected Firestore instance in tests.

## Out of Scope
- Auditing or optimizing repositories not explicitly mentioned in the provided execution plan.
- Migrating the entire backend away from Firebase/Firestore.