# Specification: Optimistic UI Refresh Refactor

## Overview

Migrate the three core features (Transactions, Wallets, Debts) and supporting providers (Statistics, Employee) to a fully compliant "Optimistic UI" architecture as defined by the project constitution (`.specify/memory/constitution.md`). The goal is to achieve real-time UI updates without expensive Firestore streams, enforce strict client-side rollback on write failures, and adopt true UUID-based document identification for idempotent sync.

## Current State (Gap Analysis)

| Area | Constitution Requires | Current State | Gap |
|------|----------------------|---------------|-----|
| Optimistic UI | Mutate RAM first, Firestore write async | ❌ All 3 providers await Firestore before UI update | **Critical** |
| Safe Rollback | Capture snapshot → revert on failure → show error | ❌ No rollback in any provider | **Critical** |
| Stream Eradication | No Firestore streams for provider-managed data | ⚠️ `StatisticsProvider` and `EmployeeProvider` have active `StreamSubscriptions` causing excessive reads | **High** |
| Fetch Shield | Block auto-fetch ~5s after isolate injection | ⚠️ Present in TX/Wallet, missing in Debt | **Medium** |
| Client-Side UUIDs | True UUID via `uuid` package | ⚠️ Uses `doc().id` (Firestore auto-ID, not true UUID) | **Medium** |
| WriteBatch Atomicity | Atomic multi-doc mutations | ⚠️ Not consistently used for transaction+wallet balance updates | **High** |
| Derived Summaries | Dynamic computation from local state | ⚠️ Relies on server-side `stats/summary` docs only | **High** |

## Functional Requirements

### FR-1: Stream Eradication (Phase 0)
- **FR-1.1:** Remove `StreamSubscription` from `StatisticsProvider`. Replace with a one-shot `Future`-based fetch on initialization. After initial load, stats are updated locally (derived state) when transactions or debts mutate.
- **FR-1.2:** Remove `StreamSubscription` from `EmployeeProvider`. Replace with a one-shot `Future`-based fetch.
- **FR-1.3:** Verify that no Firestore `.snapshots()` streams remain in any provider managing Transactions, Wallets, Debts, Statistics, or Employees.

### FR-2: Optimistic Transaction Creation (Phase 1)
- **FR-2.1:** Generate a true UUID (via `uuid` package) client-side before any Firestore write.
- **FR-2.2:** Insert the new transaction at position 0 of the local `_transactions` list and update `_transactionMap` immediately. Call `safeNotify()` — UI updates with zero latency.
- **FR-2.3:** Update the related wallet's `currentBalance` in `WalletProvider` locally and immediately.
- **FR-2.4:** Execute a Firestore `WriteBatch` containing BOTH the transaction document `.set()` AND the wallet balance update atomically in the background.
- **FR-2.5:** Dashboard summaries (Total Sent, Total Received, Total Commission) must be computed dynamically from the local `_transactions` list via getters.
- **FR-2.6:** On initial app load, fetch stats from the Firestore `stats/summary` document for fast startup. After initial load, compute summaries locally. Keep `stats/summary` docs in sync by including stats updates in the `WriteBatch`.

### FR-3: Optimistic Wallet CRUD (Phase 2)
- **FR-3.1:** Generate a true UUID for new wallets client-side.
- **FR-3.2:** Add new wallet to `_wallets` list and `_walletMap` immediately, call `safeNotify()`.
- **FR-3.3:** Await Firestore `.set()` in background.
- **FR-3.4:** "Total Active Wallets" summary updates dynamically from local list length/status.
- **FR-3.5:** When a transaction is created (Phase 1), the corresponding wallet's balance in `_wallets`/`_walletMap` must update immediately without requiring a Firestore re-fetch.

### FR-4: Optimistic Debt CRUD (Phase 3)
- **FR-4.1:** Generate a true UUID for new debts client-side.
- **FR-4.2:** Add new debt to `_debts` list and `_debtMap` immediately, call `safeNotify()`.
- **FR-4.3:** Await Firestore `.set()` in background.
- **FR-4.4:** Settlement (تسديد): When marking a debt as paid, update local model status to `Paid` immediately. UI must instantly move the debt card to the "Paid" tab. Then execute Firestore update in background.
- **FR-4.5:** "Open Debts" and "Settled Debts" summary cards derive counts and totals dynamically from local `_debts` list.
- **FR-4.6:** Add fetch shield (~5s) to `DebtProvider` consistent with Transaction/Wallet providers.

### FR-5: Strict Rollback Mechanism (All Phases)
- **FR-5.1:** Before every optimistic mutation, capture an **isolated, immutable snapshot** of the previous state. In Dart, this means using `_transactions.toList()` for lists, `Map.of(_transactionMap)` for maps, and deep-copying mutable model fields if necessary. A simple variable assignment creates a reference, NOT a copy — this must be explicitly avoided.
- **FR-5.2:** Wrap every Firestore network call in `try/catch`.
- **FR-5.3:** On Firestore write failure: revert the local lists, maps, and balances to the captured snapshot, call `safeNotify()`, and route the error through `AppErrorHandler` (which handles error routing to UI toasts/snackbars).
- **FR-5.4:** The rollback must be atomic — if a `WriteBatch` fails, ALL local mutations from that batch must revert.

### FR-6: Immutable Ledger & Timestamps
- **FR-6.1:** Transactions cannot be edited or deleted (enforce at provider level).
- **FR-6.2:** Use local `DateTime.now()` for immediate UI display.
- **FR-6.3:** Save to Firestore using `FieldValue.serverTimestamp()` for authoritative server time.

### FR-7: Pull-to-Refresh Smart Merge
- **FR-7.1:** During a pull-to-refresh fetch, providers must NOT blindly clear and replace local lists. They must perform an **Upsert** (Update/Insert) by matching incoming Firestore document UUIDs against the local list.
- **FR-7.2:** Optimistic local items that are pending Firestore upload must NOT be duplicated, overwritten with older server data, or wiped out during refresh.
- **FR-7.3:** This upsert pattern must be implemented consistently across `TransactionProvider`, `WalletProvider`, and `DebtProvider`.

## Non-Functional Requirements

- **NFR-1: Zero UI Latency** — All create/update operations must reflect in the UI before the Firestore round-trip completes.
- **NFR-2: Offline Resilience** — Firestore persistence is already enabled (`persistenceEnabled: true`). Optimistic mutations should work seamlessly offline with Firestore SDK queuing writes.
- **NFR-3: Backward Compatibility** — Pull-to-refresh (already implemented on 5 screens) must continue to work via smart upsert merge, serving as the mechanism to re-sync local state with Firestore truth.
- **NFR-4: Constitution Compliance** — All changes must adhere to the 7 principles in `.specify/memory/constitution.md`.
- **NFR-5: Existing Test Coverage** — Existing tests must not break. New tests must be written for all rollback and optimistic update paths.

## Acceptance Criteria

- [ ] No `StreamSubscription` to Firestore remains in `StatisticsProvider` or `EmployeeProvider`
- [ ] Creating a transaction updates the UI instantly (before Firestore write completes)
- [ ] Creating a transaction atomically updates the wallet balance via `WriteBatch`
- [ ] Dashboard summaries recompute dynamically from local state after initial stats load
- [ ] Creating a wallet updates the UI instantly
- [ ] Creating/settling a debt updates the UI instantly; settled debts move to "Paid" tab without delay
- [ ] `DebtProvider` has a fetch shield consistent with other providers
- [ ] All providers use true UUIDs (from `uuid` package) for document ID generation
- [ ] Simulated Firestore write failure triggers rollback: local state reverts and `AppErrorHandler` fires
- [ ] Rollback snapshots are isolated copies (`.toList()`, `Map.of()`) — not references
- [ ] Pull-to-refresh performs UUID-based upsert merge, preserving optimistic pending items
- [ ] All existing pull-to-refresh flows continue to function correctly
- [ ] All existing tests pass; new unit tests cover optimistic paths and rollback scenarios
- [ ] `FieldValue.serverTimestamp()` is used for Firestore writes; local `DateTime.now()` is used for UI display

## Out of Scope

- **Editing/deleting transactions** — immutable ledger by design
- **New UI screens or navigation changes** — this is a backend/state-management refactor
- **Overlay/isolate changes** — the existing `insertTransactionLocally()` and overlay flow remain untouched
- **SystemConfigProvider streams** — not part of the core feature triad
- **New localization strings** — unless error messages require new keys
- **Firestore security rules changes** — rules are unaffected by this client-side refactor
