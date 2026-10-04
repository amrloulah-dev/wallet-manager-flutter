
# Implementation Plan: Firebase & Firestore Refactoring (Phase 4.2)

## Phase 1: Force Atomicity (FieldValue.increment)
- [x] Task: Refactor Transaction Validator
    - [x] Update `test/data/services/transaction_validator_service_test.dart` to verify wallet balance increments via state checking in `fake_cloud_firestore`.
    - [x] Implement fix in `lib/data/services/transaction_validator_service.dart` (~Line 169) using `FieldValue.increment(balanceChange)`.
- [x] Task: Refactor Debt Repository
    - [x] Update `test/data/repositories/debt_repository_test.dart` to verify `openDebtsCount` decrements via state checking.
    - [x] Implement fix in `deleteDebt` and `processPayment` methods in `lib/data/repositories/debt_repository.dart` using `FieldValue.increment(-1)`.
- [x] Task: Refactor Employee Repository
    - [x] Update `test/data/repositories/employee_repository_test.dart` to verify stats decrements.
    - [x] Implement fix for employee deactivation/stats in `lib/data/repositories/employee_repository.dart` using `FieldValue.increment(-1)`.
- [x] Task: Refactor User Repository
    - [x] Update `test/data/repositories/user_repository_test.dart` to verify direct atomic stats updates without pre-fetching.
    - [x] Remove the `.get()` call and implement direct atomic updates in `lib/data/repositories/user_repository.dart` (~Lines 329-354).
- [x] Task: Conductor - User Manual Verification 'Phase 1: Force Atomicity' (Protocol in workflow.md)

## Phase 2: Security Fix & Tech Debt Cleanup
- [x] Task: Secure Device UUID Fallback
    - [x] Update `test/data/repositories/device_repository_test.dart` to verify reading/saving UUID via `LocalStorageService` when device info fails.
    - [x] Implement UUID caching and retrieval fallback in `lib/data/repositories/device_repository.dart`.
- [x] Task: Optimize License Key Expiry Logic
    - [x] Update `test/data/repositories/license_key_repository_test.dart` to verify precise DateTime addition.
    - [x] Replace `Duration(days: ...)` with `DateTime(year, month + ...)` in `lib/data/repositories/license_key_repository.dart`.
- [x] Task: Optimize Debt Creation Write Batch
    - [x] Update `test/data/repositories/debt_repository_test.dart` to verify `createDebt` logic.
    - [x] Refactor `createDebt()` in `lib/data/repositories/debt_repository.dart` to use `_firestore.batch()` instead of `_firestore.runTransaction()`.
- [x] Task: Conductor - User Manual Verification 'Phase 2: Security Fix & Tech Debt Cleanup' (Protocol in workflow.md)

## Phase 3: Wallet Repository Cleanup
- [x] Task: Deprecate `updateWalletBalance`
    - [x] Identify all references to `updateWalletBalance()` in the Provider layer.
    - [x] Migrate identified references to use `creditWallet` or `debitWallet`.
    - [x] Delete `updateWalletBalance()` from `lib/data/repositories/wallet_repository.dart`.
    - [x] Update/remove affected tests in `test/data/repositories/wallet_repository_test.dart` and any related Provider tests.
- [x] Task: Conductor - User Manual Verification 'Phase 3: Wallet Repository Cleanup' (Protocol in workflow.md)

## Phase: Review Fixes
- [x] Task: Apply review suggestions c7809d7