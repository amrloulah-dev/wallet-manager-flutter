# Implementation Plan: UI Refactor

## Phase 1: Core Business Logic Fixes

- [x] Task: Write failing tests for transaction count filtering (FR-1) 99a5d48
    - [x] Create/update `test/providers/statistics_provider_test.dart`
    - [x] Test that `addTransactionOptimistically` with `type: 'deposit'` or `type: 'add_balance'` does NOT increment `transactionCount`, `totalSent`, or `totalReceived`
    - [x] Test that `addTransactionOptimistically` with `type: 'credit'` or `type: 'debit'` DOES increment the correct counters
    - [x] Create/update `test/providers/transaction_provider_test.dart`
    - [x] Test that `_deriveSummaryLocally` excludes non-debit/non-credit transactions from length and fold calculations
    - [x] Run tests and confirm they fail (Red phase)

- [x] Task: Implement transaction count fix in providers (FR-1) 99a5d48
    - [x] In `lib/providers/transaction_provider.dart` (`_deriveSummaryLocally`): filter `transactionsList` to only include `TransactionType.debit` and `TransactionType.credit` before length checks and `.fold` calculations
    - [x] In `lib/providers/statistics_provider.dart` (`addTransactionOptimistically`): wrap counter increment logic in `if (type == 'credit' || type == 'debit')` guard
    - [x] Run tests and confirm all pass (Green phase)

- [x] Task: Write failing tests for wallet enum deserialization (FR-2) 99a5d48
    - [x] Create/update `test/data/models/wallet_enums_test.dart`
    - [x] Test `fromString('vodafone cash')` → `WalletType.vodafoneCash`
    - [x] Test `fromString('  Vodafone_Cash ')` → `WalletType.vodafoneCash`
    - [x] Test all supported wallet types with mixed casing, extra whitespace, and underscore/space variations
    - [x] Run tests and confirm they fail (Red phase)

- [x] Task: Implement wallet enum sanitization fix (FR-2) 99a5d48
    - [x] In `lib/data/models/wallet_enums.dart` (`fromString`): add `final sanitized = type.toLowerCase().trim().replaceAll(' ', '_');` before the switch
    - [x] Update switch cases to match against sanitized keys: `'vodafone_cash'`, `'instapay'`, `'orange_cash'`, `'etisalat_cash'`, `'we_pay'`, etc.
    - [x] Run tests and confirm all pass (Green phase)

- [x] Task: Write failing tests for number formatting (FR-3) 99a5d48
    - [x] Create/update `test/core/utils/number_formatter_test.dart`
    - [x] Test integer amounts format without `.00` (e.g., `1500` → `'1,500'` not `'1,500.00'`)
    - [x] Test fractional amounts preserve decimals (e.g., `1500.75` → `'1,500.75'`)
    - [x] Test all formatted numbers use English (Western) numerals regardless of locale
    - [x] Test `formatPhoneNumber` returns English digits without thousands separators
    - [x] Run tests and confirm they fail (Red phase)

- [x] Task: Implement number formatting fixes (FR-3) 99a5d48
    - [x] In `lib/core/utils/number_formatter.dart`: change currency formatter to `NumberFormat('#,##0.##', 'en_US')`
    - [x] Ensure `formatPhoneNumber` uses simple string replacement (Arabic-to-English digit mapping) — NOT `NumberFormat` class — to avoid thousands separators in phone numbers
    - [x] Apply English locale enforcement to all currency/amount formatting methods
    - [x] Run tests and confirm all pass (Green phase)

- [ ] Task: Conductor - User Manual Verification 'Phase 1: Core Business Logic Fixes' (Protocol in workflow.md)

## Phase 2: UX Adjustments [checkpoint: d4ca92b]

- [x] Task: Write failing tests for "Add Balance" quick action (FR-4) 1436aaf
    - [x] Create/update widget test for `dashboard_quick_actions.dart`
    - [x] Test that the quick actions grid contains an "Add Balance" / "إضافة رصيد" action
    - [x] Test that tapping the action triggers navigation to `RouteConstants.addBalance`
    - [x] Run tests and confirm they fail (Red phase)

- [x] Task: Implement "Add Balance" quick action (FR-4) 1436aaf
    - [x] In `lib/presentation/widgets/dashboard/dashboard_quick_actions.dart`: add a new quick action card for "Add Balance" (إضافة رصيد)
    - [x] Route `onTap` to `RouteConstants.addBalance`
    - [x] Follow existing quick action card pattern for styling, icon, and localization
    - [x] Run tests and confirm all pass (Green phase)

- [x] Task: Write failing tests for simplified FAB (FR-5) 1436aaf
    - [x] Create/update widget test for `wallets_list_screen.dart`
    - [x] Test that a `FloatingActionButton.extended` with "Add Wallet" label is present
    - [x] Test that no SpeedDial/expandable FAB widgets exist
    - [x] Run tests and confirm they fail (Red phase)

- [x] Task: Simplify Wallets screen FAB (FR-5) 1436aaf
    - [x] In `lib/presentation/screens/wallets/wallets_list_screen.dart`: delete `_buildSpeedDialFab` and `_buildFabOptions` methods entirely
    - [x] Replace `floatingActionButton` with `FloatingActionButton.extended(label: Text(AppLocalizations.of(context)!.addWallet), icon: Icon(Icons.add), onPressed: _navigateToAddWallet)`
    - [x] Run tests and confirm all pass (Green phase)

- [x] Task: Filter transaction list UI (FR-1 supplement) 1436aaf
    - [x] In `lib/presentation/screens/transactions/transactions_screen.dart`: filter the displayed transaction list to only show `TransactionType.debit` and `TransactionType.credit` items
    - [x] Ensure summary numbers at the top of the screen match the filtered visible list
    - [x] Verify existing transaction list tests still pass

- [x] Task: Conductor - User Manual Verification 'Phase 2: UX Adjustments' (Protocol in workflow.md) 1436aaf

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
