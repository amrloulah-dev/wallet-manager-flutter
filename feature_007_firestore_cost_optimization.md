# 🛠️ Detailed Execution Plan: Firestore Cost Optimization & Architecture Refactor (Feature 007)

**CRITICAL DIRECTIVES FOR DEVELOPER / AI AGENT:**
This document outlines the architectural shift from "Client-Side Aggregation" to a "Pre-aggregated Single Source of Truth" pattern, combined with Cursor-Based Pagination. 
1. Execution MUST be strictly sequential. 
2. Do NOT proceed to the next phase without completing the Verification Gates.
3. Your goal is to drastically reduce Firestore Document Reads and prevent Out-Of-Memory (OOM) crashes.

---

## 🗑️ Phase 1: Eradicate Client-Side Aggregation (The Kill Switch)

### 🔴 Problem Definition
The application currently fetches thousands of documents into device memory just to calculate totals (e.g., `getTransactionAggregates`). This causes severe billing explosions and RAM crashes.

### 🟢 Architectural Solution
Delete these methods entirely. The application will no longer perform manual reconciliation by reading entire collections.

### 📋 Implementation Tasks
- [ ] Navigate to `lib/data/repositories/transaction_repository.dart`. Delete `getTransactionAggregates` and any method that iterates over transactions to calculate sums.
- [ ] Navigate to `lib/data/repositories/stats_repository.dart`. Delete `reconcileStatsFromWallets` and `reconcileStatsFromDebts`.
- [ ] Navigate to `lib/data/repositories/debt_repository.dart`. Delete `getDebtAggregates`.
- [ ] Clean up any Provider or Controller that was calling these deleted methods.

### 🔍 Verification Gates (Phase 1)
- [ ] **Code Audit:** Search the codebase for `reconcileStatsFromWallets`, `getTransactionAggregates`, and `getDebtAggregates`. There MUST be 0 occurrences.

---

## 📄 Phase 2: Implement Cursor-Based Pagination (UI Lists)

### 🔴 Problem Definition
Methods like `getAllTransactions` and `getAllWallets` use unbounded `.get()` queries. Fetching an entire collection at once will crash the app as the store grows.

### 🟢 Architectural Solution
Enforce a hard limit of 20 documents per query and implement `startAfterDocument` for infinite scrolling functionality in the UI.

### 📋 Implementation Tasks
- [ ] Navigate to `transaction_repository.dart` and locate `getAllTransactions` (and `getTransactionsByDateRange`).
- [ ] Modify the method signature to accept an optional parameter: `DocumentSnapshot? lastDocument`.
- [ ] Append `.limit(20)` to the Firestore query.
- [ ] Add conditional logic: `if (lastDocument != null) query = query.startAfterDocument(lastDocument);`
- [ ] Repeat this EXACT pagination refactoring for `getAllWallets` (in `wallet_repository.dart`) and `getDebtsByDateRange` (in `debt_repository.dart`).
- [ ] Ensure the return type of these methods provides both the data list and the last `DocumentSnapshot` to the UI Provider for the next fetch.

### 🔍 Verification Gates (Phase 2)
- [ ] **Code Audit:** Search for `.collection(`. Any query fetching lists of Transactions, Debts, or Wallets MUST have a `.limit(20)` appended to it. Unbounded queries are strictly forbidden.

---

## ⚡ Phase 3: Single Source of Truth Subscription (Dashboard UI)

### 🔴 Problem Definition
With client-side aggregation deleted, the UI needs a new way to display totals without reading transactions.

### 🟢 Architectural Solution
The database already contains perfectly structured pre-aggregated documents:
1. `stores/{storeId}/stats/summary` (Lifetime totals: `totalBalance`, `totalTransactions`, `totalCommission`, etc.)
2. `stores/{storeId}/daily_stats/{date}` (Daily totals)
The UI must listen directly to these two documents.

### 📋 Implementation Tasks
- [ ] Navigate to the Provider/Controller responsible for the Main Dashboard / Stats UI.
- [ ] Implement a `StreamSubscription` to `_firestore.collection('stores').doc(storeId).collection('stats').doc('summary').snapshots()`.
- [ ] Implement a second `StreamSubscription` to today's daily stats document: `_firestore.collection('stores').doc(storeId).collection('daily_stats').doc(todayDateString).snapshots()`.
- [ ] Bind the UI elements (Total Balance, Total Commission, Sent/Received counts) directly to the fields in these `DocumentSnapshot` streams.

### 🔍 Verification Gates (Phase 3)
- [ ] **Architecture Audit:** Verify that the Dashboard UI is populated SOLELY by reading the `summary` and `daily_stats` documents, using exactly 2 document reads per update.

---

## 🛡️ Phase 4: Enforce Atomic Writes (The Increment Rule)

### 🔴 Problem Definition
To ensure the `summary` and `daily_stats` documents remain 100% accurate without manual reconciliation, every new transaction MUST atomically update these stats.

### 🟢 Architectural Solution
Verify and enforce the use of `FieldValue.increment` within the core transaction engine.

### 📋 Implementation Tasks
- [ ] Navigate to `TransactionValidatorService` (or the equivalent core service handling transaction creation).
- [ ] Ensure that when a transaction is saved via a Firestore `WriteBatch` or `Transaction`, the code includes updates to both the `summary` document and the `daily_stats` document.
- [ ] Ensure NO manual arithmetic is used (e.g., `totalAmount = oldAmount + newAmount`).
- [ ] You MUST use `FieldValue.increment(amount)` for values and `FieldValue.increment(1)` for counts (like `transactionCount` or `sendCount`).

### 🔍 Verification Gates (Phase 4)
- [ ] **Code Audit:** Inspect `TransactionValidatorService`. Verify that ALL updates to `summary` and `daily_stats` use `FieldValue.increment`.
- [ ] **Final Global Compile:** Run `flutter analyze`. The terminal MUST output `0 issues found`.

---