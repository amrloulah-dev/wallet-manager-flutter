# Specification: Critical Logic Fixes (B-002 & B-004)

## Overview
This track addresses two major business logic flaws related to transaction validation (Bug B-004) and subscription enforcement (Bug B-002). 

## Functional Requirements
1. **Bug B-004: Missing `isActive` / Soft-Delete Check**
   - **Location:** `TransactionValidatorService.validateAndSave`
   - **Requirement:** After verifying the wallet document exists in Firestore, check if the wallet is logically enabled (`isActive == true`). 
   - **Action:** If the wallet is inactive or deleted, throw a `ValidationException` with the exact message: "لا يمكن إجراء معاملة: المحفظة غير مفعلة أو تم حذفها". This must occur *before* any Firestore writes.

2. **Bug B-002: Null Subscription Bypass**
   - **Location:** `WalletProvider.createWallet`
   - **Requirement:** Prevent the creation of wallets when `_subscriptionProvider` is null.
   - **Action:** Remove the permissive `if (_subscriptionProvider != null)` wrapper. Replace it with a strict guard clause that immediately returns `false` and sets the error message: "تعذر التحقق من حالة الاشتراك. يرجى المحاولة لاحقاً." if the provider is null.

3. **Unit Tests**
   - Add unit tests to verify that `TransactionValidatorService` throws the correct exception for inactive wallets.
   - Add unit tests to verify that `WalletProvider.createWallet` fails gracefully when the subscription provider is uninitialized.

## Acceptance Criteria
- [ ] Attempting to process a transaction on a soft-deleted wallet fails and shows the exact error message.
- [ ] Attempting to create a wallet without a valid subscription provider fails and shows the exact error message.
- [ ] Unit tests for both failure scenarios pass.
- [ ] `flutter analyze` returns 0 issues after changes are applied.

## Out of Scope
- Refactoring other services or providers outside the specified bugs.