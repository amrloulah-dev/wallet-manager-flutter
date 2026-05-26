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

- [x] Task: Write failing tests for `createWallet` with `WriteBatch` [bd42113]
    - [x] Test case: Verify `createWallet` uses `WriteBatch` (not `runTransaction`)
    - [x] Test case: Verify wallet document is created in Firestore
    - [x] Test case: Verify `updateStatsOnWalletChange` is called with `batch` parameter
    - [x] Test case: Verify `_cacheManager.clearWhere` is called after batch commit
    - [x] Run tests — confirm they fail (Red Phase)

- [x] Task: Migrate `createWallet` from `runTransaction` to `WriteBatch` [f5e960b]
    - [x] Replace `_firestore.runTransaction(...)` with `_firestore.batch()`
    - [x] Use `batch.set(walletRef, wallet.toFirestore())`
    - [x] Call `updateStatsOnWalletChange` with `batch: batch`
    - [x] Call `await batch.commit()`
    - [x] Preserve `_cacheManager.clearWhere(...)` after commit
    - [x] Preserve error handling (`catch`, `AppErrorHandler`, `ServerException`)
    - [x] Run tests — confirm they pass (Green Phase)

- [x] Task: Verify existing callers are unaffected [f5e960b]
    - [x] Run existing tests for `creditWallet`, `debitWallet`, `setWalletActiveStatus`
    - [x] Confirm no test failures

- [x] Task: Conductor - User Manual Verification 'Phase 2: Refactor WalletRepository.createWallet' (Protocol in workflow.md)
