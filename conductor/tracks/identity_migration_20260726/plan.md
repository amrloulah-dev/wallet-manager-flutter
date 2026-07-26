# Implementation Plan: Identity Unification & Silent Data Migration

## Phase A: Refactor Employee Creation Flow

- [x] Task: Write failing tests for identity-first employee creation dd258ca
    - [x] Create `test/data/repositories/employee_repository_identity_test.dart`
    - [x] Test that `addEmployee()` calls `IdentityService.provisionIdentity()` before persisting the document
    - [x] Test that the resulting document ID equals the Auth UID returned by `provisionIdentity()`
    - [x] Test that `firebaseUid` field is set to the Auth UID at creation time (not null)
    - [x] Test that the PIN lock document's `userId` field uses the Auth UID as its value
    - [x] Test error handling: provisioning failure prevents employee creation
    - [x] Run tests and confirm they fail (Red phase)

- [x] Task: Refactor `EmployeeRepository.addEmployee()` to use identity-first creation dd258ca
    - [x] Call `IdentityService.provisionIdentity()` at the start of `addEmployee()` to obtain the Auth UID
    - [x] Replace `_usersCollection.doc().id` with the returned Auth UID as the canonical document ID
    - [x] Set `firebaseUid: authUid` in the `UserModel` constructor (not `null`)
    - [x] Ensure `transaction.set(_usersCollection.doc(authUid), userData)` is used within the existing transaction
    - [x] Update the PIN lock document to use `authUid` as the `userId` value
    - [x] Run tests and confirm they pass (Green phase)

- [x] Task: Remove redundant `provisionIdentity()` call from `EmployeeProvider` dd258ca
    - [x] In `lib/providers/employee_provider.dart`, remove the separate `_employeeRepository.provisionIdentity(newEmployee)` call after `addEmployee()`
    - [x] Verify the provider still returns the employee with correct `firebaseUid` populated
    - [x] Run all employee-related tests to confirm no regressions

- [ ] Task: Conductor - User Manual Verification 'Phase A: Refactor Employee Creation Flow' (Protocol in workflow.md)

## Phase B: Create Silent Identity Migration UseCase

- [ ] Task: Write failing tests for `IdentityMigrationUseCase`
    - [ ] Create `test/domain/usecases/identity_migration_usecase_test.dart`
    - [ ] Test: skips employees where `doc.id == firebaseUid` (already migrated)
    - [ ] Test: skips employees where `firebaseUid` is null or empty
    - [ ] Test: for a mismatched employee, creates new doc at `firebaseUid`, copies data, and deletes old doc
    - [ ] Test: foreign key updates in wallets (`createdBy`) reference the new doc ID
    - [ ] Test: foreign key updates in transactions (`createdBy`, `createdById`, `updatedBy`, `deletedBy`) reference the new doc ID
    - [ ] Test: foreign key updates in debts (`createdBy`, `markedPaidBy`, `lastUpdatedBy`) reference the new doc ID
    - [ ] Test: pin lock documents (`userId` field) are updated to reference the new doc ID
    - [ ] Test: operations are chunked into 450-op batches when exceeding the limit
    - [ ] Test: migration is idempotent (running twice produces no duplicates or errors)
    - [ ] Run tests and confirm they fail (Red phase)

- [ ] Task: Implement `IdentityMigrationUseCase`
    - [ ] Create `lib/domain/usecases/identity_migration_usecase.dart`
    - [ ] Inject Firestore instance and required collection references
    - [ ] Implement `executeMigration(String currentStoreId)`:
        - [ ] Query users where `storeId == currentStoreId` AND `role == employee`
        - [ ] Filter: `doc.id != firebaseUid` AND `firebaseUid != null && isNotEmpty`
        - [ ] For each mismatched employee, prepare WriteBatch operations:
            - [ ] Create new doc at `_usersCollection.doc(firebaseUid)` with existing data
            - [ ] Query and update wallets `createdBy` matching old doc ID
            - [ ] Query and update transactions `createdBy`, `createdById`, `updatedBy`, `deletedBy` matching old doc ID
            - [ ] Query and update debts `createdBy`, `markedPaidBy`, `lastUpdatedBy` matching old doc ID
            - [ ] Query and update pin lock `userId` matching old doc ID
            - [ ] Delete old employee document
        - [ ] Chunk into 450-op batches and commit each batch
    - [ ] Follow `AppErrorHandler` patterns with proper stack trace capture
    - [ ] Run tests and confirm they pass (Green phase)

- [ ] Task: Integrate `IdentityMigrationUseCase` into `DatabaseSyncService`
    - [ ] Register `IdentityMigrationUseCase` in `lib/core/di/service_locator.dart`
    - [ ] In `DatabaseSyncService._finalizeOwnerLogin()`, invoke `IdentityMigrationUseCase.executeMigration(storeId)` silently after auth confirmation
    - [ ] Wrap invocation in try-catch so migration failures do not block the login flow
    - [ ] Write tests verifying the migration is called during owner login and failures are handled gracefully
    - [ ] Run all tests to confirm no regressions

- [ ] Task: Conductor - User Manual Verification 'Phase B: Create Silent Identity Migration UseCase' (Protocol in workflow.md)

## Phase C: Revert Fallback Queries (Cleanup)

- [ ] Task: Write tests confirming direct document lookup without fallback
    - [ ] In `test/data/repositories/user_repository_test.dart`, add test: `getUserById` returns null on permission-denied (no fallback query)
    - [ ] Verify no query-by-`firebaseUid` fallback exists
    - [ ] Run tests and confirm they fail (Red phase)

- [ ] Task: Remove fallback query from `UserRepository.getUserById()`
    - [ ] Remove the `permission-denied` catch block containing `.where('firebaseUid', isEqualTo: userId)` fallback
    - [ ] Restore clean error handling: rethrow `ServerException` on `FirebaseException`
    - [ ] Run tests and confirm they pass (Green phase)

- [ ] Task: Verify `WalletRepository.getWalletById()` has no fallback queries
    - [ ] Inspect `WalletRepository.getWalletById()` and confirm no permission-denied fallback exists
    - [ ] If clean, mark as verified with no changes needed
    - [ ] If fallback exists, remove it and add corresponding test

- [ ] Task: Final static analysis and full test suite validation
    - [ ] Run `flutter analyze` and verify no new errors or warnings
    - [ ] Run `CI=true flutter test` and verify all tests pass
    - [ ] Verify code coverage meets >80% threshold for new code

- [ ] Task: Conductor - User Manual Verification 'Phase C: Revert Fallback Queries (Cleanup)' (Protocol in workflow.md)
