# Implementation Plan - Enforce Native 6-Digit PIN Architecture & Purge Legacy Padding

## User Review Required
> [!IMPORTANT]
> This plan executes a hard cutoff strategy: legacy 4-digit PIN padding is purged. Store owners will manually delete legacy 4-digit employees and recreate them with native 6-digit PINs.

## Proposed Changes

### Phase 1: Purge IdentityService Padding
- [x] Task: Purge legacy padding & derivation logic from `IdentityService`
    - Remove `_deriveAuthPassword` method from `lib/core/services/identity_service.dart`.
    - Refactor `provisionIdentity()` to pass `rawPin` directly as password to `createUserWithEmailAndPassword`.
    - Refactor `authenticateEmployee()` to remove adaptive fallback loop and execute a single `signInWithEmailAndPassword` call with `rawPin`.
    - Write/update tests in `test/core/services/identity_service_test.dart` for direct 6-digit PIN auth.
- [x] Task: Conductor - User Manual Verification 'Phase 1: Purge IdentityService Padding' (Protocol in workflow.md)

### Phase 2: Harden UI Validators
- [x] Task: Update PIN validator to strictly enforce 6 digits
    - Modify `validatePin` in `lib/core/utils/validators.dart` using regex `^\d{6}$`.
    - Update Arabic and English localization files (`app_ar.arb`, `app_en.arb`) or validator strings to state "PIN must be exactly 6 digits".
    - Update unit and widget tests in `test/core/utils/validators_test.dart` (and related UI tests) to validate exactly 6-digit PINs.
- [x] Task: Conductor - User Manual Verification 'Phase 2: Harden UI Validators' (Protocol in workflow.md)

### Phase 3: Audit Deletion & Lock Release
- [x] Task: Audit and verify `pin_locks` deletion in `EmployeeRepository.deleteEmployee`
    - Audit `deleteEmployee` in `lib/data/repositories/employee_repository.dart` and confirm `_firestore.collection('stores').doc(storeId).collection('pin_locks').doc(hashedPin)` is explicitly deleted in the `WriteBatch`.
    - Update/add tests in `test/data/repositories/employee_repository_test.dart` to verify `pin_locks` document deletion.
- [x] Task: Conductor - User Manual Verification 'Phase 3: Audit Deletion & Lock Release' (Protocol in workflow.md)

### Phase 4: Final Quality Assurance & Analysis Sweep
- [x] Task: Static analysis and full test suite execution
    - Run `flutter analyze` to ensure zero warnings or dead code references.
    - Run `CI=true flutter test` to ensure all tests pass.
- [x] Task: Conductor - User Manual Verification 'Phase 4: Final Quality Assurance & Analysis Sweep' (Protocol in workflow.md)
