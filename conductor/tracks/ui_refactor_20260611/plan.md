# Implementation Plan: UI Refactor

## Phase 1: Core Business Logic Fixes

- [ ] Task: Write failing tests for transaction count filtering (FR-1)
    - [ ] Create/update `test/providers/statistics_provider_test.dart`
    - [ ] Test that `addTransactionOptimistically` with `type: 'deposit'` or `type: 'add_balance'` does NOT increment `transactionCount`, `totalSent`, or `totalReceived`
    - [ ] Test that `addTransactionOptimistically` with `type: 'credit'` or `type: 'debit'` DOES increment the correct counters
    - [ ] Create/update `test/providers/transaction_provider_test.dart`
    - [ ] Test that `_deriveSummaryLocally` excludes non-debit/non-credit transactions from length and fold calculations
    - [ ] Run tests and confirm they fail (Red phase)

- [ ] Task: Implement transaction count fix in providers (FR-1)
    - [ ] In `lib/providers/transaction_provider.dart` (`_deriveSummaryLocally`): filter `transactionsList` to only include `TransactionType.debit` and `TransactionType.credit` before length checks and `.fold` calculations
    - [ ] In `lib/providers/statistics_provider.dart` (`addTransactionOptimistically`): wrap counter increment logic in `if (type == 'credit' || type == 'debit')` guard
    - [ ] Run tests and confirm all pass (Green phase)

- [ ] Task: Write failing tests for wallet enum deserialization (FR-2)
    - [ ] Create/update `test/data/models/wallet_enums_test.dart`
    - [ ] Test `fromString('vodafone cash')` → `WalletType.vodafoneCash`
    - [ ] Test `fromString('  Vodafone_Cash ')` → `WalletType.vodafoneCash`
    - [ ] Test all supported wallet types with mixed casing, extra whitespace, and underscore/space variations
    - [ ] Run tests and confirm they fail (Red phase)

- [ ] Task: Implement wallet enum sanitization fix (FR-2)
    - [ ] In `lib/data/models/wallet_enums.dart` (`fromString`): add `final sanitized = type.toLowerCase().trim().replaceAll(' ', '_');` before the switch
    - [ ] Update switch cases to match against sanitized keys: `'vodafone_cash'`, `'instapay'`, `'orange_cash'`, `'etisalat_cash'`, `'we_pay'`, etc.
    - [ ] Run tests and confirm all pass (Green phase)

- [ ] Task: Write failing tests for number formatting (FR-3)
    - [ ] Create/update `test/core/utils/number_formatter_test.dart`
    - [ ] Test integer amounts format without `.00` (e.g., `1500` → `'1,500'` not `'1,500.00'`)
    - [ ] Test fractional amounts preserve decimals (e.g., `1500.75` → `'1,500.75'`)
    - [ ] Test all formatted numbers use English (Western) numerals regardless of locale
    - [ ] Test `formatPhoneNumber` returns English digits without thousands separators
    - [ ] Run tests and confirm they fail (Red phase)

- [ ] Task: Implement number formatting fixes (FR-3)
    - [ ] In `lib/core/utils/number_formatter.dart`: change currency formatter to `NumberFormat('#,##0.##', 'en_US')`
    - [ ] Ensure `formatPhoneNumber` uses simple string replacement (Arabic-to-English digit mapping) — NOT `NumberFormat` class — to avoid thousands separators in phone numbers
    - [ ] Apply English locale enforcement to all currency/amount formatting methods
    - [ ] Run tests and confirm all pass (Green phase)

- [ ] Task: Conductor - User Manual Verification 'Phase 1: Core Business Logic Fixes' (Protocol in workflow.md)

## Phase 2: UX Adjustments

- [ ] Task: Write failing tests for "Add Balance" quick action (FR-4)
    - [ ] Create/update widget test for `dashboard_quick_actions.dart`
    - [ ] Test that the quick actions grid contains an "Add Balance" / "إضافة رصيد" action
    - [ ] Test that tapping the action triggers navigation to `RouteConstants.addBalance`
    - [ ] Run tests and confirm they fail (Red phase)

- [ ] Task: Implement "Add Balance" quick action (FR-4)
    - [ ] In `lib/presentation/widgets/dashboard/dashboard_quick_actions.dart`: add a new quick action card for "Add Balance" (إضافة رصيد)
    - [ ] Route `onTap` to `RouteConstants.addBalance`
    - [ ] Follow existing quick action card pattern for styling, icon, and localization
    - [ ] Run tests and confirm all pass (Green phase)

- [ ] Task: Write failing tests for simplified FAB (FR-5)
    - [ ] Create/update widget test for `wallets_list_screen.dart`
    - [ ] Test that a `FloatingActionButton.extended` with "Add Wallet" label is present
    - [ ] Test that no SpeedDial/expandable FAB widgets exist
    - [ ] Run tests and confirm they fail (Red phase)

- [ ] Task: Simplify Wallets screen FAB (FR-5)
    - [ ] In `lib/presentation/screens/wallets/wallets_list_screen.dart`: delete `_buildSpeedDialFab` and `_buildFabOptions` methods entirely
    - [ ] Replace `floatingActionButton` with `FloatingActionButton.extended(label: Text(AppLocalizations.of(context)!.addWallet), icon: Icon(Icons.add), onPressed: _navigateToAddWallet)`
    - [ ] Run tests and confirm all pass (Green phase)

- [ ] Task: Filter transaction list UI (FR-1 supplement)
    - [ ] In `lib/presentation/screens/transactions/transactions_screen.dart`: filter the displayed transaction list to only show `TransactionType.debit` and `TransactionType.credit` items
    - [ ] Ensure summary numbers at the top of the screen match the filtered visible list
    - [ ] Verify existing transaction list tests still pass

- [ ] Task: Conductor - User Manual Verification 'Phase 2: UX Adjustments' (Protocol in workflow.md)

## Phase 3: UI Redesign — WalletCard via Stitch

- [ ] Task: Fetch WalletCard design from Stitch MCP
    - [ ] Use Stitch MCP to fetch design from Project ID: `17710906945534389850`, Screen ID: `84cff1ca188a4264bff171511a7713bf`
    - [ ] Analyze the fetched design: identify layout structure, colors, typography, spacing, and visual elements
    - [ ] Document the design interpretation for implementation reference

- [ ] Task: Write failing tests for new WalletCard (FR-6)
    - [ ] Create/update `test/presentation/widgets/wallets/wallet_card_test.dart`
    - [ ] Test that WalletCard is a `StatelessWidget`
    - [ ] Test that WalletCard renders wallet name, balance, and provider type from constructor-injected `WalletModel`
    - [ ] Test frozen state visual indication when `isFrozen: true`
    - [ ] Test `onTap`, `onEdit`, `onDelete` callbacks fire correctly
    - [ ] Run tests and confirm they fail (Red phase)

- [ ] Task: Implement new WalletCard design (FR-6)
    - [ ] In `lib/presentation/widgets/wallets/wallet_card.dart`: implement the new Stitch-based layout
    - [ ] Maintain `StatelessWidget` with constructor parameters: `WalletModel wallet`, `bool isFrozen`, `VoidCallback onTap`, `VoidCallback onEdit`, `VoidCallback onDelete`
    - [ ] No `Selector`, `Consumer`, or `context.read/watch` inside the widget
    - [ ] Implement frozen state visual treatment (opacity, overlay, icon, etc.)
    - [ ] Ensure RTL/LTR compatibility with logical constraints (`EdgeInsetsDirectional`, `start`/`end`)
    - [ ] Use `ValueKey('${wallet.id}_${wallet.balance}')` for the widget key
    - [ ] Run tests and confirm all pass (Green phase)

- [ ] Task: Verify WalletCard integration with parent screen
    - [ ] Confirm `wallets_list_screen.dart` passes updated data to WalletCard via `Consumer`/`Selector` at the parent level
    - [ ] Verify wallet list renders correctly with the new card design
    - [ ] Run full test suite to check for regressions

- [ ] Task: Conductor - User Manual Verification 'Phase 3: UI Redesign — WalletCard via Stitch' (Protocol in workflow.md)
