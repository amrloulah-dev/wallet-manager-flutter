# Implementation Plan: Critical Logic Fixes (B-002 & B-004)

## Phase 1: Fix Missing isActive Check (B-004)
- [ ] Task: Write Failing Tests (Red Phase)
    - [ ] Create/Update test file for `TransactionValidatorService` to verify soft-deleted wallet validation fails.
- [ ] Task: Implement to Pass Tests (Green Phase)
    - [ ] Open `lib/data/services/transaction_validator_service.dart`.
    - [ ] In `validateAndSave`, add check for `!wallet.isActive` exactly after `.exists` and before Firestore writes.
    - [ ] Throw `ValidationException('لا يمكن إجراء معاملة: المحفظة غير مفعلة أو تم حذفها')`.
- [ ] Task: Conductor - User Manual Verification 'Phase 1: Fix Missing isActive Check (B-004)' (Protocol in workflow.md)

## Phase 2: Fix Null Subscription Bypass (B-002)
- [ ] Task: Write Failing Tests (Red Phase)
    - [ ] Create/Update test file for `WalletProvider` to verify wallet creation fails when subscription provider is null.
- [ ] Task: Implement to Pass Tests (Green Phase)
    - [ ] Open `lib/providers/wallet_provider.dart`.
    - [ ] In `createWallet`, replace permissive `if (_subscriptionProvider != null)` wrapper with a strict guard clause.
    - [ ] Return `false` and set error `تعذر التحقق من حالة الاشتراك. يرجى المحاولة لاحقاً.` if `_subscriptionProvider` is null.
- [ ] Task: Refactor & Analyze
    - [ ] Run `flutter analyze` and resolve any new issues introduced.
- [ ] Task: Conductor - User Manual Verification 'Phase 2: Fix Null Subscription Bypass (B-002)' (Protocol in workflow.md)