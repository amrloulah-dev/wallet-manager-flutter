# 🕵️ Report 4: Firebase & Firestore Audit (Exhaustive)

**Application:** Wallet Manager (ewallet-manager-421b8)  
**Auditor:** Elite Firebase/Flutter Data Architect  
**Date:** 2026-04-30  
**Phase:** 4 — Exhaustive Static Analysis
---

## 🔴 CRITICAL (Blockers / Billing Explosions / Race Conditions)

*Definition: Unbounded queries without limits, missing `WriteBatch` for multi-writes, math done in Dart instead of `FieldValue.increment()`, or client-side filtering of sensitive data.*

| File Path | Line(s) | The Exact Issue / Code Snippet | Why it's a severe problem |
| :--- | :--- | :--- | :--- |
| `lib/data/repositories/wallet_repository.dart` | **217–248** | **`debitWallet`**: Reads `currentBalance`, then writes `'balance': currentBalance - amount` (hardcoded value). Entirely inside `runTransaction` but NOT using `FieldValue.increment()`. | **SEVERE RACE CONDITION**: Between the `tx.get(walletRef)` read and the `tx.update(walletRef, {...})` write, another concurrent write can modify the balance. If two debits fire simultaneously, one will be silently lost. Financial app = data corruption. Must replace with `'balance': FieldValue.increment(-amount)`. |
| `lib/data/services/transaction_validator_service.dart` | **165–167** | Balance calculated in Dart memory: `walletUpdateData['balance'] = validationWallet.balance + balanceChange;` then written back as hard value. | **SEVERE RACE CONDITION**: Even inside `runTransaction`, writing a pre-computed balance value is dangerous. The fresh wallet data was READ at line 47, but another concurrent transaction on the same wallet (e.g., overlay SMS) could commit first, making `validationWallet.balance` stale. Must use `'balance': FieldValue.increment(balanceChange)`. |
| `lib/data/repositories/stats_repository.dart` | **194–213** | `totalWallets` and `activeWallets` use Dart arithmetic: `final newTotal = (currentTotal + countChange).clamp(0, 9999999).toInt(); summaryUpdates['totalWallets'] = newTotal;` | **RACE CONDITION**: Counter stats like `totalWallets` are read then written back as hard integer values. A concurrent wallet creation across two devices would lose one count. Must use `FieldValue.increment(countChange)` with a clamp done in Firestore rules or pre-aggregation. |
| `lib/data/repositories/user_repository.dart` | **104–118** | `getUsersByStoreId`: `.where(storeId).where(isActive).get()` — **NO LIMIT applied**. Fetches entire `users` subcollection. | **BILLING EXPLOSION**: As store employees grow, this unbounded query reads ALL user documents every call. Every user added = more billing. Should add `.limit(100)` or use aggregate count. |
| `lib/data/repositories/stats_repository.dart` | **28–36** | `getStatsSummary` and `initializeStats` — read then write pattern for stats initialization. On first load for a new store, if two devices simultaneously call `getStatsSummary` and both see doc missing, both will call `initializeStats`, causing a write conflict. | **RACE CONDITION on initialization**: Missing `SetOptions(merge: true)` on the initial set, or proper `runTransaction` wrapping. |
| `lib/data/repositories/user_repository.dart` | **122–138** | `getEmployeesByStoreId`: `.where(storeId).where(role).where(isActive).orderBy(fullName).get()` — **NO LIMIT**. Fetches all employees ordered by name. | **BILLING EXPLOSION**: Same as `getUsersByStoreId`. Employee count unbounded. Must add `.limit(100)` and pagination. |

---

## 🟠 MEDIUM (Tech Debt / Cache Inefficiency)

*Definition: N+1 query structures, improper error mapping for FirebaseExceptions, lack of pagination setup.*

| File Path | Line(s) | The Exact Issue / Code Snippet | Recommended Pattern |
| :--- | :--- | :--- | :--- |
| `lib/providers/employee_provider.dart` | **38–46** | `filteredEmployees` getter: `return _employees.where((employee) { final query = _searchQuery...; return (nameMatch || phoneMatch) && activeMatch; }).toList();` — Client-side filtering of the entire `_employees` list. | **N+1 / Client Filtering**: The full list is fetched via `watchEmployees` with `limit(100)` already, but search filtering is done in Dart. For stores with many employees, implement Firestore-side query: `.where('fullName', isGreaterThanOrEqualTo: query).where('fullName', isLessThanOrEqualTo: query + '\uf8ff')`. |
| `lib/data/repositories/stats_repository.dart` | **200–202, 210–212** | `totalWallets` and `activeWallets` count updates use Dart `.clamp()` arithmetic after reading summary doc. Same code path as the CRITICAL issue but for the non-transactional `updateStatsOnWalletChange` standalone method. | Pre-aggregate counts using `FieldValue.increment()` (positive or negative) instead of reading and re-writing. Wrap in `runTransaction` with `FieldValue.increment()`. |
| `lib/providers/statistics_provider.dart` | **246–266** | `_calculateSummary()` (private, called by `_fetchSummary`): iterates `_transactions` list in a `for` loop summing `totalCommission`, `totalAmount`, `sendCount`, `receiveCount` **client-side**. | **CLIENT-SIDE AGGREGATION**: For dashboards with thousands of transactions, summing in Dart is O(N). Should use the pre-aggregated `StatsSummaryModel` from `stats/summary` subcollection (already available via `watchStatsSummary`). The `_summary` map in the provider is redundant. |
| `lib/data/repositories/stats_repository.dart` | **84–93** | `watchStatsSummary`: `.snapshots().asyncMap((doc) async { ... await initializeStats(storeId); ... })` — Uses `asyncMap` which creates a **new async gap** inside the stream for each document. | **STREAM PIPELINE ISSUE**: `asyncMap` defers execution, meaning the stream can emit before `initializeStats` completes, causing the UI to briefly see an empty summary. Use `.asyncExpand` or handle initialization in the provider layer instead. |
| `lib/data/repositories/debt_repository.dart` | **494–540** | `fetchDebtStatistics`: Runs 2 `aggregate(..., count())` queries sequentially in parallel (`Future.wait`). Then a second `paidQuery` without `count()` is built but not executed separately. | **SUBOPTIMAL AGGREGATION**: The `paidQuery` is constructed but only `paidAggregate` with `sum` + `count()` is awaited. The second query is effectively a no-op or dead code. Consolidate into a single `aggregate(sum(), count())` per baseQuery. |
| `lib/providers/transaction_provider.dart` | **246–266** | `_calculateSummary()`: client-side aggregation of `_transactions` list (totalCommission, totalAmount, sendCount, receiveCount). | **CLIENT-SIDE AGGREGATION**: Same pattern as statistics provider. Should rely on pre-aggregated `stats/summary` document, available via `watchStatsSummary`. |
| `lib/data/repositories/debt_repository.dart` | **333–375** | `getDebtsByDateRange`: uses `_lastDocument` as instance state for pagination (`_lastDocument = snapshot.docs.last`). Not passed as parameter. | **STATEFUL PAGINATION ANTI-PATTERN**: `_lastDocument` is stored as instance field. This makes the method non-reentrant and breaks in concurrent/overlay contexts. Should be stateless with `DocumentSnapshot? lastDocument` as parameter (like `transaction_repository.dart:162`). |
| `lib/data/repositories/employee_repository.dart` | **21–41** | `getEmployeesByStoreId`: Uses `.get()` without limit. | **BILLING INEFFICIENCY**: No limit. Combine with `count().get()` for the count operation and `.limit(100)` for the data fetch. |

---

## 🟢 QUICK WINS (Low Hanging Fruit)

*Definition: Unused Firebase references, repetitive collection path strings instead of centralized constants.*

| File Path | Line(s) | The Exact Issue / Code Snippet | Recommended Fix |
| :--- | :--- | :--- | :--- |
| `lib/data/repositories/transaction_repository.dart` | **1–9** | Imports include `'package:walletmanager/../firebase_constants.dart'` and `'package:walletmanager/../firebase_service.dart'`, but no centralized `_storeId` path constant for subcollection path `stores/{storeId}/stats/summary`. Each repo rebuilds this path inline. | Extract to `FirebaseConstants.statsSubcollection` and `FirebaseConstants.summaryDoc` path builder: `String statsPath(String storeId) => '${FirebaseConstants.storesCollection}/$storeId/${FirebaseConstants.statsCollection}/${FirebaseConstants.summaryDoc}'`. |
| `lib/data/repositories/employee_repository.dart` | **17–19** | Constructor: `_firestore = firestore ?? FirebaseFirestore.instance` — directly uses `FirebaseFirestore.instance` instead of going through `FirebaseService().firestore` singleton. | Unify to `FirebaseService().firestore` for consistency and to benefit from the singleton's settings (persistence, cacheSize). |
| `lib/data/repositories/subscription_repository.dart` | **28** | `collection( FirebaseConstants.storesCollection).doc(storeId).collection( FirebaseConstants.deviceRegistrationsCollection)` — mixes `FirebaseConstants` strings with raw string `'device_registrations'` instead of `FirebaseConstants.deviceRegistrationsCollection`. | Fix inconsistent constant usage — `deviceRegistrationsCollection` IS defined at `firebase_constants. dart:9`. |
| `lib/data/repositories/stats_repository. dart` | **28** | `getStatsSummary`: silently returns `initializeStats(storeId)` if doc doesn't exist, but swallows errors in `fetchTodayStats`. | Standardize "doc missing" fallback: use `SetOptions(merge: true)` on initial set or return an empty model without an extra write call. |
| `lib/core/services/database_sync_service. dart` | **339–407** | `_createStoreAndUser`: two sequential awaits: `await _storeRepository.createStore(...)` then `await _userRepository.createUser(...)` — not wrapped in `WriteBatch`. Partial failure (after store creation succeeds) would leave orphan store without owner. | Wrap both writes in a `WriteBatch` for atomic creation. |
| `lib/data/repositories/store_repository. dart` | **39** | `createStore`: uses `_firestore.batch()` which is good, but the batch commits only store + stats. If a prior check or initialization is needed, it should be inside the same transaction. | Already uses batch correctly. Minor: consider `runTransaction` instead of batch for more robust retry on contention. |

---

## ✅ Positive Findings (Already Correct)

- **`transaction_validator_service.dart`**: All writes (transaction doc + wallet doc + stats doc + daily_ stats doc) are atomically executed inside a single `runTransaction` — **Excellent**.
- **`debt_repository.dart`** `processPayment`, `addPartialDebt`, `deleteDebt`: All use `runTransaction` with proper `FieldValue.increment()` for stats. **Excellent**.
- **`wallet_repository.dart`** `creditWallet` line 199: Uses `FieldValue.increment(amount)` — **Correct**. Only `debitWallet` has the Dart math issue.
- **`debt_repository.dart`** `getDebtsCount` and `getDebtsTotalAmount`: Uses aggregate queries (`count()`, `sum()`) — **Excellent billing optimization**.
- **`transaction_repository.dart`** `getTransactionsByDateRange` and `getAllTransactions`: Both use explicit pagination with `DocumentSnapshot` cursor and `.limit(20)` — **Excellent**.
- **`employee_repository.dart`** `watchEmployees`: Uses `.limit(100)` — **Good ceiling**.
- **`FirebaseService`**: Proper singleton with offline persistence enabled (`persistenceEnabled: true`, `CACHE_SIZE_ UNLIMITED`) — **Excellent**.