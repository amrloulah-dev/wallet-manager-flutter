# Specification: State Management & UI Reactivity Refactoring

## 1. Summary

The application currently exhibits inconsistent state management consumption patterns across its five core screens (Dashboard, Wallets, Transactions, Debts, Statistics). Broad `context.watch` calls at root widget levels trigger expensive full-tree rebuilds whenever any Provider field changes, causing visible frame drops on mid-range devices. Additionally, certain detail screens maintain redundant direct Firestore stream listeners that duplicate data already managed by Providers, generating unnecessary read costs and introducing race conditions where stale server data overwrites fresh local state. Finally, Providers managing collections rely on linear-scan list lookups to resolve relational data, degrading performance as collection sizes grow.

This refactoring project transitions the application from a "Pull & Watch" architecture to a "Surgical Reactivity" model. The change eliminates wasteful widget rebuilds, removes duplicate Firestore connections, and enforces constant-time data access patterns—delivering a smooth, zero-latency user experience and reduced operational costs.

## Clarifications

### Session 2026-04-05
- Q: Should screens be refactored incrementally (screen-by-screen), all-at-once, or layer-first? → A: Domain-by-Domain (Layer-first per feature). Tackle one feature domain at a time (1. Wallets, 2. Transactions, 3. Statistics, 4. Debts). For each domain, FIRST refactor the Provider (add O(1) maps, optimistic mutations, rollback logic), SECOND refactor the UI screens to use Selector and consume the new Provider methods. Complete and stabilize each domain before moving to the next.

## 2. Actors & Target Audience

- **Store Owners (Primary Users)**: Benefit from a jank-free, instantly responsive UI when managing wallets, viewing transactions, recording debts, and reviewing daily statistics—even on budget Android devices.
- **Background System (SMS Overlay)**: Benefits from predictable state propagation paths that guarantee its transactions appear in the main UI without triggering redundant Firestore reads.
- **Project Maintainers**: Benefit from a consistent, auditable state management pattern that simplifies future feature development and reduces the surface area for reactivity bugs.

## 3. User Scenarios & Testing

### Scenario 1: Dashboard loads without full-tree rebuilds
- **Given** the user opens the application and lands on the Dashboard,
- **When** a single data point changes (e.g., one wallet's balance updates via the overlay),
- **Then** only the specific dashboard component displaying that wallet's balance rebuilds; the Quick Actions bar, Alerts section, and other wallet summaries remain untouched.

### Scenario 2: Wallet list scrolling remains smooth during background updates
- **Given** the user is scrolling through the Wallets List screen,
- **When** a background overlay transaction completes and updates a wallet's balance,
- **Then** only the affected wallet card re-renders (via its composite ValueKey change); the scroll position is preserved, no frame drops occur, and unaffected wallet cards do not rebuild.

### Scenario 3: Wallet details load from Provider state, not Firestore
- **Given** the user taps on a wallet card to view its details,
- **When** the Wallet Details screen opens,
- **Then** the screen displays data from the Provider's in-memory state immediately (zero loading time), not from a separate Firestore stream. No redundant Firestore read is triggered.

### Scenario 4: Transaction creation reflects instantly across all visible screens
- **Given** the user creates a new transaction from either the manual entry screen or the SMS overlay,
- **When** the transaction is saved,
- **Then** the wallet balance, transaction list, daily statistics, and any affected debt records update in the UI instantly (optimistic update from RAM), with the Firestore write occurring asynchronously in the background. If the write fails, the UI reverts to the pre-transaction state and shows an error notification.

### Scenario 5: Debt lookup by wallet resolves instantly
- **Given** the user opens a screen that displays debts associated with a specific wallet,
- **When** the screen queries the debt Provider for debts by wallet ID,
- **Then** the lookup completes in constant time using an indexed map, not a linear scan of all debts.

### Scenario 6: Statistics screen updates surgically
- **Given** the user is viewing the Statistics screen with aggregated daily totals,
- **When** a new transaction is recorded,
- **Then** only the specific statistic value that changed (e.g., today's total sent) rebuilds; charts for other time periods and unaffected metrics remain untouched.

### Scenario 7: Failed background write triggers safe rollback
- **Given** the user submits a transaction and the UI has optimistically updated,
- **When** the background Firestore write fails (e.g., network error, validation rejection),
- **Then** the Provider reverts the wallet balance and transaction list to their pre-mutation snapshots, calls `notifyListeners()` to update the UI with the reverted state, and surfaces an error to the user via an appropriate notification mechanism (dialog or toast).

### Scenario 8: App lifecycle resync does not overwrite fresh state
- **Given** the user switches away from the app and returns within 5 seconds of a background transaction,
- **When** the app lifecycle triggers a resync,
- **Then** the fetch shield blocks the automatic Firestore fetch from overwriting the fresh local state. After the cooldown period expires, subsequent resyncs proceed normally.

## 4. Functional Requirements

- **FR1: Eliminate Root-Level context.watch** — Every screen (`MainDashboardScreen`, `WalletsListScreen`, `TodayTransactionsScreen`, `DebtsListScreen`, and Statistics screens) MUST replace blanket `context.watch<T>()` calls at the root of `build()` methods with targeted `Selector<T, R>` or tightly scoped `Consumer<T>` widgets that rebuild only the specific UI components dependent on the changed data.

- **FR2: Remove Redundant Firestore Streams** — All `StreamBuilder` widgets listening to Firestore document streams for data that is already managed by a Provider (e.g., `WalletDetailsScreen` wallet stream) MUST be removed. The affected screens MUST instead observe the corresponding Provider state via `Selector` or `Consumer`.

- **FR3: Indexed Map Lookups in Providers** — All Providers managing collections (`WalletProvider`, `TransactionProvider`, `DebtProvider`) MUST maintain an internal `Map<String, Model>` indexed by the model's unique identifier. The Map and any companion List MUST be kept in sync during add, update, and remove operations. UI code MUST use the map for lookups instead of linear scans.

- **FR4: Pre-computed Derived Data** — Widget `build()` methods MUST NOT perform computation, filtering, or sorting on Provider data. All derived data (e.g., filtered transaction lists, grouped statistics, sorted wallet lists) MUST be pre-computed in the Provider and exposed as ready-to-consume properties.

- **FR5: Optimistic Mutation with Snapshot Rollback** — Every state-changing Provider method MUST capture a snapshot of the affected state before mutation, apply the mutation to RAM and call `notifyListeners()` immediately, execute the Firestore operation asynchronously, and revert to the snapshot with a second `notifyListeners()` call if the operation fails. Errors MUST be surfaced to the user and logged.

- **FR6: Composite ValueKey on Mutable Lists** — All list items displaying mutable financial data (wallet cards, transaction rows, debt cards) MUST use a composite `ValueKey` that includes both the model ID and all mutable display fields (e.g., `ValueKey('${wallet.id}_${wallet.balance}')`). Index-based keys are prohibited for mutable data lists.

- **FR7: Fetch Shield Enforcement** — Upon receiving a state update from the background isolate, the Provider MUST set a fetch shield flag that prevents automatic Firestore fetches from overwriting fresh local state for a defined cooldown period (recommended: 5 seconds).

## 5. Success Criteria

- **SC1**: No screen in the application uses `context.watch<T>()` at the root of its `build()` method. Every Provider subscription uses `Selector` or a tightly scoped `Consumer`.
- **SC2**: Zero `StreamBuilder` widgets exist in the codebase that listen to Firestore documents for Provider-managed data.
- **SC3**: All collection-managing Providers expose a `Map<String, Model>` for constant-time lookups, and no UI `build()` method performs `.firstWhere()`, `.firstWhereOrNull()`, or `.where()` on Provider-managed collections.
- **SC4**: A user-initiated transaction (manual or overlay) reflects in all visible UI components within 100 milliseconds of the action, with the Firestore write completing asynchronously afterward.
- **SC5**: When a Firestore write fails after an optimistic update, the UI reverts to the correct pre-mutation state within 500 milliseconds and the user receives an error notification.
- **SC6**: Application frame rate maintains 60fps during list scrolling on a mid-range Android device while background transactions are being processed.
- **SC7**: Firestore read operations decrease by at least 50% compared to the current baseline after removing redundant streams and enforcing Provider-only data access.

## 6. Key Entities

- **WalletProvider**: Manages wallet collection state, exposes `walletMap` for O(1) lookups, handles optimistic balance mutations with rollback.
- **TransactionProvider**: Manages transaction collection state, exposes `transactionMap` for O(1) lookups, pre-computes daily/filtered views.
- **DebtProvider**: Manages debt collection state, exposes `debtMap` for O(1) lookups, pre-computes wallet-grouped debt aggregates.
- **StatisticsProvider**: Manages aggregated financial statistics, pre-computes all chart/summary data to eliminate computation in `build()`.
- **Selector\<T, R\>**: Flutter Provider widget used to subscribe to a specific sub-value of a Provider, preventing unnecessary rebuilds.
- **ValueKey**: Flutter key type used on list items to force widget reconciliation when mutable data fields change.

## 7. Scope & Boundaries

### In Scope
- Refactoring all five core screens (Dashboard, Wallets List, Transactions, Debts List, Statistics) to use Selector-based reactivity.
- Adding indexed `Map<String, Model>` to `WalletProvider`, `TransactionProvider`, and `DebtProvider`.
- Removing `StreamBuilder` from `WalletDetailsScreen` and any other detail screens with redundant Firestore listeners.
- Ensuring all optimistic mutations have snapshot-based rollback logic.
- Auditing and enforcing composite `ValueKey` usage on all mutable list items.

### Migration Strategy
Work proceeds domain-by-domain in this fixed order: **Wallets → Transactions → Statistics → Debts**. For each domain, the implementation strictly follows a two-phase approach:
1. **Phase A — Provider Refactor**: Add `Map<String, Model>` index, implement/verify optimistic mutation with snapshot rollback, pre-compute derived data.
2. **Phase B — UI Refactor**: Replace root `context.watch` / broad `Consumer` with `Selector`, enforce composite `ValueKey` on list items, remove any redundant `StreamBuilder`.

A domain is considered complete only after both phases pass validation. The next domain does not begin until the current one is stable.

### Out of Scope
- Modifying the SMS overlay isolate's internal logic or Firestore write path.
- Changing the `TransactionValidatorService` validation rules or `FeeCalculator` logic.
- Adding new Provider classes or refactoring the Provider architecture itself (e.g., switching to Riverpod).
- Modifying Firestore security rules or database schema.
- Performance profiling tooling setup (assumed to be done manually by the developer).

## 8. Assumptions & Dependencies

- **Assumption**: The existing Provider instances (`WalletProvider`, `TransactionProvider`, `DebtProvider`, `StatisticsProvider`) are correctly registered as singletons at the app root via `MultiProvider` or equivalent.
- **Assumption**: The existing `IsolateNameServer`-based communication channel between the overlay isolate and the main app is functional and will continue to be the mechanism for background state updates.
- **Assumption**: The `TransactionValidatorService` already handles atomic Firestore writes and will not need modification as part of this refactoring.
- **Dependency**: The Project Constitution v1.0.0 (7 principles) has been ratified and all changes in this project MUST comply with its rules.
- **Dependency**: Spec 001 (Unified Validation Engine) is assumed to be implemented or in-progress, providing the centralized validation infrastructure that this refactoring builds upon.
