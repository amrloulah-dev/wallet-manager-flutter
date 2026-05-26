# Bug Report — Wallet Manager
**Date:** 2026-05-26  
**Investigator:** Antigravity AI  
**Method:** Static code analysis (no fixes applied)  
**Scope:** 4 functional bugs + 1 UI bug reported during manual testing

---

## Summary Table

| ID | Severity | Title | Primary File | Status |
|----|----------|-------|-------------|--------|
| BUG-01 | 🔴 Critical | Wallet Creation Always Fails | `wallet_repository.dart:45` | Open |
| BUG-02 | 🔴 Critical | Employee Fetch/Add Fails (Permission Denied) | `firestore.rules:73` | Open |
| BUG-03 | 🟠 High | Daily Summary Always Shows Zeros | `transaction_provider.dart:36` | Open |
| BUG-04 | 🟠 High | Stats Date Filter Has No Effect | `statistics_provider.dart:219` | Open |
| BUG-05 | 🟡 Medium | UI Overflow on Balance Card (7.4px) | `general_statistics_screen.dart:444` | Open |

---

## BUG-01 — Wallet Creation Always Fails (`wallet_error_create_failed`)

**Severity:** 🔴 Critical  
**Reported Error:** `wallet_error_create_failed` snackbar shown immediately after tapping "Create Wallet"

### Affected Files
- `lib/data/repositories/wallet_repository.dart` — Lines 38–60
- `lib/providers/wallet_provider.dart` — Lines 282–336

### Root Cause

`WalletRepository.createWallet()` calls `await _statsRepository.updateStatsOnWalletChange(...)` **inside** a `_firestore.runTransaction()` callback. Firestore's transaction mechanism does not permit awaiting arbitrary async operations that perform their own Firestore reads/writes outside the transaction object. The SDK detects the violation and aborts the transaction, which the outer `catch` block silently swallows and re-throws as the generic `ServerException('wallet_error_create_failed')`.

### Code Location

```dart
// lib/data/repositories/wallet_repository.dart — Lines 38–60
Future<void> createWallet(WalletModel wallet) async {
  try {
    await _firestore.runTransaction((transaction) async {
      final walletRef = _walletsCollection.doc(wallet.walletId);
      transaction.set(walletRef, wallet.toFirestore());

      await _statsRepository.updateStatsOnWalletChange( // ← BUG: async call inside transaction
        wallet.storeId,
        countChange: 1,
        activeCountChange: wallet.isActive ? 1 : 0,
        balanceChange: wallet.balance,
        firestoreTransaction: transaction,
      );
    });
    _cacheManager.clearWhere((key) => key.startsWith('wallets_page_'));
  } catch (e, stack) {
    AppErrorHandler.logSilentError(e.toString(), 'WalletRepository.createWallet',
        stackTrace: stack);
    throw ServerException('wallet_error_create_failed'); // ← always reached
  }
}
```

### Provider Call Chain

```dart
// lib/providers/wallet_provider.dart — Lines 319
await _walletRepository.createWallet(newWallet); // → throws → caught at line 326
```

### Fix Direction

Move the `_statsRepository.updateStatsOnWalletChange(...)` call so that it uses **only the `transaction` object** for its reads/writes without making any additional `await` calls to external services inside the transaction callback, or restructure it as a batched write outside the transaction.

---

## BUG-02 — Employee Fetch/Add Fails (`employee_error_fetch_failed`)

**Severity:** 🔴 Critical  
**Reported Error:** Employee list fails to load; adding an employee fails with permission-denied

### Affected Files
- `lib/data/repositories/employee_repository.dart` — Lines 23–48 (`getEmployeesByStoreId`)
- `lib/data/repositories/employee_repository.dart` — Lines 81–172 (`addEmployee`)
- `firestore.rules` — Lines 63–78 (`/users/{userId}`)

### Root Cause

The Firestore security rule for `/users/{userId}` grants `allow read` **conditioned on `resource.data.storeId`**:

```js
// firestore.rules — Lines 73–74
allow read, delete: if isAuthenticated() && isStoreOwner(resource.data.storeId);
allow create, update: if isAuthenticated() && isStoreOwner(request.resource.data.storeId);
```

In Firestore Security Rules, `allow read` covers both `get` (single document) and `list` (collection query). However, for a **list** operation, `resource.data` is **not available** — Firestore cannot evaluate per-document fields during query-level access checks. Because `isStoreOwner(resource.data.storeId)` references `resource.data`, the rule evaluation fails for any list query, resulting in a `permission-denied` error even for the store owner.

`getEmployeesByStoreId` performs exactly this kind of list query:

```dart
// employee_repository.dart — Lines 38–41
final snapshot = await query
    .orderBy(FirebaseConstants.createdAt, descending: true)
    .limit(limit)
    .get(); // ← list query → permission-denied due to rules bug
```

Similarly, `addEmployee` writes a user doc with `isStoreOwner(request.resource.data.storeId)`, which **should** work for `create` — but the `list` needed to verify capacity (`storeSnap`) relies on a `transaction.get()` of the store doc, which may also be denied depending on the calling context.

### Fix Direction

Split the `allow read` rule into separate `allow get` and `allow list` rules. The `allow list` rule should be conditioned on a **request-level** field (e.g., `request.query.filters` or a verified auth claim) rather than `resource.data`, since document data is unavailable during list evaluation.

```js
// Suggested direction (not a complete fix):
allow get: if isAuthenticated() && (request.auth.uid == userId || isStoreOwner(resource.data.storeId));
allow list: if isAuthenticated() && isStoreOwner(request.auth.uid); // use uid as storeId
```

---

## BUG-03 — Daily Summary Always Shows Zeros

**Severity:** 🟠 High  
**Symptom:** The summary card on `TodayTransactionsScreen` always displays 0 for sent amount, received amount, and transaction count.

### Affected Files
- `lib/providers/transaction_provider.dart` — Line 36, Lines 84–90
- `lib/presentation/screens/transactions/today_transactions_screen.dart` — Lines 107–119

### Root Cause

`TransactionProvider` declares `_summary` as a final empty map that is **never written to**:

```dart
// transaction_provider.dart — Line 36
final Map<String, dynamic> _summary = {}; // ← initialized empty, never populated
```

The `_recomputeTodayTransactions()` method filters `_transactions` into `_todayTransactions` correctly, but performs **no aggregation** and never updates `_summary`:

```dart
// transaction_provider.dart — Lines 84–90
void _recomputeTodayTransactions() {
  final now = TimeService.now();
  _todayTransactions = _transactions.where((tx) {
    return DateHelper.isSameDay(tx.transactionDate ?? now, now);
  }).toList();
  // _summary is NOT computed here — missing aggregation logic
}
```

The screen reads from this always-empty map, falling back to `0` / `0.0` for every key:

```dart
// today_transactions_screen.dart — Lines 107–119
Selector<TransactionProvider, Map<String, dynamic>>(
  selector: (context, provider) => provider.summary,
  builder: (context, summary, child) {
    return TransactionSummaryCard(
      totalTransactions: summary['totalTransactions'] ?? 0,       // always 0
      sendCount: summary['sendCount'] ?? 0,                       // always 0
      receiveCount: summary['receiveCount'] ?? 0,                 // always 0
      totalSendAmount: summary['totalSendAmount'] ?? 0.0,         // always 0.0
      totalReceiveAmount: summary['totalReceiveAmount'] ?? 0.0,   // always 0.0
      totalCommission: summary['totalCommission'] ?? 0.0,         // always 0.0
    );
  },
),
```

### Fix Direction

Add aggregation logic inside `_recomputeTodayTransactions()` (or a separate `_recomputeSummary()` method) that iterates `_todayTransactions` and writes the computed totals into `_summary`. The map keys must exactly match those consumed by the screen (`totalSendAmount`, `totalReceiveAmount`, etc.).

---

## BUG-04 — Stats Date Filter Has No Effect

**Severity:** 🟠 High  
**Symptom:** Applying a custom date range on `GeneralStatisticsScreen` either shows the same global stats or shows an empty state — the filter is never applied.

### Affected Files
- `lib/presentation/screens/statistics/general_statistics_screen.dart` — Lines 52–74 (`_applyFilter`)
- `lib/providers/statistics_provider.dart` — Lines 187–230 (`fetchFilteredStats`)

### Root Cause

`fetchFilteredStats()` **never queries Firestore** with the requested date range. It only examines two in-memory conditions:

1. If the range is exactly **today** → returns a subset of `_dashboardSummary`
2. For **any other range** → unconditionally returns the global `_dashboardSummary.toMap()` (all-time stats)

```dart
// statistics_provider.dart — Lines 187–230
Future<void> fetchFilteredStats(DateTimeRange dateRange) async {
  // ...
  try {
    if (_storeId == null) throw Exception("Store ID not found");

    final isToday = DateHelper.isToday(dateRange.start) &&
        DateHelper.isToday(dateRange.end);

    if (isToday && _dashboardSummary != null) {
      // Uses today's in-memory snapshot
      _filteredStats = { /* today's data from dashboardSummary */ };
    } else if (_dashboardSummary != null) {
      // ← BUG: ignores dateRange entirely, returns all-time global stats
      _filteredStats = _dashboardSummary?.toMap();
    }
    // No _statsRepository call with dateRange anywhere in this method
  } catch (e, stack) { ... }
}
```

The "Apply Filter" button in the screen calls this method correctly, but the method never acts on the date range for anything other than today:

```dart
// general_statistics_screen.dart — Lines 71–72
provider.fetchFilteredStats(
    DateTimeRange(start: localStartDate, end: localEndDate)); // range is ignored
```

### Fix Direction

`fetchFilteredStats` must call the repository with the provided `dateRange`. The `StatsRepository` (or `TransactionRepository`) needs a method that aggregates transaction/stats data for an arbitrary date range and returns the result. The provider should then build `_filteredStats` from that response.

---

## BUG-05 — UI Overflow on "الرصيد" (Balance) Card (+7.4 pixels)

**Severity:** 🟡 Medium  
**Symptom:** Flutter renders a red overflow indicator on the Balance stat card in `GeneralStatisticsScreen`: *"Right overflowed by 7.4 pixels"*

### Affected Files
- `lib/presentation/screens/statistics/general_statistics_screen.dart` — Lines 426–467 (`StatItemWidget`)

### Root Cause

`StatItemWidget` places two unconstrained children in a `Row` with `MainAxisAlignment.spaceBetween`. Neither child is wrapped in `Flexible` or `Expanded`, so Flutter cannot shrink them when their combined intrinsic width exceeds the available space:

```dart
// general_statistics_screen.dart — Lines 440–467
@override
Widget build(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(                        // ← NO Flexible/Expanded
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.bodyLarge),  // Arabic label can be wide
            if (subtitle != null) ...[
              Text(subtitle!, style: AppTextStyles.bodySmall...),
            ],
          ],
        ),
        Text(                          // ← NO Flexible/Expanded
          value,
          style: AppTextStyles.h3...,  // Large formatted number (e.g., "12,345.67 ج.م")
        ),
      ],
    ),
  );
}
```

The overflow is most visible on the Balance card because `l10n.totalWalletBalance` is a long Arabic string, and `NumberFormatter.formatAmount(totalBalance)` outputs a wide currency string simultaneously.

### Fix Direction

Wrap the label `Column` in a `Flexible` widget (with `fit: FlexFit.loose`) so it can shrink when the value text is wide. Alternatively, set `overflow: TextOverflow.ellipsis` on the label `Text` widget as a secondary safeguard.

```dart
// Suggested direction:
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Flexible(           // ← add this
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.bodyLarge, overflow: TextOverflow.ellipsis),
          ...
        ],
      ),
    ),
    const SizedBox(width: 8),
    Text(value, style: AppTextStyles.h3...),
  ],
),
```

---

## Appendix — Files Investigated

| File | Lines | Role |
|------|-------|------|
| `lib/data/repositories/wallet_repository.dart` | 411 | Wallet CRUD & Firestore transactions |
| `lib/providers/wallet_provider.dart` | 522 | Wallet state management |
| `lib/data/repositories/employee_repository.dart` | 445 | Employee CRUD |
| `lib/providers/transaction_provider.dart` | 443 | Transaction state & daily summary |
| `lib/providers/statistics_provider.dart` | 326 | Stats state & date-range filtering |
| `lib/presentation/screens/statistics/general_statistics_screen.dart` | 469 | Stats UI + date filter + Balance card |
| `lib/presentation/screens/transactions/today_transactions_screen.dart` | 244 | Daily summary display |
| `firestore.rules` | 155 | Firestore security rules |
