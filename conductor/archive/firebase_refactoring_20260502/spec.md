# Specification: Firebase & Firestore Refactoring Blueprint

## 1. Overview
Address critical Firebase architecture leaks in Wallet Manager. This includes fixing atomicity leaks in financial operations, unbounded queries causing memory/billing issues, and incomplete error handling for `FirebaseException`. The project will follow a Strict TDD approach and apply fixes globally.

## 2. Functional Requirements

### 2.1. Atomicity Leaks (Data Integrity)
- **Requirement:** All related mutations for a financial operation MUST happen inside a single `runTransaction` block.
- **Specific Fixes:**
  - `WalletRepository` (`creditWallet`, `debitWallet`): Move stats update inside the main wallet transaction.
  - `TransactionRepository` (`createTransaction`): Move stats calls (e.g., `incrementOpenDebtStats`) inside the `validateAndSave` transaction block.
- **Global Audit:** Perform an immediate global audit across ALL repositories. Refactor any database write or stats update occurring sequentially after a `runTransaction` or `WriteBatch` to be inside the atomic block.

### 2.2. Unbounded Queries (Billing Explosions)
- **Requirement:** Eliminate unbounded `.get()` queries pulling massive datasets into memory.
- **Specific Fixes:**
  - `MigrationService` (`recalculateStoreStats`): Use Firestore Aggregate Queries (`count()`, `sum()`) to calculate stats directly on the server.
- **Global Audit:** Scan ALL services and repositories. Add `.limit()` or use aggregate queries for any unbounded `.get()` list operations found.

### 2.3. Incomplete Error Handling
- **Requirement:** Ensure all Firebase operations have explicit error handling for `FirebaseException`.
- **Specific Fixes:**
  - `MigrationService`: Wrap logic in `try/catch` targeting `FirebaseException`. Map it to `ServerException` and pass to `AppErrorHandler`.
- **Global Audit:** Scan all `services/`. Ensure all Firebase interactions are securely wrapped and mapped to `AppErrorHandler`.

## 3. Non-Functional Requirements
- **Testing:** Strict TDD must be followed. Explicit tests for atomicity and data bounds must be written *before* refactoring.
- **Budget constraints:** Solutions must align with the $0 Budget (Spark Plan) constraint (e.g., minimal reads, no Cloud Functions).
- **Financial Atomicity:** 100% atomicity required. No partial failures.

## 4. Acceptance Criteria
- [ ] No database writes or stats updates occur sequentially after a completed transaction.
- [ ] No unbounded `.get()` queries exist in the codebase without `.limit()` or being replaced by aggregate queries.
- [ ] All Firebase interactions are wrapped in `try/catch` blocks targeting `FirebaseException` and utilizing `AppErrorHandler`.
- [ ] All changes are covered by automated tests proving atomicity, bounds limits, and error handling.

## 5. Out of Scope
- Major architectural changes outside of the explicitly mentioned Firebase atomicity, unbounded query, and error handling fixes.
- Refactoring business logic unrelated to Firebase interactions.