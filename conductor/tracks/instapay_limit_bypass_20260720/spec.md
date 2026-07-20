# Specification: InstaPay Limit Force-Bypass

## Overview
In the Egyptian market, merchants who exceed InstaPay limits often complete the transfer via their native banking app and need to record it in Wallet Manager's ledger. This feature introduces a **Soft-Block / Force-Bypass** flow exclusively for InstaPay wallets, where exceeding Daily or Monthly limits triggers an interactive warning dialog instead of a hard rejection. The user can confirm they completed the transaction externally and record it. All other wallet types (Vodafone Cash, Orange Cash, etc.) remain hard-blocked.

## Functional Requirements

### FR-1: Custom Domain Exception
- A new exception class `InstaPayLimitWarningException` extending `AppException` is created in `lib/core/errors/app_exceptions.dart`.
- Default message: `instapay_limit_warning`.
- This exception type signals a soft-block (user-recoverable) vs. the existing `ValidationException` which signals a hard-block (non-recoverable).

### FR-2: Provider Limit Interception Logic
- `TransactionProvider.createTransaction(...)` accepts a new named optional parameter: `bool forceInstaPayBypass = false`.
- **Limit scope:** Only Daily and Monthly limits participate in the bypass. The **Max Per Transaction** limit remains a hard block for ALL wallet types (including InstaPay).
- **Limit check logic injection:**
  - If a Daily or Monthly limit is exceeded AND `wallet.walletType != WalletType.instaPay` → Throw `ValidationException` (existing behavior, unchanged).
  - If a Daily or Monthly limit is exceeded AND `wallet.walletType == WalletType.instaPay`:
    - If `forceInstaPayBypass == false` → Throw `InstaPayLimitWarningException()`.
    - If `forceInstaPayBypass == true` → Skip the limit breach and proceed with transaction creation.
- **State Integrity:** When `InstaPayLimitWarningException` is thrown, it occurs BEFORE any optimistic state mutation (the limit checks happen before snapshots/mutations), so no rollback is needed. The exception must be **re-thrown** after the catch block to propagate to the UI, unlike `ValidationException` which is silently caught and returns `false`.

### FR-3: Audit Trail Field
- `TransactionModel` gains a new optional boolean field: `bypassedLimit` (default: `false`).
- Added to the constructor, `fromMap`, `toFirestore`, `copyWith`, and `==`/`hashCode`.
- When `forceInstaPayBypass == true`, the transaction is created with `bypassedLimit: true` in Firestore for audit tracking.

### FR-4: UI Warning Dialog & Retry Flow
- In `CreateTransactionScreen._handleCreate()`, a specific `on InstaPayLimitWarningException` catch block is added BEFORE the generic `catch (e, stack)`.
- The catch block displays an `AwesomeDialog`:
  - `dialogType: DialogType.warning` (orange/amber color).
  - `title:` "تنبيه تجاوز الحدود"
  - `desc:` EXACTLY: "لقد تجاوزت حدود إنستاباي المسموحة. هل قمت بتنفيذ هذه العملية من تطبيق البنك البديلي وتريد تسجيلها"
  - `btnCancelText:` "إلغاء" → dismisses dialog.
  - `btnOkText:` "تسجيل العملية" → Re-invokes `createTransaction` with `forceInstaPayBypass: true`.
- Loading state is properly reset when the dialog is dismissed, and correctly re-engaged on confirm-retry.
- The fixed Arabic message is used (no dynamic limit values).

## Non-Functional Requirements

### NFR-1: Zero Side Effects on Non-InstaPay Wallets
- The existing `ValidationException` logic for telecom wallets (Vodafone Cash, Orange Cash, Etisalat Cash, WE Pay) must remain completely unchanged.

### NFR-2: Optimistic UI Integrity
- `InstaPayLimitWarningException` is thrown during the pre-mutation validation phase (before optimistic insert), so no rollback is necessary when this specific exception fires.
- The existing rollback mechanism for other exceptions remains untouched.

### NFR-3: Fetch Shield Preservation
- The fetch shield activation logic (`_activateFetchShield()`) must not be affected by this change.

## Acceptance Criteria

- [ ] AC-1: Creating a transaction on a Vodafone Cash wallet that exceeds Daily/Monthly limits still throws `ValidationException` and shows a red error dialog (no change).
- [ ] AC-2: Creating a transaction on an InstaPay wallet that exceeds the Max Per Transaction limit throws `ValidationException` and shows a red error dialog (hard block preserved).
- [ ] AC-3: Creating a transaction on an InstaPay wallet that exceeds Daily or Monthly limits (but NOT Max Per Transaction) throws `InstaPayLimitWarningException`, triggering the orange warning dialog.
- [ ] AC-4: Dismissing the warning dialog ("إلغاء") does nothing — the transaction is NOT recorded.
- [ ] AC-5: Confirming the warning dialog ("تسجيل العملية") re-invokes `createTransaction` with `forceInstaPayBypass: true`, successfully recording the transaction.
- [ ] AC-6: The bypassed transaction is persisted to Firestore with `bypassedLimit: true`.
- [ ] AC-7: Loading state is correctly managed throughout the entire flow (initial attempt → warning → dismiss/retry).

## Out of Scope
- Admin dashboard for viewing bypassed transactions.
- Localized English equivalent of the warning message.
- Push notifications for bypassed transactions.
- Per-transaction limit bypass for any wallet type.
