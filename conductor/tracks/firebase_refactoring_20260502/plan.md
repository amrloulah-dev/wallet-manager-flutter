# Implementation Plan: Firebase & Firestore Refactoring Blueprint

## Phase 1: Atomicity Leaks Remediation
- [x] Task: TDD - `WalletRepository` Atomicity
    - [x] Write failing tests verifying that `creditWallet` and `debitWallet` execute stats updates within the same transaction.
    - [x] Implement refactoring in `WalletRepository` to move stats updates inside the main wallet transaction.
    - [x] Ensure tests pass.
- [x] Task: TDD - `TransactionRepository` Atomicity
    - [x] Write failing tests verifying that `createTransaction` executes stats calls inside the `validateAndSave` transaction block.
    - [x] Implement refactoring in `TransactionRepository`.
    - [x] Ensure tests pass.
- [x] Task: Global Audit - Atomicity
    - [x] Scan ALL repositories for database writes or stats updates occurring sequentially after a `runTransaction` or `WriteBatch`.
    - [x] Write failing tests for any identified leaks.
    - [x] Refactor identified leaks to be inside the atomic block (e.g., `EmployeeRepository.addEmployee` optimization).
    - [x] Ensure tests pass.
- [x] Task: Conductor - User Manual Verification 'Phase 1: Atomicity Leaks Remediation' (Protocol in workflow.md)

## Phase 2: Unbounded Queries Remediation
- [x] Task: TDD - `MigrationService` Unbounded Queries
    - [x] Write failing tests verifying `recalculateStoreStats` uses aggregate queries (`count()`, `sum()`).
    - [x] Implement refactoring in `MigrationService` to replace `.get()` with aggregate queries.
    - [x] Ensure tests pass.
- [x] Task: Global Audit - Unbounded Queries
    - [x] Scan ALL services and repositories for `.get()` without `.limit()`.
    - [x] Write failing tests for identified unbounded queries (verifying limits or aggregate usage).
    - [x] Refactor identified queries to add `.limit(500)` or use aggregate queries.
    - [x] Ensure tests pass.
- [x] Task: Conductor - User Manual Verification 'Phase 2: Unbounded Queries Remediation' (Protocol in workflow.md)

## Phase 3: Error Handling Remediation
- [x] Task: TDD - `MigrationService` Error Handling
    - [x] Write failing tests verifying that `MigrationService` operations catch `FirebaseException` and map it to `ServerException`.
    - [x] Implement explicit `try/catch` blocks targeting `FirebaseException` in `MigrationService` and map to `AppErrorHandler`.
    - [x] Ensure tests pass.
- [x] Task: Global Audit - Error Handling
    - [x] Scan all `services/` for unprotected Firebase interactions.
    - [x] Write failing tests verifying error interception.
    - [x] Wrap identified interactions in secure `try/catch` blocks mapped to `AppErrorHandler`.
    - [x] Ensure tests pass.
- [x] Task: Conductor - User Manual Verification 'Phase 3: Error Handling Remediation' (Protocol in workflow.md)