# Specification: Firebase & Firestore Refactoring (Phase 4.2: Surgical Strikes)

## Overview
This track focuses on surgical refactoring of Firebase and Firestore interactions to ensure data atomicity, resolve a security loophole in device tracking, and clean up specific technical debt. It operates under a strict $0 budget constraint (Spark Plan, no Cloud Functions) and prioritizes `FieldValue.increment()` over Dart-side math.

## Functional Requirements

### 1. Force Atomicity (`FieldValue.increment`)
- **Transaction Validator:** Update `lib/data/services/transaction_validator_service.dart` (~Line 169) to use `FieldValue.increment(balanceChange)` instead of Dart-side addition for wallet balance updates.
- **Debt Repository:** Update `lib/data/repositories/debt_repository.dart` (`deleteDebt` and `processPayment`) to use `FieldValue.increment(-1)` instead of Dart-side subtraction for `openDebtsCount`.
- **Employee Repository:** Update `lib/data/repositories/employee_repository.dart` to use `FieldValue.increment(-1)` for `stats.totalEmployees` and `SummaryEmployees`.
- **User Repository:** Update `lib/data/repositories/user_repository.dart` (~Lines 329-354) to remove the unnecessary `.get()` call and use a direct atomic update with `FieldValue.increment()` for stat fields.

### 2. Security Fix: Device UUID Fallback
- **Device Repository:** Update `lib/data/repositories/device_repository.dart` (`getDeviceId()`).
    - Attempt to read a previously saved UUID using `LocalStorageService`.
    - If found, return it.
    - If not found (and device info fails), generate a new `Uuid().v4()`, save it immediately using `LocalStorageService`, and return it.

### 3. Technical Debt & Architectural Optimization
- **License Key Repository:** Update `lib/data/repositories/license_key_repository.dart` (`activateLicenseKey()`). Replace `now.add(Duration(days: expiryMonths * 30))` with precise Dart DateTime math: `DateTime(now.year, now.month + expiryMonths, now.day, now.hour, now.minute)`.
- **Debt Repository:** Update `lib/data/repositories/debt_repository.dart` (`createDebt()`). Refactor to use `_firestore.batch()` instead of `_firestore.runTransaction()`.
- **Wallet Repository:** Delete the deprecated `updateWalletBalance()` method in `lib/data/repositories/wallet_repository.dart`. Migrate all existing references in the Provider layer to use `creditWallet` or `debitWallet` immediately.

## Non-Functional Requirements & Constraints
- **Budget Constraint:** $0 budget (Spark Plan). No Cloud Functions allowed.
- **Scope:** Strictly limit changes to the files and methods specified above. No global searches or automated wide-scale refactoring.
- **Testing:** Strict TDD using `fake_cloud_firestore`. Verify `FieldValue.increment()` operations by asserting the final document state in the fake instance. Do NOT use local emulators.
- **Rollback:** Commits must be cleanly isolated to allow for an easy Git Revert.

## Acceptance Criteria
- All specified Dart-side math operations for Firestore updates are replaced with `FieldValue.increment()`.
- Unnecessary `.get()` calls before updates in `user_repository.dart` are removed.
- `getDeviceId()` reliably returns a consistent UUID across app launches when device info fails.
- License key expiry is calculated accurately using DateTime arithmetic.
- `createDebt()` utilizes a WriteBatch instead of a transaction.
- `updateWalletBalance()` is deleted and all callers are successfully migrated.
- All unit tests pass, successfully verifying state changes in `fake_cloud_firestore`.

## Out of Scope
- Any Firebase refactoring outside of the explicitly listed files and methods.
- Setting up or utilizing Firebase Local Emulator Suite.
- Cloud Functions development.