Act as a Senior Flutter Architect. We are migrating our core features (Transactions, Wallets, Debts) to a highly cost-effective "Optimistic UI" architecture. We want to achieve Real-Time UI updates WITHOUT using expensive Firestore Streams for reading data. 

**CRITICAL INSTRUCTION:** Do NOT write code yet. Read this blueprint carefully, acknowledge the constraints, list the exact files you will modify, and wait for my "GO" command.

### 🏛️ Core Architectural Rules (APPLIES TO ALL PHASES):
1. **Client-Side UUIDs:** NEVER rely on Firestore to generate document IDs. Generate a unique ID using the `uuid` package locally FIRST, assign it to the model, and use `.set()` (or batch set) instead of `.add()`. This prevents duplicate data during pull-to-refresh syncs.
2. **Optimistic Local Update First:** Update the local Provider lists and UI states IMMEDIATELY before executing the `await` call to Firestore. Zero UI latency.
3. **Derived Summaries (No Static Counters):** Remove any static state variables used for summaries (e.g., `totalIncome`, `totalOpenDebts`). Summaries MUST be computed dynamically on-the-fly via getters that loop through the local lists whenever they change.
4. **Strict Rollback Mechanism:** Wrap every Firestore network call in a `try/catch` block. If the server write fails, you MUST revert the local lists and balances to their previous state and show a failure toast.
5. **Immutable Ledger & Timestamps:** Transactions cannot be edited or deleted. For timestamps, use local `DateTime.now()` for immediate UI display, but save to Firestore using `FieldValue.serverTimestamp()`.
6. **Offline Persistence:** Ensure `FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true)` is initialized in `main.dart`.

---

### 🚀 Phase 1: Transactions (معاملات اليوم)
**Target:** `TransactionProvider`, `create_transaction_screen`, `main_dashboard_screen`
- **Creation:** Generate UUID -> Add transaction to the top of `transactionsList` locally (`.insert(0, tx)`) -> Update the related wallet's `currentBalance` locally -> UI updates instantly.
- **Atomicity:** You MUST use a Firestore `WriteBatch`. The batch must include BOTH the transaction document creation and the wallet balance update.
- **Summaries:** The Dashboard summaries (Total Sent, Total Received, Total Commission) must dynamically recalculate from the updated `transactionsList`.

### 🏦 Phase 2: Wallets (المحافظ)
**Target:** `WalletProvider`, `wallets_list_screen`, `add_wallet_screen`
- **Creation:** Generate UUID -> Add to `walletsList` locally -> UI updates -> Await Firestore `.set()`. 
- **Summary:** "Total Active Wallets" updates dynamically based on the local list's length and status.
- **Balance Sync:** Ensure that any transaction created in Phase 1 seamlessly updates the specific wallet's balance in the `walletsList` without requiring a fresh fetch from Firestore.

### 💳 Phase 3: Debts (الديون)
**Target:** `DebtProvider`, `debts_screen`, `add_debt_screen`
- **Creation:** Generate UUID -> Add to `debtsList` locally -> UI updates immediately -> Await Firestore `.set()`.
- **Settlement (تسديد):** When a user marks a debt as paid, update the local model's status to "Paid" immediately. The UI must instantly move the debt card to the "Paid" tab. Then execute the Firestore update.
- **Summaries:** The "Open Debts" and "Settled Debts" summary cards must derive their counts and total amounts dynamically from the local `debtsList`.

**Agent Action Required:** Confirm you understand the 6 Core Architectural Rules (especially UUID generation and Rollbacks). Outline the implementation steps and the files you will touch. Do not generate the actual Dart code until I review your plan and say "GO".