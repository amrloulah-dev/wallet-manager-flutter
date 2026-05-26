# Spec: Refactor Wallet Creation to WriteBatch (BUG-01)

## Overview

`WalletRepository.createWallet()` fails with `wallet_error_create_failed` because it uses `runTransaction` incorrectly: it performs a `transaction.set()` (write) on line 43, then calls `updateStatsOnWalletChange()` which internally does `transaction.get()` (read) on line 187. Firestore requires **all reads before all writes** within a transaction, making this sequence illegal.

## Root Cause

**File:** `lib/data/repositories/wallet_repository.dart` (Lines 38-60)

```dart
Future<void> createWallet(WalletModel wallet) async {
  try {
    await _firestore.runTransaction((transaction) async {
      final walletRef = _walletsCollection.doc(wallet.walletId);
      transaction.set(walletRef, wallet.toFirestore());  // WRITE first
      await _statsRepository.updateStatsOnWalletChange(  // Then READ (illegal!)
        wallet.storeId,
        countChange: 1,
        activeCountChange: wallet.isActive ? 1 : 0,
        balanceChange: wallet.balance,
        firestoreTransaction: transaction,
      );
    });
    ...
  }
}
```

**File:** `lib/data/repositories/stats_repository.dart` (Lines 176-220)

```dart
Future<void> updateStatsOnWalletChange(..., Transaction? firestoreTransaction) {
  ...
  Future<void> updateLogic(Transaction transaction) async {
    final summaryRef = _getSummaryDocRef(storeId);
    final summarySnap = await transaction.get(summaryRef);  // READ after WRITE = illegal!
    ...
  }
}
```

## Solution: Migrate `createWallet` to `WriteBatch`

Since `createWallet` does NOT need to read any document before writing (it creates a new wallet), a `WriteBatch` is the correct primitive. A batch guarantees atomicity (all-or-nothing) without the read-before-write constraint.

## Functional Requirements

### FR-1: Add `WriteBatch` overload to `StatsRepository.updateStatsOnWalletChange`

Add a new optional parameter `WriteBatch? batch` alongside the existing `Transaction? firestoreTransaction`. When `batch` is provided, use `batch.set(..., SetOptions(merge: true))` unconditionally (which is safe — it creates if not exists, merges if exists). The `transaction.get()` check is only needed in the transaction path.

**Proposed signature:**
```dart
Future<void> updateStatsOnWalletChange(String storeId, {
  int countChange = 0,
  int activeCountChange = 0,
  double balanceChange = 0.0,
  Transaction? firestoreTransaction,
  WriteBatch? batch,  // NEW
})
```

**Assertion:**
```dart
assert(batch == null || firestoreTransaction == null,
    'Cannot provide both batch and firestoreTransaction');
```

### FR-2: Refactor `WalletRepository.createWallet` to use `WriteBatch`

Replace `_firestore.runTransaction(...)` with:
```dart
final batch = _firestore.batch();
final walletRef = _walletsCollection.doc(wallet.walletId);
batch.set(walletRef, wallet.toFirestore());

await _statsRepository.updateStatsOnWalletChange(
  wallet.storeId,
  countChange: 1,
  activeCountChange: wallet.isActive ? 1 : 0,
  balanceChange: wallet.balance,
  batch: batch,
);

await batch.commit();
_cacheManager.clearWhere((key) => key.startsWith('wallets_page_'));
```

### FR-3: Preserve existing `Transaction` callers

The `creditWallet`, `debitWallet`, and `setWalletActiveStatus` methods correctly use `Transaction` (they read wallet data before writing). These callers MUST NOT be modified. The `firestoreTransaction` parameter remains fully functional.

### FR-4: Validate parameter exclusivity

Add assertion that `batch` and `firestoreTransaction` are not both provided.

## Non-Functional Requirements

- **NFR-1: Atomicity preserved**: `WriteBatch.commit()` is atomic — both the wallet document and stats update succeed or fail together.
- **NFR-2: No other callers affected**: `creditWallet`, `debitWallet`, `setWalletActiveStatus` remain unchanged.

## Acceptance Criteria

- [ ] `createWallet` uses `WriteBatch` instead of `runTransaction`.
- [ ] `updateStatsOnWalletChange` accepts optional `WriteBatch` parameter.
- [ ] Assertion prevents both `batch` and `firestoreTransaction` from being provided.
- [ ] Cache invalidation preserved after batch commit.
- [ ] `creditWallet`, `debitWallet`, `setWalletActiveStatus` are untouched.
- [ ] Unit tests verify wallet creation succeeds.
- [ ] Unit tests verify stats are updated correctly on wallet creation.
- [ ] Existing tests for other wallet operations still pass.

## Out of Scope

- Modifying `creditWallet`, `debitWallet`, `setWalletActiveStatus`.
- Changing the `TransactionValidatorService`.
- Modifying `daily_stats` structure (that's Track 4).
