Act as a Senior Flutter Architect and execute this comprehensive 6-point Master Refactor Plan. You must strictly follow these instructions step-by-step to fix business logic bugs, refine the UX, and integrate a new UI design via Google Stitch. 

**CRITICAL RULE:** Do NOT use `Selector`, `Consumer`, or `context.read/watch` inside isolated UI components unless explicitly told to.

### Part 1: Core Business Logic Fixes

**1. Fix Transaction Counts (Ignore Deposits/Debt Settlements)**
Target: `transaction_provider.dart` & `statistics_provider.dart`
- **Bug:** `transactionsList.length` counts "add balance/deposit" as transactions.
- **Action:** - In `transaction_provider.dart` (`_deriveSummaryLocally`), modify the length checks and `.fold` functions to ONLY include items where `transactionType == TransactionType.debit || transactionType == TransactionType.credit`.
  - In `statistics_provider.dart` (`addTransactionOptimistically`), wrap the increment logic in an `if` statement. ONLY increment `transactionCount`, `totalTransactions`, `totalSent`, or `totalReceived` if the incoming `type` is exactly 'credit' or 'debit'.

**2. Fix Wallet Type Enum Deserialization ("أخرى" Bug)**
Target: `wallet_enums.dart` (`fromString`)
- **Bug:** Spaces or uppercase letters from the database cause the string match to fail, defaulting to `WalletType.other`.
- **Action:** Aggressively sanitize the input string before the `switch` case:
  `final sanitized = type.toLowerCase().trim().replaceAll(' ', '_');`
  Then match against `'vodafone_cash'`, `'instapay'`, etc.

**3. Enforce English Numbers & Smart Decimals**
Target: `number_formatter.dart`
- **Bug:** Numbers appear in Arabic digits based on the device locale, and integer amounts show `.00` (e.g., 150.00).
- **Action:** - Force the locale to English: `final formatter = NumberFormat('#,##0.##', 'en_US');`. The pattern `#,##0.##` ensures whole numbers drop the decimals while keeping necessary fractions.
  - Apply this to currency formats and ensure `formatPhoneNumber` strictly returns English digits (strip non-digits and ensure no Arabic numeral conversion).

### Part 2: UX Adjustments

**4. Add "Add Balance" to Quick Actions**
Target: `dashboard_quick_actions.dart` (or wherever the grid is built)
- **Action:** Add a new quick action card/button for "Add Balance" (إضافة رصيد) that routes the user to `RouteConstants.addBalance`.

**5. Simplify Wallets Screen FAB**
Target: `wallets_list_screen.dart` (`_buildSpeedDialFab` & `_buildFabOptions`)
- **Bug:** The FAB is currently a complex Stack with a SpeedDial menu.
- **Action:** Completely DELETE the `_buildSpeedDialFab` and `_buildFabOptions` methods. Replace the screen's `floatingActionButton` with a simple, direct `FloatingActionButton.extended`:
  - `label`: `Text(AppLocalizations.of(context)!.addWallet)`
  - `icon`: `Icon(Icons.add)`
  - `onPressed`: `_navigateToAddWallet`

### Part 3: UI Redesign Integration via MCP (Google Stitch)

**6. Implement New Wallet Card Design**
Target: `wallet_card.dart`
- **Action:** I have prepared a new design in Google Stitch. Use your MCP capabilities to fetch the exact images and code for this project:
  - **Project Title:** Simplified Card Redesign
  - **Project ID:** 17710906945534389850
  - **Screen:** Wallet Card Redesign (ID: 84cff1ca188a4264bff171511a7713bf)
  - You may use a utility like `curl -L` if necessary to fetch hosted URLs provided by your Stitch MCP tool.
- **Architectural Constraints for the new `WalletCard`:**
  - Analyze the fetched Stitch UI and adapt it to Flutter code inside `wallet_card.dart`.
  - **CRITICAL:** The new `WalletCard` MUST remain a `StatelessWidget`. 
  - Do NOT wrap it in a `Selector` or `Consumer`. 
  - It must accept `WalletModel wallet`, `bool isFrozen`, and callback functions (`onTap`, `onEdit`, `onDelete`) exclusively via its constructor. The parent `wallets_list_screen.dart` already handles the reactivity.

Execute these 6 steps in order. Review your generated code to ensure zero regressions. Present the final updated code for the modified files.