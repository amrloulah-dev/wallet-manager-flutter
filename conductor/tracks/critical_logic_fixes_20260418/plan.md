# Implementation Plan: Critical Logic Fixes (B-002 & B-004)

## Phase 1: Fix Missing isActive Check (B-004) [checkpoint: 5642580]
- [x] Task: Write Failing Tests (Red Phase) 5642580
    - [x] Create/Update test file for `TransactionValidatorService` to verify soft-deleted wallet validation fails.
- [x] Task: Implement to Pass Tests (Green Phase) 5642580
    - [x] Open `lib/data/services/transaction_validator_service.dart`.
    - [x] In `validateAndSave`, add check for `!wallet.isActive` exactly after `.exists` and before Firestore writes.
    - [x] Throw `ValidationException('لا يمكن إجراء معاملة: المحفظة غير مفعلة أو تم حذفها')`.
- [x] Task: Conductor - User Manual Verification 'Phase 1: Fix Missing isActive Check (B-004)' (Protocol in workflow.md) 5642580

## Phase 2: Fix Null Subscription Bypass (B-002) [checkpoint: db51b4c]
- [x] Task: Write Failing Tests (Red Phase) db51b4c
    - [x] Create/Update test file for `WalletProvider` to verify wallet creation fails when subscription provider is null.
- [x] Task: Implement to Pass Tests (Green Phase) db51b4c
    - [x] Open `lib/providers/wallet_provider.dart`.
    - [x] In `createWallet`, replace permissive `if (_subscriptionProvider != null)` wrapper with a strict guard clause.
    - [x] Return `false` and set error `تعذر التحقق من حالة الاشتراك. يرجى المحاولة لاحقاً.` if `_subscriptionProvider` is null.
- [x] Task: Refactor & Analyze db51b4c
    - [x] Run `flutter analyze` and resolve any new issues introduced.
- [x] Task: Conductor - User Manual Verification 'Phase 2: Fix Null Subscription Bypass (B-002)' (Protocol in workflow.md) db51b4c