# Implementation Plan: Optimistic UI Refresh Refactor

## Phase 0: Stream Eradication [checkpoint: 59bae7d]

- [x] Task: Convert StatisticsProvider from Stream to Future-based fetch b946e8c
    - [x] Write tests for StatisticsProvider one-shot fetch behavior (Red)
    - [x] Remove `StreamSubscription _summarySubscription` and `_todayStatsSubscription`
    - [x] Replace with one-shot `Future`-based fetch on initialization
    - [x] Ensure `dispose()` cleanup is updated (remove stream cancel calls)
    - [x] Run tests and confirm green

- [x] Task: Convert EmployeeProvider from Stream to Future-based fetch b946e8c
    - [x] Write tests for EmployeeProvider one-shot fetch behavior (Red)
    - [x] Remove `StreamSubscription _employeeStreamSubscription`
    - [x] Replace with one-shot `Future`-based fetch on initialization
    - [x] Ensure `dispose()` cleanup is updated
    - [x] Run tests and confirm green

- [x] Task: Audit and verify zero Firestore streams remain in core providers b946e8c
    - [x] Grep codebase for `.snapshots()` usage in Transaction, Wallet, Debt, Statistics, Employee providers
    - [x] Document remaining `.snapshots()` usages (if any) in non-core providers (SystemConfig, etc.) as out-of-scope
    - [x] Confirm no `StreamSubscription` fields remain in the 5 target providers

- [x] Task: Conductor - User Manual Verification 'Phase 0: Stream Eradication' (Protocol in workflow.md)

## Phase 1: Optimistic Transactions

- [x] Task: Implement client-side UUID generation for transactions
    - [x] Write tests verifying transaction IDs are valid UUIDs from the `uuid` package (Red)
    - [x] Replace `_transactionRepository.generateId()` (Firestore `doc().id`) with `Uuid().v4()` in `TransactionProvider.createTransaction()`
    - [x] Run tests and confirm green

- [x] Task: Implement optimistic transaction creation with WriteBatch
    - [x] Write tests for optimistic local insert (transaction appears at index 0 before Firestore write) (Red)
    - [x] Write tests for atomic WriteBatch (transaction doc + wallet balance update) (Red)
    - [x] Capture immutable snapshot of `_transactions` list (`_transactions.toList()`), `_transactionMap` (`Map.of()`), and related wallet balance before mutation
    - [x] Insert transaction at `_transactions.insert(0, tx)`, update `_transactionMap`, call `safeNotify()`
    - [x] Update related wallet balance in `WalletProvider` locally via cross-provider call
    - [x] Execute Firestore `WriteBatch` containing transaction `.set()` + wallet balance update in background
    - [x] Run tests and confirm green

- [x] Task: Implement rollback mechanism for failed transaction writes
    - [x] Write tests for rollback scenario: simulate Firestore failure, verify local state reverts to snapshot (Red)
    - [x] In `catch` block: revert `_transactions`, `_transactionMap`, and wallet balance to captured snapshot
    - [x] Call `safeNotify()` and route error through `AppErrorHandler`
    - [x] Run tests and confirm green

- [x] Task: Implement hybrid derived summaries for dashboard (transactions)
    - [x] Write tests for dynamic summary getters computing from local `_transactions` list (Red)
    - [x] Write tests for initial load from `stats/summary` document (Red)
    - [x] Add getters for `totalSent`, `totalReceived`, `totalCommission` computed from local list
    - [x] On initial load, populate summaries from `stats/summary`. After first fetch, derive locally
    - [x] Include stats/summary document update in the transaction `WriteBatch` to keep server in sync
    - [x] Run tests and confirm green

- [x] Task: Implement FieldValue.serverTimestamp for transaction Firestore writes
    - [x] Write test verifying local `DateTime.now()` is used for UI model and `FieldValue.serverTimestamp()` for Firestore document (Red)
    - [x] Update transaction model serialization to use `FieldValue.serverTimestamp()` for `createdAt` when writing
    - [x] Ensure local model retains `DateTime.now()` for immediate UI display
    - [x] Run tests and confirm green

- [x] Task: Conductor - User Manual Verification 'Phase 1: Optimistic Transactions' (Protocol in workflow.md)

## Phase 2: Optimistic Wallets

- [x] Task: Implement client-side UUID generation for wallets
    - [x] Write tests verifying wallet IDs are valid UUIDs (Red)
    - [x] Replace `_walletRepository.generateId()` with `Uuid().v4()` in `WalletProvider`
    - [x] Run tests and confirm green

- [x] Task: Implement optimistic wallet creation with rollback
    - [x] Write tests for optimistic local insert (wallet appears in list before Firestore write) (Red)
    - [x] Write tests for rollback on Firestore failure (Red)
    - [x] Capture immutable snapshot (`_wallets.toList()`, `Map.of(_walletMap)`) before mutation
    - [x] Add wallet to `_wallets` list and `_walletMap`, call `safeNotify()`
    - [x] Execute Firestore `.set()` in background
    - [x] On failure: revert to snapshot, `safeNotify()`, route through `AppErrorHandler`
    - [x] Run tests and confirm green

- [x] Task: Implement optimistic wallet update and delete with rollback
    - [x] Write tests for optimistic update (local state changes before Firestore) (Red)
    - [x] Write tests for optimistic delete (wallet removed from local list before Firestore) (Red)
    - [x] Write tests for rollback on failure for both update and delete (Red)
    - [x] Capture snapshot, mutate locally, `safeNotify()`, execute Firestore in background
    - [x] On failure: revert, `safeNotify()`, `AppErrorHandler`
    - [x] Run tests and confirm green

- [x] Task: Implement dynamic "Total Active Wallets" summary
    - [x] Write tests for dynamic getter computing from local wallet list length/status (Red)
    - [x] Add getter that counts wallets with active status from `_wallets`
    - [x] Run tests and confirm green

- [x] Task: Ensure cross-provider wallet balance sync from transactions
    - [x] Write tests verifying that creating a transaction in Phase 1 updates the wallet balance in `WalletProvider` without Firestore re-fetch (Red)
    - [x] Verify the `WalletProvider.updateLocalBalance()` (or equivalent) method called from `TransactionProvider` works correctly
    - [x] Run tests and confirm green

- [x] Task: Conductor - User Manual Verification 'Phase 2: Optimistic Wallets' (Protocol in workflow.md)

## Phase 3: Optimistic Debts

- [x] Task: Implement client-side UUID generation for debts
    - [x] Write tests verifying debt IDs are valid UUIDs (Red)
    - [x] Replace `_debtRepository.generateId()` with `Uuid().v4()` in `DebtProvider`
    - [x] Run tests and confirm green

- [x] Task: Implement optimistic debt creation with rollback
    - [x] Write tests for optimistic local insert (debt appears in list before Firestore write) (Red)
    - [x] Write tests for rollback on Firestore failure (Red)
    - [x] Capture immutable snapshot (`_debts.toList()`, `Map.of(_debtMap)`) before mutation
    - [x] Add debt to `_debts` list and `_debtMap`, call `safeNotify()`
    - [x] Execute Firestore `.set()` in background
    - [x] On failure: revert to snapshot, `safeNotify()`, `AppErrorHandler`
    - [x] Run tests and confirm green

- [x] Task: Implement optimistic debt settlement with rollback
    - [x] Write tests for optimistic settlement (local status changes to Paid immediately, UI moves card to Paid tab) (Red)
    - [x] Write tests for rollback on settlement failure (status reverts, card moves back) (Red)
    - [x] Capture snapshot of debt model and list state
    - [x] Update local model status to Paid, `safeNotify()`
    - [x] Execute Firestore update in background
    - [x] On failure: revert status, `safeNotify()`, `AppErrorHandler`
    - [x] Run tests and confirm green

- [x] Task: Implement optimistic partial debt payment with rollback
    - [x] Write tests for optimistic partial payment (local amount updates immediately) (Red)
    - [x] Write tests for rollback on failure (Red)
    - [x] Capture snapshot, update local debt amount/status, `safeNotify()`
    - [x] Execute Firestore update in background
    - [x] On failure: revert, `safeNotify()`, `AppErrorHandler`
    - [x] Run tests and confirm green

- [x] Task: Implement dynamic debt summary getters
    - [x] Write tests for dynamic "Open Debts" count/total getter (Red)
    - [x] Write tests for dynamic "Settled Debts" count/total getter (Red)
    - [x] Add getters computing from local `_debts` list filtered by status
    - [x] Run tests and confirm green

- [x] Task: Add fetch shield to DebtProvider
    - [x] Write tests for fetch shield behavior (~5s block after isolate state injection) (Red)
    - [x] Implement `_activateFetchShield()` consistent with TransactionProvider/WalletProvider pattern
    - [x] Run tests and confirm green

- [x] Task: Conductor - User Manual Verification 'Phase 3: Optimistic Debts' (Protocol in workflow.md)

## Phase 4: Pull-to-Refresh Smart Merge & Final Verification

- [x] Task: Implement smart upsert merge for pull-to-refresh across all providers
    - [x] Write tests for upsert merge: incoming Firestore docs matched by UUID, local-only pending items preserved (Red)
    - [x] In `TransactionProvider.fetchInitialTransactions(forceRefresh: true)`: match incoming docs by UUID, update existing, insert new, do NOT duplicate or overwrite optimistic pending items
    - [x] Apply same upsert pattern to `WalletProvider.fetchInitialWallets(forceRefresh: true)`
    - [x] Apply same upsert pattern to `DebtProvider` refresh method
    - [x] Run tests and confirm green

- [x] Task: Final integration verification across all providers
    - [x] Run full test suite (`CI=true flutter test`)
    - [x] Run static analysis (`flutter analyze`)
    - [x] Verify no regressions in existing pull-to-refresh flows
    - [x] Verify no remaining Firestore streams in target providers

- [x] Task: Conductor - User Manual Verification 'Phase 4: Pull-to-Refresh Smart Merge & Final Verification' (Protocol in workflow.md)
