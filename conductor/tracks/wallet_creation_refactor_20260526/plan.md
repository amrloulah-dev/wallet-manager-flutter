# Plan: Refactor Wallet Creation to WriteBatch (BUG-01)

## Phase 1: Refactor StatsRepository

- [x] Task: Write failing tests for `updateStatsOnWalletChange` with `WriteBatch` [4efb0f5]
    - [ ] Create/update test file for `StatsRepository`
    - [ ] Test case: Call with `WriteBatch` parameter — verify batch operations are queued correctly
    - [ ] Test case: Assert that `batch` and `firestoreTransaction` cannot be provided simultaneously
    - [ ] Run tests — confirm they fail (Red Phase)

- [x] Task: Implement `WriteBatch` logic in `StatsRepository.updateStatsOnWalletChange` [8b5ece7]
    - [ ] Add `WriteBatch? batch` optional parameter to method signature
    - [ ] Add assertion: `assert(batch == null || firestoreTransaction == null)`
    - [ ] Implement conditional logic: if `batch != null`, use `batch.set(summaryRef, data, SetOptions(merge: true))`
    - [ ] Preserve existing `Transaction` code path unchanged
    - [ ] Run tests — confirm they pass (Green Phase)

## Phase 2: Refactor WalletRepository.createWallet

- [~] Task: Write failing tests for `createWallet` with `WriteBatch`
    - [ ] Test case: Verify `createWallet` uses `WriteBatch` (not `runTransaction`)
    - [ ] Test case: Verify wallet document is created in Firestore
    - [ ] Test case: Verify `updateStatsOnWalletChange` is called with `batch` parameter
    - [ ] Test case: Verify `_cacheManager.clearWhere` is called after batch commit
    - [ ] Run tests — confirm they fail (Red Phase)

- [ ] Task: Migrate `createWallet` from `runTransaction` to `WriteBatch`
    - [ ] Replace `_firestore.runTransaction(...)` with `_firestore.batch()`
    - [ ] Use `batch.set(walletRef, wallet.toFirestore())`
    - [ ] Call `updateStatsOnWalletChange` with `batch: batch`
    - [ ] Call `await batch.commit()`
    - [ ] Preserve `_cacheManager.clearWhere(...)` after commit
    - [ ] Preserve error handling (`catch`, `AppErrorHandler`, `ServerException`)
    - [ ] Run tests — confirm they pass (Green Phase)

- [ ] Task: Verify existing callers are unaffected
    - [ ] Run existing tests for `creditWallet`, `debitWallet`, `setWalletActiveStatus`
    - [ ] Confirm no test failures

- [ ] Task: Conductor - User Manual Verification 'Phase 2: Refactor WalletRepository.createWallet' (Protocol in workflow.md)
