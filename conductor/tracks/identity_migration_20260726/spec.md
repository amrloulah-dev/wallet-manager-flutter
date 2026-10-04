# Specification: Identity Unification & Silent Data Migration

## Overview
Employee documents in Firestore currently use auto-generated document IDs (`_usersCollection.doc().id` / `.add()`) while the employee's Firebase Auth UID is stored in the `firebaseUid` field. This mismatch causes Firestore Security Rules to fail (`doc.id != request.auth.uid`) since rules compare `request.auth.uid` against the document ID.

This track refactors the employee creation flow so new employees are persisted with `doc.id == firebaseUid`, implements a silent identity migration use case to transparently fix existing legacy employee documents and their foreign key references during the Store Owner sync cycle, and removes temporary fallback queries that were added to work around the mismatch.

## Functional Requirements

### FR-1: Refactor Employee Creation Flow
- **FR-1.1:** In `EmployeeRepository.addEmployee()`, replace the current `_usersCollection.doc().id` + `transaction.set(_usersCollection.doc(newUserId), userData)` pattern. Instead, call `IdentityService.provisionIdentity()` FIRST to generate the Auth UID, then use that UID as the document ID: `_usersCollection.doc(authUid).set(userData)` within the existing transaction.
- **FR-1.2:** The `firebaseUid` field inside the document data must be set to the Auth UID at creation time (not left as `null` and backfilled later).
- **FR-1.3:** The separate `provisionIdentity()` call currently invoked after `addEmployee()` in `EmployeeProvider` must be removed, since identity is now provisioned as an awaited sequential step inline within the creation flow itself. The existing architecture intentionally awaits this call to obtain the canonical Auth UID before updating local RAM — this await-first contract must be preserved in the refactored flow.
- **FR-1.4:** `userId` is always derived from `doc.id` via `UserModel.fromFirestore()` — no need to write it into document data.

### FR-2: Silent Identity Migration UseCase
- **FR-2.1:** Create `IdentityMigrationUseCase` in `lib/domain/usecases/identity_migration_usecase.dart`.
- **FR-2.2:** Implement `executeMigration(String currentStoreId)` that:
  - Queries the `users` collection where `storeId == currentStoreId` AND `role == employee`.
  - Filters employees where `doc.id != firebaseUid` AND `firebaseUid != null && firebaseUid.isNotEmpty`.
  - For each mismatched employee:
    - Creates a new document at `_usersCollection.doc(employee.firebaseUid)` with the employee's existing data.
    - Queries `wallets`, `transactions`, and `debts` where `storeId == currentStoreId`.
    - Updates foreign key references in a `WriteBatch`:
      - **Wallets:** `createdBy` where it matches the old doc ID.
      - **Transactions:** `createdBy`, `createdById`, `updatedBy`, `deletedBy` where they match the old doc ID.
      - **Debts:** `createdBy`, `markedPaidBy`, `lastUpdatedBy` where they match the old doc ID.
      - **Pin Locks:** Update the `userId` field in `stores/{storeId}/pin_locks/{hashedPin}` documents that reference the old doc ID, so employees can continue authenticating with their PINs.
    - Deletes the old employee document.
  - Commits the `WriteBatch`.
- **FR-2.3:** Operations must be chunked into 450-operation batches to stay within Firestore's 500-op limit, matching the existing tech-stack convention.
- **FR-2.4:** The migration runs every sync cycle and silently skips employees where `doc.id == firebaseUid` — idempotent, no migration-complete flag needed.
- **FR-2.5:** Migration must be invoked silently (no UI interruption) from the owner login lifecycle after auth confirmation, within `DatabaseSyncService`.

### FR-3: Remove Fallback Queries (Cleanup)
- **FR-3.1:** In `UserRepository.getUserById()`, remove the `permission-denied` catch block that falls back to `.where('firebaseUid', isEqualTo: userId)` query. Restore to standard `_usersCollection.doc(userId).get()` with clean error handling.
- **FR-3.2:** In `WalletRepository.getWalletById()`, confirm and remove any permission-denied fallback queries if present. (Current codebase inspection shows this is already clean.)

## Non-Functional Requirements
- **NFR-1:** Migration uses `WriteBatch` (not `runTransaction`) for atomic writes across users, wallets, transactions, debts, and pin locks.
- **NFR-2:** Clean Architecture boundaries must be maintained — the use case lives in `domain/usecases/`, repository interactions stay in `data/repositories/`.
- **NFR-3:** `firestore.rules` must NOT be modified.
- **NFR-4:** All providers must continue extending `SafeChangeNotifier`.
- **NFR-5:** Error handling must follow `AppErrorHandler` patterns with proper stack trace capture.

## Acceptance Criteria
- **AC-1:** New employees are saved with `doc.id == firebaseUid` (verifiable by inspecting Firestore after employee creation).
- **AC-2:** Legacy employees with `doc.id != firebaseUid` are automatically migrated during owner login, with all foreign keys (including pin_locks) updated atomically.
- **AC-3:** `UserRepository.getUserById()` no longer contains a firebaseUid fallback query.
- **AC-4:** `flutter analyze` passes with no new errors or warnings.
- **AC-5:** All existing tests continue to pass.
- **AC-6:** Migration is idempotent — running it multiple times produces no duplicate documents or errors.

## Out of Scope
- Modifying Firestore Security Rules.
- Migrating owner documents (owners already have `doc.id == firebaseUid`).
- UI changes or new screens.
- Changes to the SMS automation / background service architecture.
