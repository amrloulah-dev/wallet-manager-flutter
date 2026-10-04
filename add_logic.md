We are upgrading the UX/UI of the `CreateTransactionScreen` to implement an Enterprise-Grade "Optimistic Validation" system for Receive transactions. The goal is to provide real-time visual feedback based on the wallet's dynamic capacity limit.

**DO NOT alter the `TransactionProvider` or existing Firestore logic.** Your scope is strictly the UI and state management within `CreateTransactionScreen` (and any necessary getters in `WalletModel`).

Please implement the following exactly:

### 1. State Management & Real-time Validation (Color Feedback)
- Add a listener to the `_amountController`. 
- Dynamically calculate the `maxAvailable` amount. For `receive` transactions, this is `wallet.availableToReceiveDaily` or `wallet.availableToReceiveMonthly` (whichever is lower). *Note: InstaPay wallets bypass capacity constraints, so ensure their max available reflects only the flow limit, not the balance capacity.*
- If `enteredAmount > maxAvailable`, the `TextFormField`'s border and text color must turn Red.
- Disable the "إنشاء المعاملة" (Submit) button dynamically if the amount exceeds `maxAvailable` (unless it's an InstaPay wallet, which allows soft warnings).

### 2. The "Max" Button
- Inject a `TextButton` or `IconButton` labeled "Max" (الحد الأقصى) inside the `suffixIcon` of the amount `TextFormField`.
- When tapped, it should automatically populate the `_amountController` with the `maxAvailable` value and trigger validation.

### 3. The 3-Zone Dynamic Progress Bar
- Refactor the current limit progress bar into a `Row` of `Flexible` containers (or a custom graphical widget) to visually represent 3 zones for e-wallets during a `receive` transaction:
  - **Zone 1 (Used):** Colored Red/Dark. Represents `monthlyUsed`.
  - **Zone 2 (Available):** Colored Green. Represents `maxAvailable`.
  - **Zone 3 (Blocked by Balance):** Colored Grey/Hatched. Represents the space unavailable due to the existing wallet balance.
  - *Math constraint:* Total width represents `monthlyLimit`. `Zone 3` is calculated as `monthlyLimit - (monthlyUsed + maxAvailable)`.
- If the wallet is `instapay` or the transaction type is `send`, revert to the standard 2-zone progress bar (Used vs. Remaining) without the Grey block.

### Execution Constraints:
- Ensure the UI rebuilding is optimized (use `ValueListenableBuilder` or specific `setState` scopes if possible) so typing in the text field does not lag.
- Ensure all localized strings (if new) fallback to hardcoded Arabic if `app_ar.arb` injection isn't possible directly.

Review the codebase, write the necessary modifications, and provide the updated code segments.