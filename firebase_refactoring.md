# 🛠️ Wallet Manager - Firebase & Firestore Refactoring Blueprint (Phase 4)

## 📌 1. General Context & System Prompt
**To the AI Agent (Antigravity / Gemini CLI):**
You are working on "Wallet Manager", a Flutter-based financial operations app for Egyptian store owners to manage digital wallets (like Vodafone Cash), track debts, and process transactions. 
**Core Constraints:**
1. The project operates on a strictly **$0 Budget** (Firebase Spark Plan). We CANNOT use Cloud Functions. 
2. All financial data must be 100% accurate. **Atomicity is non-negotiable**.
3. We must minimize Firestore reads/writes to avoid billing explosions.
4. Follow **Clean Architecture** principles.

Your task is to refactor specific repositories and providers based on the following specific issues and solutions. Do not change the overall architecture; only apply the targeted fixes.

---

## 📌 2. Fix Financial Race Conditions (Data Corruption Risks)

### 2.1. Dart-Side Math in Transactions
* **Context:** In `WalletRepository.debitWallet` and `transaction_validator_service.dart`, the balance and stats calculations are currently done in Dart memory (e.g., `currentBalance - amount`) inside a `runTransaction` block, then written as hard values. This causes race conditions if concurrent events (like background SMS parsing) trigger simultaneously.
* **Solution:** 
  * Refactor all math operations inside Firestore transactions to use `FieldValue.increment()`.
  * For `debitWallet`, replace Dart math with `'balance': FieldValue.increment(-amount)`.
  * For `stats_repository.dart` (`totalWallets` and `activeWallets`), remove the `.clamp()` logic from Dart and use `FieldValue.increment(countChange)` inside a `runTransaction`.

### 2.2. Initialization & Entity Creation Conflicts
* **Context:** `DatabaseSyncService._createStoreAndUser` runs sequential `awaits` to create a store then a user, which can cause partial failures. Also, `stats_repository.dart` initializes stats using a "read then write" pattern that conflicts if two devices open the app simultaneously.
* **Solution:**
  * In `DatabaseSyncService`, wrap `_storeRepository.createStore` and `_userRepository.createUser` inside a single `WriteBatch` to ensure atomic creation.
  * In `stats_repository.dart` (`initializeStats`), use `SetOptions(merge: true)` when setting the initial summary document to handle concurrent initializations gracefully without overwriting existing data.

---

## 📌 3. Prevent Billing Explosions & Optimize Reads

### 3.1. Unbounded Queries
* **Context:** `UserRepository` and `EmployeeRepository` fetch lists of users/employees without a `.limit()`. As the data grows, this will consume massive read quotas.
* **Solution:** Add `.limit(20)` (or a suitable number for pagination) to `getUsersByStoreId` and `getEmployeesByStoreId`. If a total count is needed for the UI, use Firestore's `count()` aggregation function.

### 3.2. Client-Side Aggregation (CPU & Read Waste)
* **Context:** `statistics_provider.dart` and `transaction_provider.dart` (`_calculateSummary`) currently fetch all transaction documents and use a `for loop` in Dart to calculate `totalCommission`, `totalAmount`, etc.
* **Solution:** Delete the client-side `for loop` aggregation completely. The database already maintains a pre-aggregated document at `stores/{storeId}/stats/summary`. Read directly from this `StatsSummaryModel` to display the data.

### 3.3. Client-Side Search Filtering
* **Context:** In `employee_provider.dart`, the `filteredEmployees` getter filters employees by name/phone in Dart memory after fetching the whole list.
* **Solution:** Delegate the search to Firestore. Use query parameters: `.where('fullName', isGreaterThanOrEqualTo: query).where('fullName', isLessThanOrEqualTo: query + '\uf8ff')`.

---

## 📌 4. State Management & Architecture Fixes

### 4.1. Stale Data in Cache
* **Context:** `TransactionRepository` and `DebtRepository` clear cached data by specifically matching `startsWith('transactions_page_0_')`. If a mutation occurs, subsequent pages remain stale.
* **Solution:** Update the cache eviction Regex/logic to clear ALL pages: `startsWith('transactions_page_')`.

### 4.2. Stateful Pagination Anti-Pattern
* **Context:** `debt_repository.dart` (`getDebtsByDateRange`) stores `_lastDocument` as an instance variable, breaking reentrancy and causing state bugs during concurrent calls.
* **Solution:** Remove `_lastDocument` as an instance variable. Refactor the method signature to accept `DocumentSnapshot? lastDocument` as a parameter (stateless pagination).

### 4.3. Stream Pipeline Async Gaps
* **Context:** `stats_repository.dart` (`watchStatsSummary`) uses `.asyncMap` to initialize stats inside the stream, causing the UI to briefly flash empty data.
* **Solution:** Remove `.asyncMap`. Ensure initialization is handled at the provider level or repository initialization phase before watching the stream.

---

## 📌 5. Technical Debt Cleanup

* **Context:** Several files use hardcoded strings for paths and bypass Dependency Injection.
* **Solution:**
  * Refactor `transaction_repository.dart` and `subscription_repository.dart` to use central path builders, e.g., `FirebaseConstants.statsSubcollection`.
  * In `employee_repository.dart`, replace `FirebaseFirestore.instance` in the constructor with the singleton access: `sl<FirebaseService>().firestore`.