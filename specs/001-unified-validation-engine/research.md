# Phase 0: Research

## Firestore Atomic Transactions
- **Decision:** Use `FirebaseFirestore.instance.runTransaction` for all operations altering wallet balance.
- **Rationale:** Prevents race conditions when overlapping updates happen (e.g. rapid succession SMS overlays).
- **Alternatives:** `WriteBatch` or `update()` (rejected due to Constitution rules).

## Stream-based State Management
- **Decision:** Update `WalletProvider` to hold a `StreamSubscription<DocumentSnapshot>` for active wallets. Replace future-based `get()` calls in UI with simple `Consumer<WalletProvider>` that reads the live state.
- **Rationale:** Ensures that background isolate writes (Overlay) seamlessly update foreground UI without complex IPC mechanisms.
- **Alternatives:** Polling or IsolateNameServer pinging (more complex, less reliable).

## Background Isolate Execution
- **Decision:** Execute `TransactionValidatorService` via the existing OverlayProvider. The Overlay runs in a background isolate but has full access to initialized Firebase services.
- **Rationale:** The simplest way to keep the main isolate clean per Constitution rule 5.
