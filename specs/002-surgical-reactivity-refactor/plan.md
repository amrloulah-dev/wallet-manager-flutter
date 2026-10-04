# Implementation Plan: Surgical Reactivity Architecture Refactor

## Technical Context

| Item | Value |
|------|-------|
| **Spec** | `specs/002-surgical-reactivity-refactor/spec.md` |
| **Stack** | Flutter 3.x · Provider · Cloud Firestore · Android Overlay (SAW) |
| **Constitution** | v1.0.0 — 7 principles (Zero-Latency, Anti-Jank, Zero-Waste, Safe Rollback, O(1) Lookup, Fetch Shield, ValueKey) |
| **Migration Order** | Wallets → Transactions → Statistics → Debts → Dashboard (cross-domain) |
| **Constraints** | No Riverpod migration, no overlay isolate changes, no validator/fee logic changes |

---

## Constitution Check ✅

| # | Principle | Plan Compliance |
|---|-----------|----------------|
| 1 | Zero-Latency | Every mutation method captures snapshot → mutates RAM → `notifyListeners()` → async Firestore write |
| 2 | Anti-Jank | All `context.watch<T>()` replaced with `Selector<T,R>` or scoped `Consumer<T>` |
| 3 | Zero-Waste | `StreamBuilder` in `WalletDetailsScreen` removed; UI reads from Provider RAM only |
| 4 | Safe Rollback | Every optimistic write wrapped in try-catch; rollback restores snapshot + `notifyListeners()` |
| 5 | O(1) Lookup | `Map<String, Model>` added to WalletProvider, TransactionProvider, DebtProvider |
| 6 | Fetch Shield | `_lockFetching` upgraded to 5s timer; `fetchInitialWallets` already respects it; same pattern added to Transaction/Debt |
| 7 | ValueKey | Composite `ValueKey('${id}_${mutableField}')` enforced on all mutable list items |

---

## Phase 1: Wallets Domain

### Phase 1A — WalletProvider Refactor

#### [MODIFY] [wallet_provider.dart](file:///c:/src/walletmanager/lib/providers/wallet_provider.dart)

**1. Add O(1) Indexed Map**
```dart
// New field
Map<String, WalletModel> _walletMap = {};

// New getter
Map<String, WalletModel> get walletMap => _walletMap;
```

**Sync Rule**: Every operation that modifies `_wallets` MUST also update `_walletMap`. This includes:
- `fetchInitialWallets()` — rebuild map after assigning `_wallets`
- `fetchMoreWallets()` — add new entries to map
- `createWallet()` — add to map
- `deleteWallet()` — remove from map
- `applyLocalDeduction()` — update map entry
- `updateWalletOptimistically()` — update map entry
- Overlay listener `local_deduct` handler — update map entry

Add private sync helper:
```dart
void _rebuildWalletMap() {
  _walletMap = {for (final w in _wallets) w.walletId: w};
}
```

**2. Upgrade Fetch Shield to 5-second Timer**

Current `_lockFetching` uses a 3-second `Future.delayed` in `applyLocalDeduction()` only. Upgrade:
- Rename to `_fetchShieldActive` for clarity
- Add `Timer? _fetchShieldTimer` field
- Create `_activateFetchShield()` method with 5s duration and timer cancellation
- Apply fetch shield in ALL isolate/overlay paths: `applyLocalDeduction()`, overlay `local_deduct` handler, `updateWalletOptimistically()`
- Guard `fetchInitialWallets()` and `fetchMoreWallets()` with the shield check

```dart
Timer? _fetchShieldTimer;
bool _fetchShieldActive = false;

void _activateFetchShield() {
  _fetchShieldActive = true;
  _fetchShieldTimer?.cancel();
  _fetchShieldTimer = Timer(const Duration(seconds: 5), () {
    _fetchShieldActive = false;
  });
}
```

**3. Add Snapshot Rollback to Mutation Methods**

For `createWallet()`:
```dart
// Optimistic: add to _wallets + _walletMap + notifyListeners() BEFORE Firestore write
// try: await Firestore write
// catch: remove from _wallets + _walletMap + notifyListeners() + surface error
```

For `addBalanceToWallet()`:
```dart
// Snapshot: final previousBalance = wallet.balance
// Optimistic: update balance in _wallets + _walletMap + notifyListeners()
// try: await Firestore write
// catch: revert balance to previousBalance in _wallets + _walletMap + notifyListeners()
```

For `deleteWallet()`:
```dart
// Snapshot: final removedWallet = _wallets[index]
// Optimistic: remove from _wallets + _walletMap + notifyListeners()
// try: await Firestore write
// catch: re-insert removedWallet into _wallets + _walletMap + notifyListeners()
```

For `updateWallet()`:
```dart
// Snapshot: final previousWallet = _walletMap[walletId]
// Optimistic: apply data changes to _wallets + _walletMap + notifyListeners()
// try: await Firestore write
// catch: revert to previousWallet in _wallets + _walletMap + notifyListeners()
```

---

### Phase 1B — Wallets UI Refactor

#### [MODIFY] [wallet_details_screen.dart](file:///c:/src/walletmanager/lib/presentation/screens/wallets/wallet_details_screen.dart)

**Remove StreamBuilder** (line 45): The entire `StreamBuilder<WalletModel?>` that wraps the screen body must be replaced with a `Selector<WalletProvider, WalletModel?>`:

```dart
Selector<WalletProvider, WalletModel?>(
  selector: (_, provider) => provider.walletMap[walletId],
  builder: (context, wallet, _) {
    if (wallet == null) return ErrorWidget(...);
    return _buildWalletDetails(context, wallet);
  },
)
```

The `walletId` is passed as a route argument. The screen will read the wallet from Provider RAM — zero Firestore reads.

#### [MODIFY] [wallets_list_screen.dart](file:///c:/src/walletmanager/lib/presentation/screens/wallets/wallets_list_screen.dart)

- **Replace root Consumer** with scoped Selectors:
  - `Selector<WalletProvider, List<WalletModel>>` for the list body
  - `Selector<WalletProvider, WalletStatusState>` for loading/error states
  - `Selector<WalletProvider, bool>` for `hasMore` (load-more trigger)
- **Verify composite ValueKey**: Already uses `ValueKey('${wallet.walletId}_${wallet.balance}')` on line 195 ✅

#### [MODIFY] [add_balance_screen.dart](file:///c:/src/walletmanager/lib/presentation/screens/wallets/add_balance_screen.dart)

- **Remove stale `_selectedWallet` snapshot**: Currently stores a `WalletModel?` in local state (line 28). After dropdown selection, the stored snapshot becomes stale if balance changes.
- **Refactor**: Store only `_selectedWalletId` (String). Use `Selector<WalletProvider, WalletModel?>` to fetch the live wallet by ID from `walletMap` for display in `_buildWalletInfoCard()`.

---

## Phase 2: Transactions Domain

### Phase 2A — TransactionProvider Refactor

#### [MODIFY] [transaction_provider.dart](file:///c:/src/walletmanager/lib/providers/transaction_provider.dart)

**1. Add O(1) Indexed Map**
```dart
Map<String, TransactionModel> _transactionMap = {};
Map<String, TransactionModel> get transactionMap => _transactionMap;

void _rebuildTransactionMap() {
  _transactionMap = {for (final t in _transactions) t.transactionId: t};
}
```

Apply `_rebuildTransactionMap()` after every `_transactions` mutation: `fetchInitialTransactions()`, `fetchMoreTransactions()`, `insertTransactionLocally()`, `selectTransaction()`, and any delete/update.

**2. Add Fetch Shield**
```dart
Timer? _fetchShieldTimer;
bool _fetchShieldActive = false;

void _activateFetchShield() {
  _fetchShieldActive = true;
  _fetchShieldTimer?.cancel();
  _fetchShieldTimer = Timer(const Duration(seconds: 5), () {
    _fetchShieldActive = false;
  });
}
```

Guard `fetchInitialTransactions()` with `if (_fetchShieldActive) return;`.
Activate in `insertTransactionLocally()`.

**3. Refactor `appEvents.onTransactionsChanged` Listener**

Current behavior (line 53-57): Calls `fetchInitialTransactions(forceRefresh: true)` on every event. This violates Principle 3 (Zero-Waste) because the creating method already updated local state. Refactor:
```dart
_dataChangedSubscription = appEvents.onTransactionsChanged.listen((_) {
  // Skip fetch — local state is already updated by the mutating method.
  // The fetch shield also blocks this path after overlay injections.
  debugPrint('🔥 [TransactionProvider] onTransactionsChanged — skipping fetch.');
});
```

**4. Pre-compute Derived Data**

Add pre-computed getters:
```dart
List<TransactionModel> get todayTransactions => _transactions
    .where((t) => DateHelper.isToday(t.transactionDate.toDate()))
    .toList();
```

This should be cached in a `_todayTransactions` field and updated when `_transactions` changes.

---

### Phase 2B — Transactions UI Refactor

#### [MODIFY] [today_transactions_screen.dart](file:///c:/src/walletmanager/lib/presentation/screens/transactions/today_transactions_screen.dart)

- Replace root `Consumer<TransactionProvider>` with:
  - `Selector<TransactionProvider, List<TransactionModel>>` for the list
  - `Selector<TransactionProvider, TransactionStatus>` for loading states
- Add composite `ValueKey('${tx.transactionId}_${tx.amount}_${tx.paymentStatus}')` on transaction list items

#### [MODIFY] [transaction_details_screen.dart](file:///c:/src/walletmanager/lib/presentation/screens/transactions/transaction_details_screen.dart)

- **Remove O(n) wallet lookup** (line 279-280): Replace `walletProvider.wallets.firstWhereOrNull(...)` with `walletProvider.walletMap[transaction.walletId]`
- Replace `Consumer<WalletProvider>` in `_buildWalletInfoCard` with `Selector<WalletProvider, WalletModel?>`:
  ```dart
  Selector<WalletProvider, WalletModel?>(
    selector: (_, wp) => wp.walletMap[transaction.walletId],
    builder: (context, wallet, _) { ... },
  )
  ```

#### [MODIFY] [create_transaction_screen.dart](file:///c:/src/walletmanager/lib/presentation/screens/transactions/create_transaction_screen.dart)

- **Remove `firstWhere` lookup** (line 72): Replace with `walletProvider.walletMap[_preSelectedWalletId]`
- **Remove stale wallet snapshot**: Store only `_selectedWalletId`. Use `Selector<WalletProvider, WalletModel?>` to fetch live balance for display.

---

## Phase 3: Statistics Domain

### Phase 3A — StatisticsProvider Refactor

#### [MODIFY] [statistics_provider.dart](file:///c:/src/walletmanager/lib/providers/statistics_provider.dart)

- **Pre-compute all derived data**: Ensure `dashboardSummary` and `filteredStats` are fully resolved before exposure. No computation should happen in widget `build()`.
- **Add fetch shield** (same pattern as above)
- Ensure `addTransactionOptimistically()` properly updates the pre-computed summary fields

### Phase 3B — Statistics UI Refactor

#### [MODIFY] [general_statistics_screen.dart](file:///c:/src/walletmanager/lib/presentation/screens/statistics/general_statistics_screen.dart)

- The current `Consumer<StatisticsProvider>` on line 90 wraps the entire screen. Replace with:
  - `Selector<StatisticsProvider, StatsMode>` for mode-dependent UI switching
  - `Selector<StatisticsProvider, StatsSummaryModel?>` for the statistics display
  - `Selector<StatisticsProvider, bool>` for loading state

---

## Phase 4: Debts Domain

### Phase 4A — DebtProvider Refactor

#### [MODIFY] [debt_provider.dart](file:///c:/src/walletmanager/lib/providers/debt_provider.dart)

**1. Add O(1) Indexed Map**
```dart
Map<String, DebtModel> _debtMap = {};
Map<String, DebtModel> get debtMap => _debtMap;

void _rebuildDebtMap() {
  _debtMap = {for (final d in _debts) d.debtId: d};
}
```

**2. Add Fetch Shield** (same pattern)

**3. Refactor `appEvents.onDebtsChanged` Listener** — skip fetch, same as transaction pattern

**4. Add Snapshot Rollback** to `createDebt()`, `updateDebt()`, `markDebtAsPaid()` methods

### Phase 4B — Debts UI Refactor

#### [MODIFY] [debts_list_screen.dart](file:///c:/src/walletmanager/lib/presentation/screens/debts/debts_list_screen.dart)

- Replace root Consumer with scoped Selectors
- **Fix ValueKey** (line 192): Current `ValueKey(debt.debtId)` is ID-only. Change to composite: `ValueKey('${debt.debtId}_${debt.amountDue}_${debt.debtStatus}')`

---

## Phase 5: Dashboard (Cross-Domain)

#### [MODIFY] [main_dashboard_screen.dart](file:///c:/src/walletmanager/lib/presentation/screens/home/main_dashboard_screen.dart)

**Remove 5 root-level `context.watch` calls** (lines 94-98):
```dart
// CURRENT (lines 94-98) — violates Principle 2
final authProvider = context.watch<AuthProvider>();
final statsProvider = context.watch<StatisticsProvider>();
final transactionProvider = context.watch<TransactionProvider>();
final walletProvider = context.watch<WalletProvider>();
final debtProvider = context.watch<DebtProvider>();
```

**Replace with targeted Selectors per section:**

| Dashboard Section | Selector Expression |
|---|---|
| Greeting Text | `Selector<AuthProvider, String?>` → `auth.currentUser?.name` |
| Balance Summary Card | `Selector<WalletProvider, double>` → sum of wallet balances |
| Wallets Horizontal List | `Selector<WalletProvider, List<WalletModel>>` → `wallets` |
| Today's Transactions | `Selector<TransactionProvider, List<TransactionModel>>` → `todayTransactions` |
| Statistics Summary | `Selector<StatisticsProvider, StatsSummaryModel?>` → `dashboardSummary` |
| Debts Alert | `Selector<DebtProvider, int>` → open debts count |

Each section becomes an independently scoped widget that only rebuilds when its specific data changes.

---

## File Change Summary

| Phase | File | Change Type | Principle(s) |
|-------|------|-------------|-------------|
| 1A | `wallet_provider.dart` | Add `walletMap`, fetch shield, rollback | P1, P4, P5, P6 |
| 1B | `wallet_details_screen.dart` | Remove `StreamBuilder`, add `Selector` | P2, P3 |
| 1B | `wallets_list_screen.dart` | Replace root Consumer with Selectors | P2 |
| 1B | `add_balance_screen.dart` | Remove stale snapshot, use `Selector` | P2, P5 |
| 2A | `transaction_provider.dart` | Add `transactionMap`, fetch shield, pre-compute | P1, P5, P6 |
| 2B | `today_transactions_screen.dart` | Selectors + composite ValueKey | P2, P7 |
| 2B | `transaction_details_screen.dart` | O(1) lookup via `walletMap` | P5 |
| 2B | `create_transaction_screen.dart` | Remove stale snapshot, O(1) lookup | P2, P5 |
| 3A | `statistics_provider.dart` | Pre-compute, fetch shield | P1, P6 |
| 3B | `general_statistics_screen.dart` | Selectors | P2 |
| 4A | `debt_provider.dart` | Add `debtMap`, fetch shield, rollback | P1, P4, P5, P6 |
| 4B | `debts_list_screen.dart` | Selectors + composite ValueKey | P2, P7 |
| 5 | `main_dashboard_screen.dart` | Remove 5 `context.watch`, add 6+ Selectors | P2 |

---

## Verification Plan

### Per-Phase Validation
After each phase (1A→1B, 2A→2B, etc.):
1. `flutter analyze` — zero errors, zero warnings
2. Manual smoke test — navigate to the refactored screen, verify data displays correctly
3. Verify no `context.watch<T>()` at screen root in modified files
4. Verify no `StreamBuilder` for Provider-managed data in modified files
5. Verify no `.firstWhere()` / `.firstWhereOrNull()` in `build()` methods

### Final Validation (after Phase 5)
1. Full `flutter analyze` clean pass
2. Grep audit:
   - `grep -r "context.watch" lib/presentation/screens/` → only justified usages remain (auth screens)
   - `grep -r "StreamBuilder" lib/presentation/screens/` → zero for Provider-managed data
   - `grep -r "firstWhere\|firstWhereOrNull" lib/presentation/screens/` → zero in build() methods
3. User testing on mid-range Android device — verify smooth 60fps scrolling during overlay transactions
