# Track Specification: Enforce Native 6-Digit PIN Architecture & Purge Legacy Padding

## Overview
This track implements a hard cutoff strategy for employee PINs in the Wallet Manager application to natively align with Firebase Auth's 6-character password requirement. All legacy 4-digit PIN padding/salting mechanics (e.g. `_deriveAuthPassword` and adaptive fallback sign-in) in `IdentityService` are purged. Store owners will manually recreate employees with native 6-digit PINs.

## Functional Requirements
1. **Identity Service Purge & Direct Pass-Through**:
   - Purge helper methods responsible for padding/salting PINs (`_deriveAuthPassword`) from `lib/core/services/identity_service.dart`.
   - Refactor `provisionIdentity()` to pass `rawPin` directly as the password to `FirebaseAuth.instance.createUserWithEmailAndPassword`.
   - Refactor `authenticateEmployee()` to remove any adaptive fallback logic and execute a single `signInWithEmailAndPassword` call using `rawPin` directly.
2. **UI Validation Hardening**:
   - Update `validatePin` in `lib/core/utils/validators.dart` (or equivalent validator utility) to strictly enforce exactly 6 digits via regex `^\d{6}$`.
   - Update localization messages and validation error strings in both Arabic and English to state: "PIN must be exactly 6 digits".
3. **Employee Deletion & Lock Release Audit**:
   - Audit `deleteEmployee` in `lib/data/repositories/employee_repository.dart` to confirm that the `WriteBatch` explicitly contains a `delete` operation for `_firestore.collection('stores').doc(storeId).collection('pin_locks').doc(hashedPin)` to release the lock and free the subscription seat.
4. **Test Suite Alignment**:
   - Update unit and widget tests across the codebase (e.g. `identity_service_test.dart`, `validators_test.dart`, `employee_repository_test.dart`) to use 6-digit PINs and test exact 6-digit validation.

## Non-Functional Requirements
- Maintain Clean Architecture boundaries.
- Ensure zero dead code or orphaned references to padded passwords.
- Enforce strict type safety and error reporting.

## Acceptance Criteria
- `_deriveAuthPassword` is deleted and no salting/padding logic remains in `IdentityService`.
- `validatePin` returns invalid for any input that is not exactly 6 digits.
- `EmployeeRepository.deleteEmployee` successfully deletes the linked `pin_locks` document.
- `flutter analyze` reports 0 issues.
- `flutter test` succeeds across all test suites.
