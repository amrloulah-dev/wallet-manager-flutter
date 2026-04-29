# Implementation Plan: Firestore Architecture & Billing Optimization

## Phase 1: Stopping the Billing Leaks (Query Optimization)
- [ ] Task: Wallet Aggregation Leak (C-001, C-002) in `wallet_repository.dart`
    - [ ] Write failing test: Verify `getTotalBalance` and `getWalletsCount` fetch from `stats/summary` instead of the `wallets` collection using the Firebase Emulator.
    - [ ] Implement to pass tests: Replace unbounded `.get()` queries with single document reads.
- [ ] Task: Employee Count Leak (C-003) in `employee_repository.dart`
    - [ ] Write failing test: Verify employee count calculation uses the native index counting `.count()` using the Firebase Emulator.
    - [ ] Implement to pass tests: Replace querying all employee documents with the `.count()` method.
- [ ] Task: Conductor - User Manual Verification 'Phase 1: Stopping the Billing Leaks' (Protocol in workflow.md)

## Phase 2: Atomic Operations & Race Condition Prevention
- [ ] Task: The TOCTOU Registration Race (C-007) in `subscription_repository.dart`
    - [ ] Write failing test: Simulate concurrent `verifyDevice` calls in the Emulator and assert atomic writes to `firstSeenAt`/`lastSeenAt`.
    - [ ] Implement to pass tests: Wrap `verifyDevice` logic inside `_firestore.runTransaction`.
- [ ] Task: The Stats Desync Nightmare (C-004, C-005) in `wallet_repository.dart` and `stats_repository.dart`
    - [ ] Write failing test: Verify `toggleWalletStatus` atomically updates the wallet state and `stats/summary` metrics simultaneously in the Emulator.
    - [ ] Implement to pass tests: Implement a unified `runTransaction` for wallet toggles and remove dual-write to legacy root stats fields.
- [ ] Task: The 500-Limit Batch Crash (C-008) in `wallet_repository.dart`
    - [ ] Write failing test: Attempt to invoke `resetLimitsForWallets` with over 500 wallets in the Emulator and verify successful sequential processing.
    - [ ] Implement to pass tests: Introduce a chunk size of 450 items and implement array chunking for the `WriteBatch`.
- [ ] Task: Conductor - User Manual Verification 'Phase 2: Atomic Operations & Race Condition Prevention' (Protocol in workflow.md)

## Phase 3: Eradicating Tech Debt & Silent Failures
- [ ] Task: The Silent Fraud Bypass (M-003, M-006, M-009)
    - [ ] Write failing test: Enforce failure using the Firebase Emulator (e.g., via strict Firebase Security Rules that deny writes) to ensure `DomainException` propagates correctly.
    - [ ] Implement to pass tests: Remove empty `catch` blocks and replace silent defaults with `throw` or `return false`, propagating `DomainException`.
- [ ] Task: Time Travel and Magic Strings (M-002, M-008, M-004)
    - [ ] Write failing test: Verify timestamps and strings use `FirebaseConstants` and `FieldValue.serverTimestamp()` in the Emulator.
    - [ ] Implement to pass tests: Standardize strings to constants, update all `Timestamp.now()` writes to `FieldValue.serverTimestamp()`, and fix string interpolations.
- [ ] Task: The Duplicate Stats Hazard (M-001)
    - [ ] Write failing test: Verify `StatsRepository` no longer exposes isolated transaction stats update methods.
    - [ ] Implement to pass tests: Delete `updateStatsOnTransactionCreate` from `StatsRepository` to enforce `TransactionValidatorService` usage.
- [ ] Task: Untestable Repositories (M-005) in `SystemConfigRepository`
    - [ ] Write failing test: Verify `SystemConfigRepository` correctly uses the injected `FirebaseFirestore` instance connected to the Emulator.
    - [ ] Implement to pass tests: Refactor the constructor to inject `FirebaseFirestore` alongside standard dependency injection.
- [ ] Task: Conductor - User Manual Verification 'Phase 3: Eradicating Tech Debt & Silent Failures' (Protocol in workflow.md)

## Phase 4: Data Migration
- [ ] Task: One-Time Migration Script
    - [ ] Write failing test: Write tests against the Emulator to ensure the migration script correctly recalculates actual wallet balances and document counts, and successfully overwrites the desynced `stats/summary` document.
    - [ ] Implement to pass tests: Implement the migration script to perform the recalculation and `stats/summary` update to restore financial integrity.
- [ ] Task: Conductor - User Manual Verification 'Phase 4: Data Migration' (Protocol in workflow.md)