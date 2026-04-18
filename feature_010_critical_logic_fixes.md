# 🛠️ Detailed Execution Plan: Critical Business Logic & Security Fixes (Feature 010)

**CRITICAL DIRECTIVES FOR DEVELOPER / AI AGENT:**
This document outlines the patching of two critical business logic vulnerabilities: Bug B-004 (Soft Delete Bypass) and Bug B-002 (Paywall/Subscription Bypass).
1. Execution MUST be strictly sequential.
2. Ensure you are applying "Fail-Closed" security principles.

---

## 🔒 Phase 1: Enforce Soft Delete Validation (Bug B-004)

### 🔴 Problem Definition
In `TransactionValidatorService.validateAndSave`, the code checks if a wallet physically exists (`!walletSnap.exists`) but fails to check its logical state (`isActive` or `isDeleted`). This allows ghost transactions on deactivated wallets.

### 🟢 Architectural Solution
Implement a strict check for the soft-delete flag immediately after the physical existence check.

### 📋 Implementation Tasks
- [ ] Navigate to `lib/data/services/transaction_validator_service.dart`.
- [ ] Locate the `validateAndSave` method.
- [ ] Find the line: `if (!walletSnap.exists) throw NotFoundException('المحفظة غير موجودة.');`
- [ ] Immediately BELOW this line, safely extract the document data and check the active status. Add the following logic:
      ```dart
      final walletData = walletSnap.data() as Map<String, dynamic>?;
      // Note: Adjust the key 'isActive' or 'isDeleted' based on what the Wallet model actually uses. Assuming 'isActive'.
      if (walletData == null || walletData['isActive'] == false || walletData['isDeleted'] == true) {
        throw Exception('لا يمكن إجراء معاملة: المحفظة غير مفعلة أو تم حذفها.');
      }
      ```
- [ ] Ensure this check happens *before* any `tx.update` or balance increments.

### 🔍 Verification Gates (Phase 1)
- [ ] **Code Audit:** Verify that `TransactionValidatorService` explicitly checks the logical state (`isActive`/`isDeleted`) and throws an Exception if the wallet is logically deleted.

---

## 🧱 Phase 2: Enforce Strict Paywall (Bug B-002)

### 🔴 Problem Definition
In `WalletProvider.createWallet`, the subscription limit check is wrapped in an `if (_subscriptionProvider != null)` block. If the provider is null (e.g., loading delay or missing dependency), the app bypasses the limit and allows unlimited wallet creation (Fail-Open).

### 🟢 Architectural Solution
Refactor the logic to follow the "Fail-Closed" principle. If the subscription state cannot be verified, the action MUST be denied.

### 📋 Implementation Tasks
- [ ] Navigate to `lib/providers/wallet_provider.dart`.
- [ ] Locate the `createWallet` method.
- [ ] Find the block starting with `if (_subscriptionProvider != null) { ... }`.
- [ ] REMOVE the `if (_subscriptionProvider != null)` wrapper.
- [ ] Replace it with strict Guard Clauses:
      ```dart
      // 1. Guard Clause: Deny if subscription cannot be verified
      if (_subscriptionProvider == null) {
        _setError('تعذر التحقق من حالة الاشتراك. يرجى المحاولة لاحقاً.');
        return false;
      }

      // 2. Limit Validation
      final currentCount = await _walletRepository.getWalletsCount(_currentStoreId!);
      if (!_subscriptionProvider!.canAddWallet(currentCount)) {
        _setError('تم الوصول للحد الأقصى للمحافظ (${_subscriptionProvider!.maxWallets})');
        return false;
      }
      ```

### 🔍 Verification Gates (Phase 2)
- [ ] **Code Audit:** Inspect `WalletProvider.createWallet`. Verify there is NO code path that allows wallet creation without explicitly passing the `_subscriptionProvider!.canAddWallet()` check.
- [ ] **Final Global Compile:** Run `flutter analyze`. The terminal MUST output `0 issues found`.