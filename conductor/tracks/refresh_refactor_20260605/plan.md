# Implementation Plan: Optimistic UI Refresh Refactor

## Phase 0: Stream Eradication [checkpoint: 59bae7d]

- [ ] Task: Convert StatisticsProvider from Stream to Future-based fetch b946e8c
    - [ ] Write tests for StatisticsProvider one-shot fetch behavior (Red)
    - [ ] Remove `StreamSubscription _summarySubscription` and `_todayStatsSubscription`
    - [ ] Replace with one-shot `Future`-based fetch on initialization
    - [ ] Ensure `dispose()` cleanup is updated (remove stream cancel calls)
    - [ ] Run tests and confirm green

- [ ] Task: Convert EmployeeProvider from Stream to Future-based fetch b946e8c
    - [ ] Write tests for EmployeeProvider one-shot fetch behavior (Red)
    - [ ] Remove `StreamSubscription _employeeStreamSubscription`
    - [ ] Replace with one-shot `Future`-based fetch on initialization
    - [ ] Ensure `dispose()` cleanup is updated
    - [ ] Run tests and confirm green

- [ ] Task: Audit and verify zero Firestore streams remain in core providers b946e8c
    - [ ] Grep codebase for `.snapshots()` usage in Transaction, Wallet, Debt, Statistics, Employee providers
    - [ ] Document remaining `.snapshots()` usages (if any) in non-core providers (SystemConfig, etc.) as out-of-scope
    - [ ] Confirm no `StreamSubscription` fields remain in the 5 target providers

- [ ] Task: Conductor - User Manual Verification 'Phase 0: Stream Eradication' (Protocol in workflow.md)

## Phase 1: Optimistic Transactions

- [ ] Task: Implement client-side UUID generation for transactions
    - [ ] Write tests verifying transaction IDs are valid UUIDs from the `uuid` package (Red)
    - [ ] Replace `_transactionRepository.generateId()` (Firestore `doc().id`) with `Uuid().v4()` in `TransactionProvider.createTransaction()`
    - [ ] Run tests and confirm green

- [ ] Task: Implement optimistic transaction creation with WriteBatch
    - [ ] Write tests for optimistic local insert (transaction appears at index 0 before Firestore write) (Red)
    - [ ] Write tests for atomic WriteBatch (transaction doc + wallet balance update) (Red)
    - [ ] Capture immutable snapshot of `_transactions` list (`_transactions.toList()`), `_transactionMap` (`Map.of()`), and related wallet balance before mutation
    - [ ] Insert transaction at `_transactions.insert(0, tx)`, update `_transactionMap`, call `safeNotify()`
    - [ ] Update related wallet balance in `WalletProvider` locally via cross-provider call
    - [ ] Execute Firestore `WriteBatch` containing transaction `.set()` + wallet balance update in background
    - [ ] Run tests and confirm green

- [ ] Task: Implement rollback mechanism for failed transaction writes
    - [ ] Write tests for rollback scenario: simulate Firestore failure, verify local state reverts to snapshot (Red)
    - [ ] In `catch` block: revert `_transactions`, `_transactionMap`, and wallet balance to captured snapshot
    - [ ] Call `safeNotify()` and route error through `AppErrorHandler`
    - [ ] Run tests and confirm green

- [ ] Task: Implement hybrid derived summaries for dashboard (transactions)
    - [ ] Write tests for dynamic summary getters computing from local `_transactions` list (Red)
    - [ ] Write tests for initial load from `stats/summary` document (Red)
    - [ ] Add getters for `totalSent`, `totalReceived`, `totalCommission` computed from local list
    - [ ] On initial load, populate summaries from `stats/summary`. After first fetch, derive locally
    - [ ] Include stats/summary document update in the transaction `WriteBatch` to keep server in sync
    - [ ] Run tests and confirm green

- [ ] Task: Implement FieldValue.serverTimestamp for transaction Firestore writes
    - [ ] Write test verifying local `DateTime.now()` is used for UI model and `FieldValue.serverTimestamp()` for Firestore document (Red)
    - [ ] Update transaction model serialization to use `FieldValue.serverTimestamp()` for `createdAt` when writing
    - [ ] Ensure local model retains `DateTime.now()` for immediate UI display
    - [ ] Run tests and confirm green

- [ ] Task: Conductor - User Manual Verification 'Phase 1: Optimistic Transactions' (Protocol in workflow.md)

## Phase 2: Optimistic Wallets

- [ ] Task: Implement client-side UUID generation for wallets
    - [ ] Write tests verifying wallet IDs are valid UUIDs (Red)
    - [ ] Replace `_walletRepository.generateId()` with `Uuid().v4()` in `WalletProvider`
    - [ ] Run tests and confirm green

- [ ] Task: Implement optimistic wallet creation with rollback
    - [ ] Write tests for optimistic local insert (wallet appears in list before Firestore write) (Red)
    - [ ] Write tests for rollback on Firestore failure (Red)
    - [ ] Capture immutable snapshot (`_wallets.toList()`, `Map.of(_walletMap)`) before mutation
    - [ ] Add wallet to `_wallets` list and `_walletMap`, call `safeNotify()`
    - [ ] Execute Firestore `.set()` in background
    - [ ] On failure: revert to snapshot, `safeNotify()`, route through `AppErrorHandler`
    - [ ] Run tests and confirm green

- [ ] Task: Implement optimistic wallet update and delete with rollback
    - [ ] Write tests for optimistic update (local state changes before Firestore) (Red)
    - [ ] Write tests for optimistic delete (wallet removed from local list before Firestore) (Red)
    - [ ] Write tests for rollback on failure for both update and delete (Red)
    - [ ] Capture snapshot, mutate locally, `safeNotify()`, execute Firestore in background
    - [ ] On failure: revert, `safeNotify()`, `AppErrorHandler`
    - [ ] Run tests and confirm green

- [ ] Task: Implement dynamic "Total Active Wallets" summary
    - [ ] Write tests for dynamic getter computing from local wallet list length/status (Red)
    - [ ] Add getter that counts wallets with active status from `_wallets`
    - [ ] Run tests and confirm green

- [ ] Task: Ensure cross-provider wallet balance sync from transactions
    - [ ] Write tests verifying that creating a transaction in Phase 1 updates the wallet balance in `WalletProvider` without Firestore re-fetch (Red)
    - [ ] Verify the `WalletProvider.updateLocalBalance()` (or equivalent) method called from `TransactionProvider` works correctly
    - [ ] Run tests and confirm green

- [ ] Task: Conductor - User Manual Verification 'Phase 2: Optimistic Wallets' (Protocol in workflow.md)

## Phase 3: Optimistic Debts

- [ ] Task: Implement client-side UUID generation for debts
    - [ ] Write tests verifying debt IDs are valid UUIDs (Red)
    - [ ] Replace `_debtRepository.generateId()` with `Uuid().v4()` in `DebtProvider`
    - [ ] Run tests and confirm green

- [ ] Task: Implement optimistic debt creation with rollback
    - [ ] Write tests for optimistic local insert (debt appears in list before Firestore write) (Red)
    - [ ] Write tests for rollback on Firestore failure (Red)
    - [ ] Capture immutable snapshot (`_debts.toList()`, `Map.of(_debtMap)`) before mutation
    - [ ] Add debt to `_debts` list and `_debtMap`, call `safeNotify()`
    - [ ] Execute Firestore `.set()` in background
    - [ ] On failure: revert to snapshot, `safeNotify()`, `AppErrorHandler`
    - [ ] Run tests and confirm green

- [ ] Task: Implement optimistic debt settlement with rollback
    - [ ] Write tests for optimistic settlement (local status changes to Paid immediately, UI moves card to Paid tab) (Red)
    - [ ] Write tests for rollback on settlement failure (status reverts, card moves back) (Red)
    - [ ] Capture snapshot of debt model and list state
    - [ ] Update local model status to Paid, `safeNotify()`
    - [ ] Execute Firestore update in background
    - [ ] On failure: revert status, `safeNotify()`, `AppErrorHandler`
    - [ ] Run tests and confirm green

- [ ] Task: Implement optimistic partial debt payment with rollback
    - [ ] Write tests for optimistic partial payment (local amount updates immediately) (Red)
    - [ ] Write tests for rollback on failure (Red)
    - [ ] Capture snapshot, update local debt amount/status, `safeNotify()`
    - [ ] Execute Firestore update in background
    - [ ] On failure: revert, `safeNotify()`, `AppErrorHandler`
    - [ ] Run tests and confirm green

- [ ] Task: Implement dynamic debt summary getters
    - [ ] Write tests for dynamic "Open Debts" count/total getter (Red)
    - [ ] Write tests for dynamic "Settled Debts" count/total getter (Red)
    - [ ] Add getters computing from local `_debts` list filtered by status
    - [ ] Run tests and confirm green

- [ ] Task: Add fetch shield to DebtProvider
    - [ ] Write tests for fetch shield behavior (~5s block after isolate state injection) (Red)
    - [ ] Implement `_activateFetchShield()` consistent with TransactionProvider/WalletProvider pattern
    - [ ] Run tests and confirm green

- [ ] Task: Conductor - User Manual Verification 'Phase 3: Optimistic Debts' (Protocol in workflow.md)

## Phase 4: Pull-to-Refresh Smart Merge & Final Verification

- [ ] Task: Implement smart upsert merge for pull-to-refresh across all providers
    - [ ] Write tests for upsert merge: incoming Firestore docs matched by UUID, local-only pending items preserved (Red)
    - [ ] In `TransactionProvider.fetchInitialTransactions(forceRefresh: true)`: match incoming docs by UUID, update existing, insert new, do NOT duplicate or overwrite optimistic pending items
    - [ ] Apply same upsert pattern to `WalletProvider.fetchInitialWallets(forceRefresh: true)`
    - [ ] Apply same upsert pattern to `DebtProvider` refresh method
    - [ ] Run tests and confirm green

- [ ] Task: Final integration verification across all providers
    - [ ] Run full test suite (`CI=true flutter test`)
    - [ ] Run static analysis (`flutter analyze`)
    - [ ] Verify no regressions in existing pull-to-refresh flows
    - [ ] Verify no remaining Firestore streams in target providers

- [ ] Task: Conductor - User Manual Verification 'Phase 4: Pull-to-Refresh Smart Merge & Final Verification' (Protocol in workflow.md)
