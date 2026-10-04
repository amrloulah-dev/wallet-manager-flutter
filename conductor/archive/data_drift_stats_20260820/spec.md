# Specification: Data Drift & Stats Aggregation Patch

## 1. Overview
Resolve the critical data drift anomaly where `totalBalance` in `stores/{storeId}/stats/summary` desynchronizes from the arithmetic sum of active `WalletModel` balances across both Cloud Firestore and client RAM state.

## 2. Functional Requirements
- **FR-1: Total Balance Synchronization in Transaction Execution**
  - Inside `TransactionValidatorService.validateAndSave`, inject `FirebaseConstants.totalBalance: FieldValue.increment(balanceChange)` into the `summaryUpdates` map before `tx.set(statsSummaryRef, summaryUpdates, SetOptions(merge: true))`.
  - Ensures every send, receive, and deposit atomically updates `stores/{storeId}/stats/summary.totalBalance` along with the individual wallet's balance.
- **FR-2: Wallet Status Toggle Idempotency**
  - In `WalletRepository.setWalletActiveStatus`, implement an early return guard `if (wallet.isActive == isActive) return;` immediately after parsing `wallet` and before calling `_statsRepository.updateStatsOnWalletChange`.
  - Prevents duplicate deductions or additions to `totalBalance` and `activeWallets` when attempting to deactivate an already inactive wallet or reactivate an active wallet.
- **FR-3: Optimistic UI Math Parity for Service Fees**
  - Update `StatisticsProvider.updateLocalStats`, `applyTransactionLocally`, and `addTransactionOptimistically` to accept optional `double serviceFee = 0.0`.
  - For debit/send transactions, calculate `newTotalBalance -= (amount + serviceFee)` to maintain exact mathematical parity with `WalletProvider.updateLocalWalletBalance`.
  - Update `TransactionProvider.createTransaction` to pass `serviceFee: serviceFee` to `sl<StatisticsProvider>().updateLocalStats(...)`.

## 3. Non-Functional Requirements
- **NFR-1: Atomicity & Rollback Integrity**
  - All Firestore modifications must remain inside existing `runTransaction` blocks.
  - Client state rollbacks via `SafeChangeNotifier` and `_rollbackLocalTx` must remain fully intact.
- **NFR-2: Zero Regression**
  - Existing limit validations, currency precision checks (EGP epsilon), and tenant isolation guards must not be affected.

## 4. Acceptance Criteria
- [ ] Executing a send/debit transaction in `TransactionValidatorService` decrements both `wallet.balance` and `stats/summary.totalBalance` atomically in Firestore.
- [ ] Executing a receive/credit or deposit transaction in `TransactionValidatorService` increments both `wallet.balance` and `stats/summary.totalBalance` atomically in Firestore.
- [ ] Calling `setWalletActiveStatus` with the current status of the wallet performs a no-op without modifying stats counters.
- [ ] Optimistic state update in `StatisticsProvider` for a debit transaction with a non-zero service fee deducts `amount + serviceFee` from `totalBalance` in memory.
- [ ] All unit and integration tests pass with 100% adherence to clean architecture principles.

## 5. Out of Scope
- Modifying offline SMS background isolates or overlay window layout.
- Changing debt settlement architecture or cash payment workflows.
