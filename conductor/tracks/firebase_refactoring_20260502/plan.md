# Implementation Plan: Firebase & Firestore Refactoring Blueprint

## Phase 1: Atomicity Leaks Remediation
- [ ] Task: TDD - `WalletRepository` Atomicity
    - [ ] Write failing tests verifying that `creditWallet` and `debitWallet` execute stats updates within the same transaction.
    - [ ] Implement refactoring in `WalletRepository` to move stats updates inside the main wallet transaction.
    - [ ] Ensure tests pass.
- [ ] Task: TDD - `TransactionRepository` Atomicity
    - [ ] Write failing tests verifying that `createTransaction` executes stats calls inside the `validateAndSave` transaction block.
    - [ ] Implement refactoring in `TransactionRepository`.
    - [ ] Ensure tests pass.
- [ ] Task: Global Audit - Atomicity
    - [ ] Scan ALL repositories for database writes or stats updates occurring sequentially after a `runTransaction` or `WriteBatch`.
    - [ ] Write failing tests for any identified leaks.
    - [ ] Refactor identified leaks to be inside the atomic block.
    - [ ] Ensure tests pass.
- [ ] Task: Conductor - User Manual Verification 'Phase 1: Atomicity Leaks Remediation' (Protocol in workflow.md)

## Phase 2: Unbounded Queries Remediation
- [ ] Task: TDD - `MigrationService` Unbounded Queries
    - [ ] Write failing tests verifying `recalculateStoreStats` uses aggregate queries (`count()`, `sum()`).
    - [ ] Implement refactoring in `MigrationService` to replace `.get()` with aggregate queries.
    - [ ] Ensure tests pass.
- [ ] Task: Global Audit - Unbounded Queries
    - [ ] Scan ALL services and repositories for `.get()` without `.limit()`.
    - [ ] Write failing tests for identified unbounded queries (verifying limits or aggregate usage).
    - [ ] Refactor identified queries to add `.limit(500)` or use aggregate queries.
    - [ ] Ensure tests pass.
- [ ] Task: Conductor - User Manual Verification 'Phase 2: Unbounded Queries Remediation' (Protocol in workflow.md)

## Phase 3: Error Handling Remediation
- [ ] Task: TDD - `MigrationService` Error Handling
    - [ ] Write failing tests verifying that `MigrationService` operations catch `FirebaseException` and map it to `ServerException`.
    - [ ] Implement explicit `try/catch` blocks targeting `FirebaseException` in `MigrationService` and map to `AppErrorHandler`.
    - [ ] Ensure tests pass.
- [ ] Task: Global Audit - Error Handling
    - [ ] Scan all `services/` for unprotected Firebase interactions.
    - [ ] Write failing tests verifying error interception.
    - [ ] Wrap identified interactions in secure `try/catch` blocks mapped to `AppErrorHandler`.
    - [ ] Ensure tests pass.
- [ ] Task: Conductor - User Manual Verification 'Phase 3: Error Handling Remediation' (Protocol in workflow.md)