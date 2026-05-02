# Implementation Plan: Firebase & Firestore Refactoring (Phase 4.2)

## Phase 1: Force Atomicity (FieldValue.increment)
- [ ] Task: Refactor Transaction Validator
    - [ ] Update `test/data/services/transaction_validator_service_test.dart` to verify wallet balance increments via state checking in `fake_cloud_firestore`.
    - [ ] Implement fix in `lib/data/services/transaction_validator_service.dart` (~Line 169) using `FieldValue.increment(balanceChange)`.
- [ ] Task: Refactor Debt Repository
    - [ ] Update `test/data/repositories/debt_repository_test.dart` to verify `openDebtsCount` decrements via state checking.
    - [ ] Implement fix in `deleteDebt` and `processPayment` methods in `lib/data/repositories/debt_repository.dart` using `FieldValue.increment(-1)`.
- [ ] Task: Refactor Employee Repository
    - [ ] Update `test/data/repositories/employee_repository_test.dart` to verify stats decrements.
    - [ ] Implement fix for employee deactivation/stats in `lib/data/repositories/employee_repository.dart` using `FieldValue.increment(-1)`.
- [ ] Task: Refactor User Repository
    - [ ] Update `test/data/repositories/user_repository_test.dart` to verify direct atomic stats updates without pre-fetching.
    - [ ] Remove the `.get()` call and implement direct atomic updates in `lib/data/repositories/user_repository.dart` (~Lines 329-354).
- [ ] Task: Conductor - User Manual Verification 'Phase 1: Force Atomicity' (Protocol in workflow.md)

## Phase 2: Security Fix & Tech Debt Cleanup
- [ ] Task: Secure Device UUID Fallback
    - [ ] Update `test/data/repositories/device_repository_test.dart` to verify reading/saving UUID via `LocalStorageService` when device info fails.
    - [ ] Implement UUID caching and retrieval fallback in `lib/data/repositories/device_repository.dart`.
- [ ] Task: Optimize License Key Expiry Logic
    - [ ] Update `test/data/repositories/license_key_repository_test.dart` to verify precise DateTime addition.
    - [ ] Replace `Duration(days: ...)` with `DateTime(year, month + ...)` in `lib/data/repositories/license_key_repository.dart`.
- [ ] Task: Optimize Debt Creation Write Batch
    - [ ] Update `test/data/repositories/debt_repository_test.dart` to verify `createDebt` logic.
    - [ ] Refactor `createDebt()` in `lib/data/repositories/debt_repository.dart` to use `_firestore.batch()` instead of `_firestore.runTransaction()`.
- [ ] Task: Conductor - User Manual Verification 'Phase 2: Security Fix & Tech Debt Cleanup' (Protocol in workflow.md)

## Phase 3: Wallet Repository Cleanup
- [ ] Task: Deprecate `updateWalletBalance`
    - [ ] Identify all references to `updateWalletBalance()` in the Provider layer.
    - [ ] Migrate identified references to use `creditWallet` or `debitWallet`.
    - [ ] Delete `updateWalletBalance()` from `lib/data/repositories/wallet_repository.dart`.
    - [ ] Update/remove affected tests in `test/data/repositories/wallet_repository_test.dart` and any related Provider tests.
- [ ] Task: Conductor - User Manual Verification 'Phase 3: Wallet Repository Cleanup' (Protocol in workflow.md)