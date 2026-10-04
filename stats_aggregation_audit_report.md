# SYSTEM AUDIT & REVERSE ENGINEERING REPORT: STATS AGGREGATION PIPELINE

**Audit Focus:** `stores/{storeId}/stats/summary` document lifecycle, `totalBalance` aggregation, and `WalletModel.balance` synchronization drift.  
**Framework Standard:** Global Documentation Framework — Zero Hallucination & Evidence-Based Verification.  
**Target Scope:** `StatsSummaryModel`, `WalletModel`, `TransactionModel`, `StatsRepository`, `WalletRepository`, `TransactionRepository`, `DebtRepository`, `TransactionValidatorService`, `StatisticsProvider`, `WalletProvider`, `TransactionProvider`, and `DebtProvider`.

---

## 1. `totalBalance` Data Flow Architecture

### 1.1 Storage Topology & Schema Definition
The `totalBalance` metric represents the store-wide aggregate liquid capital across all active wallets.

- **Firestore Document Path:** `stores/{storeId}/stats/summary` (Subcollection structure resolved in [FirebaseConstants.statsSummaryPath](file:///c:/src/walletmanager/lib/core/constants/firebase_constants.dart#L84-L85)).
- **Data Model Representation:** [StatsSummaryModel](file:///c:/src/walletmanager/lib/data/models/stats_summary_model.dart#L39-L115) defines `final double totalBalance` (defaulting to `0.0` upon initialization).
- **Deserialization:** [StatsSummaryModel.fromMap](file:///c:/src/walletmanager/lib/data/models/stats_summary_model.dart#L92-L115) maps `data['totalBalance']` via [NumberParser.toDouble](file:///c:/src/walletmanager/lib/core/utils/number_parser.dart).
- **Individual Wallet Balance:** [WalletModel.balance](file:///c:/src/walletmanager/lib/data/models/wallet_model.dart#L173) in collection `wallets/{walletId}`.

### 1.2 Data Flow Lifecycle Diagram
```
                      ┌──────────────────────────────────────────────┐
                      │   Store Initialization / Migration Reset     │
                      └──────────────────────┬───────────────────────┘
                                             │
                                             ▼
                      ┌──────────────────────────────────────────────┐
                      │ Firestore: stores/{storeId}/stats/summary   │
                      │        (totalBalance: double)                │
                      └───────┬───────────────────────────────▲──────┘
                              │                               │
                              │ Read                          │ Increments / Overwrites
                              ▼                               │
    ┌──────────────────────────────────────────────┐          │
    │ Client State (RAM):                          │          │
    │  - StatisticsProvider._dashboardSummary      │          │
    │  - WalletProvider._wallets / _walletMap      │          │
    │  - TransactionProvider._transactions         │          │
    └──────────────────────────────────────────────┘          │
                              │                               │
            Optimistic UI /   │                               │
            CRUD Operations   ▼                               │
    ┌─────────────────────────────────────────────────────────┴──────┐
    │ Persistence & Mutation Layer:                                 │
    │  1. WalletRepository.createWallet                              │
    │  2. WalletRepository.setWalletActiveStatus                     │
    │  3. TransactionValidatorService.validateAndSave (TX Execution) │
    │  4. WalletRepository.updateWallet (Direct Editing)             │
    │  5. MigrationService.recalculateStoreStats (Batch Rollup)      │
    └────────────────────────────────────────────────────────────────┘
```

---

## 2. Mutation Entry Points (Where Does the Number Change?)

### 2.1 Complete Inventory of Firestore Mutations of `totalBalance`

The following functions in the codebase directly write to or increment the `totalBalance` field in `stores/{storeId}/stats/summary`:

| # | Function | File & Line Number | Mutation Type | Trigger Scenario |
|---|---|---|---|---|
| 1 | `StoreRepository.createStore` | [store_repository.dart:79-88](file:///c:/src/walletmanager/lib/data/repositories/store_repository.dart#L79-L88) | `batch.set` (`totalBalance: 0.0`) | New store registration. |
| 2 | `StatsRepository.initializeStats` | [stats_repository.dart:101-106](file:///c:/src/walletmanager/lib/data/repositories/stats_repository.dart#L101-L106) | `docRef.set` (`totalBalance: 0.0`, merge) | On-demand stats doc creation if missing. |
| 3 | `StatsRepository.updateStatsOnWalletChange` | [stats_repository.dart:249-300](file:///c:/src/walletmanager/lib/data/repositories/stats_repository.dart#L249-L300) | `FieldValue.increment(balanceChange)` | Helper invoked by `WalletRepository` operations. |
| 4 | `WalletRepository.createWallet` | [wallet_repository.dart:46-52](file:///c:/src/walletmanager/lib/data/repositories/wallet_repository.dart#L46-L52) | Passes `balanceChange: wallet.balance` to `updateStatsOnWalletChange` | When a new wallet document is committed. |
| 5 | `WalletRepository.creditWallet` | [wallet_repository.dart:247-251](file:///c:/src/walletmanager/lib/data/repositories/wallet_repository.dart#L247-L251) | Passes `balanceChange: amount` to `updateStatsOnWalletChange` | Direct top-up method in `WalletRepository` (standalone). |
| 6 | `WalletRepository.debitWallet` | [wallet_repository.dart:287-291](file:///c:/src/walletmanager/lib/data/repositories/wallet_repository.dart#L287-L291) | Passes `balanceChange: -amount` to `updateStatsOnWalletChange` | Direct deduction method in `WalletRepository` (standalone). |
| 7 | `WalletRepository.setWalletActiveStatus` | [wallet_repository.dart:326-332](file:///c:/src/walletmanager/lib/data/repositories/wallet_repository.dart#L326-L332) | Passes `balanceChange: isActive ? wallet.balance : -wallet.balance` | Soft deletion / reactivation of a wallet. |
| 8 | `MigrationService.recalculateStoreStats` | [migration_service.dart:94-97](file:///c:/src/walletmanager/lib/data/services/migration_service.dart#L94-L97) | `set` (`totalBalance: sum('balance')`) | Admin/Maintenance aggregate recalculation. |

---

### 2.2 Complete Inventory of Firestore Mutations of `WalletModel.balance`

The following functions in the codebase mutate the `balance` field within `wallets/{walletId}` documents:

| # | Function | File & Line Number | Mutation Type | Associated Stats Update? |
|---|---|---|---|---|
| 1 | `TransactionValidatorService.validateAndSave` | [transaction_validator_service.dart:191, 259](file:///c:/src/walletmanager/lib/data/services/transaction_validator_service.dart#L191-L259) | `walletUpdateData['balance'] = FieldValue.increment(balanceChange)` | **NO `totalBalance` UPDATE.** Only updates transaction counters/volumes in summary. |
| 2 | `WalletRepository.createWallet` | [wallet_repository.dart:44](file:///c:/src/walletmanager/lib/data/repositories/wallet_repository.dart#L44) | `batch.set(walletRef, wallet.toFirestore())` | **YES.** Increments `totalBalance` by `wallet.balance`. |
| 3 | `WalletRepository.updateWallet` | [wallet_repository.dart:213-223](file:///c:/src/walletmanager/lib/data/repositories/wallet_repository.dart#L213-L223) | `transaction.update(docRef, updateData)` | **NO.** Mutates arbitrary fields including `balance` without touching stats summary. |
| 4 | `WalletRepository.creditWallet` | [wallet_repository.dart:254](file:///c:/src/walletmanager/lib/data/repositories/wallet_repository.dart#L254) | `transaction.update(walletRef, {'balance': FieldValue.increment(amount)})` | **YES.** Increments `totalBalance` by `amount`. |
| 5 | `WalletRepository.debitWallet` | [wallet_repository.dart:294](file:///c:/src/walletmanager/lib/data/repositories/wallet_repository.dart#L294) | `transaction.update(walletRef, {'balance': FieldValue.increment(-amount)})` | **YES.** Decrements `totalBalance` by `-amount`. |

---

## 3. Atomicity & Batch Write Analysis

### 3.1 Transaction Creation Pipeline: The Core Breakdown
All standard user transactions (Send/Debit, Receive/Credit, and Deposit/Top-up) flow through:
1. `TransactionProvider.createTransaction` ([transaction_provider.dart:398-650](file:///c:/src/walletmanager/lib/providers/transaction_provider.dart#L398-L650))
2. `TransactionRepository.createTransaction` ([transaction_repository.dart:71-139](file:///c:/src/walletmanager/lib/data/repositories/transaction_repository.dart#L71-L139))
3. `TransactionValidatorService.validateAndSave` ([transaction_validator_service.dart:27-353](file:///c:/src/walletmanager/lib/data/services/transaction_validator_service.dart#L27-L353))

#### Firestore Transaction Scope in `validateAndSave`:
Inside [transaction_validator_service.dart:56-336](file:///c:/src/walletmanager/lib/data/services/transaction_validator_service.dart#L56-L336), execution is encapsulated inside `_firestore.runTransaction<void>((tx) async { ... })`:
- **Read:** `final walletSnap = await tx.get(walletRef);`
- **Write 1 (Transaction doc):** `tx.set(txRef, txData);` ([Line 185](file:///c:/src/walletmanager/lib/data/services/transaction_validator_service.dart#L185))
- **Write 2 (Wallet doc balance & limits):** `tx.update(walletRef, walletUpdateData);` ([Line 259](file:///c:/src/walletmanager/lib/data/services/transaction_validator_service.dart#L259))
- **Write 3 (Stats Summary doc):** `tx.set(statsSummaryRef, summaryUpdates, SetOptions(merge: true));` ([Line 293](file:///c:/src/walletmanager/lib/data/services/transaction_validator_service.dart#L293))
- **Write 4 (Daily Stats doc):** `tx.set(dailyStatsRef, dailyStatsUpdates, SetOptions(merge: true));` ([Line 318](file:///c:/src/walletmanager/lib/data/services/transaction_validator_service.dart#L318))
- **Write 5 (Extra writes - global stats / debt if applicable):** `await extraWrites(tx);` ([Line 327](file:///c:/src/walletmanager/lib/data/services/transaction_validator_service.dart#L327))

#### Atomicity Evaluation:
- **Transaction Isolation:** From a database transaction perspective, all database writes within `validateAndSave` are strictly atomic. A network drop during commit aborts all writes; no partial database state is committed.
- **The Core Omission:** The `summaryUpdates` map ([transaction_validator_service.dart:265-292](file:///c:/src/walletmanager/lib/data/services/transaction_validator_service.dart#L265-L292)) contains:
  ```dart
  final Map<String, dynamic> summaryUpdates = {
    FirebaseConstants.totalTransactions: FieldValue.increment(1),
    FirebaseConstants.totalTransactionsToday: FieldValue.increment(1),
    FirebaseConstants.totalCommission: FieldValue.increment(transaction.commission),
    FirebaseConstants.totalCommissionToday: FieldValue.increment(transaction.commission),
    FirebaseConstants.totalServiceFee: FieldValue.increment(transaction.serviceFee),
    FirebaseConstants.totalServiceFeeToday: FieldValue.increment(transaction.serviceFee),
    'lastUpdated': FieldValue.serverTimestamp(),
  };

  if (transaction.isSend) {
    summaryUpdates['sendCount'] = FieldValue.increment(1);
    summaryUpdates[FirebaseConstants.totalSentAmount] = FieldValue.increment(transaction.amount);
    summaryUpdates[FirebaseConstants.totalSentAmountToday] = FieldValue.increment(transaction.amount);
  } else if (transaction.isReceive) {
    summaryUpdates['receiveCount'] = FieldValue.increment(1);
    summaryUpdates[FirebaseConstants.totalReceivedAmount] = FieldValue.increment(transaction.amount);
    summaryUpdates[FirebaseConstants.totalReceivedAmountToday] = FieldValue.increment(transaction.amount);
  }
  ```
  **Evidence:** `totalBalance` is **NEVER inserted into `summaryUpdates`**.
  While `wallet.balance` is decremented (for Send) or incremented (for Receive/Deposit), `summary.totalBalance` remains completely untouched in Firestore.

---

## 4. Rollback Mechanism Safety

### 4.1 State Capture and Rollback in `TransactionProvider`
In [transaction_provider.dart:510-640](file:///c:/src/walletmanager/lib/providers/transaction_provider.dart#L510-L640):

1. **Pre-mutation Snapshot Capture:**
   ```dart
   oldTransactions = _transactions.toList();
   oldTransactionMap = Map<String, TransactionModel>.from(_transactionMap);
   oldSummary = Map<String, dynamic>.from(_summary);
   if (_walletProvider != null && _walletProvider!.walletMap.containsKey(walletId)) {
     oldWalletSnapshot = _walletProvider!.walletMap[walletId];
   }
   statsProvider = sl.isRegistered<StatisticsProvider>() ? sl<StatisticsProvider>() : null;
   if (statsProvider != null) {
     oldStatsSummary = statsProvider.dashboardSummary;
     oldStatsToday = statsProvider.todayStats;
   }
   ```
2. **Local Optimistic Mutation:**
   - Appends to `_transactions` & updates local `_summary`.
   - `_walletProvider!.updateLocalBalance(walletId, amount, transactionType, serviceFee: serviceFee)` ([Line 581](file:///c:/src/walletmanager/lib/providers/transaction_provider.dart#L581)).
   - `sl<StatisticsProvider>().updateLocalStats(amount, transactionType, commission: commission)` ([Line 601](file:///c:/src/walletmanager/lib/providers/transaction_provider.dart#L601)), which calls `StatisticsProvider.addTransactionOptimistically` ([statistics_provider.dart:246-309](file:///c:/src/walletmanager/lib/providers/statistics_provider.dart#L246-L309)).
3. **Execution Failure Catch & Rollback:**
   - If `_transactionRepository.createTransaction` throws an exception, `_rollbackLocalTx` is executed ([Lines 622, 627, 632, 637](file:///c:/src/walletmanager/lib/providers/transaction_provider.dart#L622-L638)):
     - Restores `_transactions`, `_transactionMap`, and `_summary`.
     - Calls `_walletProvider.rollbackWallet(oldWalletSnapshot)` ([Line 831](file:///c:/src/walletmanager/lib/providers/transaction_provider.dart#L831)).
     - Calls `statsProvider.rollbackStats(oldStatsSummary, oldStatsToday)` ([Line 836](file:///c:/src/walletmanager/lib/providers/transaction_provider.dart#L836)).

### 4.2 State Rollback Vulnerabilities Identified

#### Vulnerability 1: The Phantom RAM-Firestore Disconnect
- When `createTransaction` succeeds, RAM (`StatisticsProvider._dashboardSummary.totalBalance`) was incremented/decremented optimistically in [statistics_provider.dart:268, 272](file:///c:/src/walletmanager/lib/providers/statistics_provider.dart#L268-L272).
- However, because Firestore never received a `totalBalance` write in `validateAndSave`, the cloud document remained static.
- **Consequence:** The client session temporarily displays the updated sum in UI. As soon as `StatisticsProvider.fetchDashboardStats(forceRefresh: true)` is triggered, or the user navigates away and re-enters the dashboard, `_statsRepository.getStatsSummary(storeId)` fetches the stale Firestore document, snapping `totalBalance` back to the pre-transaction value while wallet balances remain altered.

#### Vulnerability 2: In-Memory Fee Calculation Discrepancy in `StatisticsProvider`
- In [statistics_provider.dart:263-273](file:///c:/src/walletmanager/lib/providers/statistics_provider.dart#L263-L273):
  ```dart
  if (type == 'credit') {
    newTotalBalance += amount;
  } else if (type == 'debit') {
    newTotalBalance -= amount;
  }
  ```
- In [wallet_provider.dart:138-142](file:///c:/src/walletmanager/lib/providers/wallet_provider.dart#L138-L142) and [transaction_validator_service.dart:46-47](file:///c:/src/walletmanager/lib/data/services/transaction_validator_service.dart#L46-L47):
  - A Debit transaction deducts `amount + serviceFee` from the wallet.
- **Consequence:** Even in RAM during an optimistic update, `StatisticsProvider` only subtracts `amount`, while `WalletProvider` subtracts `amount + serviceFee`. This immediately introduces data drift between total wallet balances and `totalBalance` in memory by the exact amount of the `serviceFee`.

#### Vulnerability 3: Missing Inter-Provider Ingestion on Wallet CRUD
- When a wallet is created in `WalletProvider.createWallet` ([wallet_provider.dart:372-450](file:///c:/src/walletmanager/lib/providers/wallet_provider.dart#L372-L450)) or deleted in `WalletProvider.deleteWallet` ([wallet_provider.dart:563-608](file:///c:/src/walletmanager/lib/providers/wallet_provider.dart#L563-L608)), `StatisticsProvider` is **never injected or notified**.
- As a result, `StatisticsProvider.dashboardSummary` in RAM maintains outdated `totalBalance`, `totalWallets`, and `activeWallets` counts until a remote network refetch occurs.

---

## 5. Identified Vulnerabilities (The Root Causes of Data Drift)

### 🚨 Root Cause 1: Complete Omission of `totalBalance` in `TransactionValidatorService`
* **File:** [lib/data/services/transaction_validator_service.dart:265-293](file:///c:/src/walletmanager/lib/data/services/transaction_validator_service.dart#L265-L293)
* **Mechanism:** When any Send, Receive, or Deposit transaction executes, `validateAndSave` modifies `wallets/{walletId}.balance` via `FieldValue.increment(balanceChange)`, but excludes `'totalBalance'` from `summaryUpdates`.
* **Impact:** Every single transaction processed in the application widens the disparity between the sum of wallet balances and `stores/{storeId}/stats/summary.totalBalance`.

---

### 🚨 Root Cause 2: Non-Idempotent Status Toggles in `WalletRepository.setWalletActiveStatus`
* **File:** [lib/data/repositories/wallet_repository.dart:315-340](file:///c:/src/walletmanager/lib/data/repositories/wallet_repository.dart#L315-L340)
* **Mechanism:**
  ```dart
  Future<void> setWalletActiveStatus(String walletId, bool isActive) async {
    await _firestore.runTransaction((transaction) async {
      ...
      final wallet = WalletModel.fromFirestore(walletSnap);

      await _statsRepository.updateStatsOnWalletChange(
        wallet.storeId,
        countChange: isActive ? 1 : -1,
        activeCountChange: isActive ? 1 : -1,
        balanceChange: isActive ? wallet.balance : -wallet.balance,
        firestoreTransaction: transaction,
      );

      transaction.update(walletRef, {
        FirebaseConstants.isActive: isActive,
        FirebaseConstants.updatedAt: FieldValue.serverTimestamp(),
      });
    });
  }
  ```
* **Vulnerability:** `setWalletActiveStatus` does not compare `wallet.isActive == isActive`.
* **Impact:** If `deleteWallet` or `setWalletActiveStatus(walletId, false)` is invoked on a wallet that is **already inactive**, it unconditionally subtracts `wallet.balance` from `totalBalance` and decrements `activeWallets` a second time, resulting in negative balance drift.

---

### 🚨 Root Cause 3: Direct Wallet Update Bypass (`WalletRepository.updateWallet`)
* **File:** [lib/data/repositories/wallet_repository.dart:207-224](file:///c:/src/walletmanager/lib/data/repositories/wallet_repository.dart#L207-L224)
* **Mechanism:** `updateWallet` applies arbitrary payload updates to Firestore:
  ```dart
  final updateData = {
    ...data,
    FirebaseConstants.updatedAt: FieldValue.serverTimestamp()
  };
  transaction.update(docRef, updateData);
  ```
* **Impact:** When a wallet's balance or status is edited directly through `updateWallet`, no adjustment is made to `stores/{storeId}/stats/summary.totalBalance`, causing silent divergence.

---

### 🚨 Root Cause 4: Disconnected Debt Payment Pipeline
* **Files:** [lib/data/repositories/debt_repository.dart:194-250](file:///c:/src/walletmanager/lib/data/repositories/debt_repository.dart#L194-L250) and [lib/providers/debt_provider.dart:585-689](file:///c:/src/walletmanager/lib/providers/debt_provider.dart#L585-L689)
* **Mechanism:** `DebtRepository.processPayment` mutates `DebtModel` and debt summary fields (`openDebtsCount`, `totalOpenAmount`, `paidDebtsCount`, `totalPaidAmount`). It does not associate with a target `walletId` or record a financial deposit transaction.
* **Impact:** Repaid debts do not credit digital wallets automatically. If an operator assumes debt repayment automatically increases `totalBalance`, this discrepancy represents an architectural separation between cash debt settlement and wallet balances.

---

### 🚨 Root Cause 5: Asymmetric Isolation in `MigrationService` vs Operational Flow
* **File:** [lib/data/services/migration_service.dart:26-31, 94-97](file:///c:/src/walletmanager/lib/data/services/migration_service.dart#L26-L31)
* **Mechanism:** `MigrationService.recalculateStoreStats` computes `totalBalance` using:
  ```dart
  final activeWalletsQuery = walletsBaseQuery.where(FirebaseConstants.isActive, isEqualTo: true);
  final activeWalletsStats = await activeWalletsQuery.aggregate(count(), sum('balance')).get();
  ```
* **Impact:** Running `MigrationService` instantly resets `totalBalance` to the true mathematical sum of active wallets. However, as soon as standard transactions run through `TransactionValidatorService`, `totalBalance` immediately freezes while wallet balances change, recreating the drift.

---

## 6. Comprehensive Audit Matrix

| Operation | `WalletModel.balance` Updated in Firestore? | `summary.totalBalance` Updated in Firestore? | Atomicity Guaranteed? | Optimistic RAM Sync? |
|---|---|---|---|---|
| **Send (Debit) Transaction** | ✅ Yes (`- (amount + fee)`) | ❌ **No (Omitted)** | ✅ Atomic (via `runTransaction`) | ⚠️ Partial (Omits fee in RAM stats) |
| **Receive (Credit) Transaction** | ✅ Yes (`+ amount`) | ❌ **No (Omitted)** | ✅ Atomic (via `runTransaction`) | ✅ Yes |
| **Deposit Transaction** | ✅ Yes (`+ (amount + comm)`) | ❌ **No (Omitted)** | ✅ Atomic (via `runTransaction`) | ❌ No in-memory deposit mapping |
| **Wallet Creation** | ✅ Yes (`initialBalance`) | ✅ Yes (`+ initialBalance`) | ✅ Atomic (via `WriteBatch`) | ❌ Not synced to `StatisticsProvider` in RAM |
| **Wallet Deactivation (Delete)** | ➖ Unchanged (`isActive: false`) | ✅ Yes (`- balance`) | ✅ Atomic (via `runTransaction`) | ❌ Not synced to `StatisticsProvider` in RAM (Also vulnerable to double-deduction) |
| **Direct Wallet Edit** | ✅ If `balance` in payload | ❌ **No (Omitted)** | ✅ Atomic (via `runTransaction`) | ❌ No stats sync |
| **Debt Payment** | ❌ No wallet selected | ❌ No change to `totalBalance` | ✅ Atomic (Debt stats only) | ✅ RAM debt stats synced |
| **Migration Recalculate** | ➖ Unchanged | ✅ Overwritten with true sum | ⚠️ Independent aggregate query + set | ❌ Requires manual refresh |

---
**Audit Status:** COMPLETE. All findings verified directly from active code references with Zero Hallucination.
