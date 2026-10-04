<!--
=== SYNC IMPACT REPORT ===
Version change: N/A → 1.0.0
Modified principles: N/A (initial creation)
Added sections:
  - Preamble
  - Principle 1: Optimistic UI & Local State Mutation (Zero-Latency Rule)
  - Principle 2: Surgical Reactivity (Anti-Jank Rule)
  - Principle 3: Zero-Waste Firestore Reads
  - Principle 4: Safe Rollbacks on Failure
  - Principle 5: O(1) Data Lookups (Performance Rule)
  - Principle 6: Isolate & Background Sync Integrity
  - Principle 7: ValueKey Invalidation
  - Governance & Amendment Process
Removed sections: N/A
Templates requiring updates:
  - .specify/templates/plan-template.md ⚠ pending (does not exist yet)
  - .specify/templates/spec-template.md ⚠ pending (does not exist yet)
  - .specify/templates/tasks-template.md ⚠ pending (does not exist yet)
Follow-up TODOs: None
=== END SYNC IMPACT REPORT ===
-->

# Wallet Manager — Project Constitution

**Project Name:** Wallet Manager
**Constitution Version:** 1.0.0
**Ratification Date:** 2026-04-05
**Last Amended Date:** 2026-04-05

---

## Preamble

This constitution defines the non-negotiable architectural commandments for
the Wallet Manager Flutter application. Every contributor—human or AI agent—
MUST treat these principles as hard constraints, not guidelines. Any code
that violates a principle MUST NOT be merged. The overarching goal is to
deliver a **high-performance, zero-latency** user experience while
maintaining data integrity with Firebase Firestore as the backend.

The application manages financial wallets, transactions, debts, and employee
access for store owners. Because it handles real money and runs critical
background automations (SMS overlay), correctness and speed are
equally paramount.

---

## Principle 1: Optimistic UI & Local State Mutation (Zero-Latency Rule)

All user actions and overlay transactions MUST reflect instantly in the UI.

- Every state-changing user action MUST first mutate the Provider's in-RAM
  state, then call `notifyListeners()` immediately.
- The corresponding Firestore write/update MUST execute asynchronously in
  the background, **after** the UI has already updated.
- The user MUST never see a loading spinner or skeleton for an action they
  just performed. The perceived latency MUST be zero.
- This applies to all mutation paths: manual transaction creation, overlay
  transaction submission, wallet balance updates, debt status changes, and
  any CRUD operation surfaced in the UI.

**Rationale:** Users interact with financial tools under time pressure.
Any perceptible delay erodes trust and slows business operations.

---

## Principle 2: Surgical Reactivity (Anti-Jank Rule)

ABSOLUTELY NO blanket `context.watch<T>()` at the root of a screen or
large widget tree.

- All Provider subscriptions MUST use `Selector<T, R>` to listen to
  specific values, or tightly scoped `Consumer<T>` widgets.
- Only the exact pixels that represent the changed data MUST rebuild.
  Parent widgets, sibling widgets, and unrelated subtrees MUST NOT
  rebuild when a single data field changes.
- Any `context.watch<T>()` call MUST be justified by proving that the
  entire subtree beneath it genuinely depends on the full `T` object.
  If fewer than 80% of child widgets use the watched value, the call
  MUST be replaced with a `Selector` or `Consumer`.
- Widget `build()` methods MUST NOT perform computation, filtering,
  or sorting. All derived data MUST be pre-computed in the Provider.

**Rationale:** Unnecessary widget rebuilds cause frame drops (jank) on
mid-range Android devices that our store-owner users typically operate.

---

## Principle 3: Zero-Waste Firestore Reads

Never use `StreamBuilder` to listen to Firestore documents if that data
is already managed by a Provider.

- The app MUST rely on Provider RAM as the single source of truth for
  the UI during normal operation.
- Firestore `.get()` reads are ONLY permitted during:
  1. **Initial app load** (cold start hydration).
  2. **Explicit pull-to-refresh** (user-initiated).
  3. **Lifecycle resyncs** (app resumed from background via
     `AppLifecycleState.resumed`).
- Any existing `StreamBuilder` that duplicates Provider-managed data
  MUST be removed and replaced with a `Consumer` or `Selector`.
- Firestore `.snapshots()` streams are ONLY permitted for data that is
  NOT represented in any Provider (e.g., one-off admin notifications).

**Rationale:** Each Firestore read costs money and adds network latency.
Redundant reads also create race conditions where stale server data
overwrites fresh local state.

---

## Principle 4: Safe Rollbacks on Failure

Whenever an optimistic local mutation is performed, the corresponding
Firebase operation MUST be wrapped in a `try-catch` block with explicit
rollback logic.

- Before mutating local state, the Provider MUST capture a snapshot of
  the previous value (e.g., `final previousBalance = wallet.balance`).
- If the Firebase write fails, the Provider MUST:
  1. Revert the local RAM state to the captured snapshot.
  2. Call `notifyListeners()` to update the UI with the reverted state.
  3. Surface the error to the user via `AwesomeDialog` or `bot_toast`
     as appropriate for the context.
- The rollback MUST be atomic: if multiple fields were mutated
  optimistically, ALL of them MUST revert together.
- Rollback logic MUST NOT silently swallow errors. Every caught
  exception MUST be logged via `debugPrint` with the operation context.

**Rationale:** Optimistic UI without rollback creates phantom state where
the user sees a balance that does not match Firestore, leading to
incorrect financial decisions.

---

## Principle 5: O(1) Data Lookups (Performance Rule)

Stop using O(n) linear scans like `list.firstWhereOrNull()` inside UI
`build()` methods.

- Providers managing lists (e.g., `WalletProvider`, `TransactionProvider`)
  MUST maintain an indexed `Map<String, Model>` (dictionary) internally,
  keyed by the model's unique identifier (e.g., `walletId`).
- The UI MUST fetch relational data via `provider.walletMap[id]` instead
  of searching through a list.
- The Provider MUST keep the `Map` and any companion `List` in sync at
  all times. When a model is added, updated, or removed, both the `Map`
  and the `List` MUST be updated in the same operation.
- Any `build()` method that performs a `.where()`, `.firstWhere()`, or
  `.firstWhereOrNull()` on a Provider-managed collection MUST be
  refactored to use the indexed map.

**Rationale:** Linear scans inside `build()` compound with list size and
rebuild frequency, creating O(n × r) per-frame cost that degrades
scrolling performance on wallet-heavy accounts.

---

## Principle 6: Isolate & Background Sync Integrity

When receiving data from the background overlay isolate via
`IsolateNameServer`, the main app MUST protect fresh local state from
being overwritten by stale Firestore fetches.

- Upon receiving an isolate message, the main app MUST:
  1. Apply the local deduction/addition to the Provider's RAM state.
  2. Call `notifyListeners()` immediately.
  3. Set a **fetch shield** flag (e.g., `_blockAutoFetch = true`) to
     prevent any automatic Firestore listeners or scheduled fetches
     from overwriting the fresh local state for a defined cooldown
     period.
- The fetch shield MUST be time-bounded (recommended: 5 seconds) and
  automatically expire to allow eventual consistency resyncs.
- The background isolate MUST NOT directly call Provider methods. It
  MUST communicate exclusively through `IsolateNameServer` or
  `SendPort`/`ReceivePort` channels.
- The main isolate MUST validate that the incoming message contains a
  valid `walletId` and `amount` before applying any state mutation.

**Rationale:** Without a fetch shield, the main app's Firestore listener
can fire milliseconds after the overlay writes, returning stale data
(pre-transaction) that overwrites the correct local state and causes
the UI to "flicker" between old and new balances.

---

## Principle 7: ValueKey Invalidation

For lists displaying mutable financial data, always inject a composite
`ValueKey` to force Flutter's reconciliation engine to rebuild the
specific list item when its exact value changes.

- `WalletCard` and similar widgets MUST use
  `ValueKey('${model.id}_${model.balance}')` or an equivalent composite
  key that includes all mutable display fields.
- The key MUST be applied at the outermost widget of the list item,
  not buried inside child widgets.
- When a Provider updates a model's mutable field (e.g., balance,
  dailyUsed), the composite key naturally changes, triggering Flutter
  to dispose the old widget and mount a fresh one—guaranteeing the UI
  reflects the new value.
- Do NOT use index-based keys (`ValueKey(index)`) for mutable data
  lists. Index keys fail to trigger rebuilds when data changes
  in-place.

**Rationale:** Flutter's default list diffing algorithm compares by
widget type and key. Without a value-aware key, an updated wallet
card may retain its old state in the Element tree, showing stale
balances until a full list rebuild occurs.

---

## Governance & Amendment Process

### Amendment Procedure

1. Any contributor MAY propose an amendment by opening a pull request
   that modifies this file.
2. The proposal MUST include: the principle affected, the exact wording
   change, and a rationale paragraph.
3. Amendments MUST be reviewed by the project owner before merging.
4. Trivial wording fixes (PATCH) may be self-merged with a descriptive
   commit message.

### Versioning Policy

This constitution follows Semantic Versioning:

- **MAJOR** (e.g., 1.0.0 → 2.0.0): A principle is removed, redefined
  in a backward-incompatible way, or a new principle fundamentally
  contradicts an existing one.
- **MINOR** (e.g., 1.0.0 → 1.1.0): A new principle is added, or an
  existing principle is materially expanded with new sub-rules.
- **PATCH** (e.g., 1.0.0 → 1.0.1): Clarifications, typo fixes, or
  non-semantic rewording that does not change enforcement behavior.

### Compliance Review

- All code reviews MUST include a constitution compliance check.
- AI agents operating on this codebase MUST read this constitution
  before generating or modifying any code.
- Violations discovered post-merge MUST be tracked as tech-debt issues
  and resolved within the current sprint.

---

## Appendix: Quick Reference

| # | Principle | One-Line Rule |
|---|-----------|---------------|
| 1 | Zero-Latency | Mutate RAM first, Firestore second. |
| 2 | Anti-Jank | `Selector`/`Consumer` only, no root `watch`. |
| 3 | Zero-Waste | No `StreamBuilder` for Provider-managed data. |
| 4 | Safe Rollback | `try-catch` + revert on every optimistic write. |
| 5 | O(1) Lookup | `Map<String, Model>` in Providers, not `firstWhere`. |
| 6 | Fetch Shield | Block auto-fetch after isolate state injection. |
| 7 | ValueKey | Composite `ValueKey` on mutable list items. |
