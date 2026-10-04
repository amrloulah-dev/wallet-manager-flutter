# Track: UI Refactor — Business Logic Fixes, UX Adjustments & WalletCard Redesign

## Overview

A comprehensive 6-point refactor addressing three categories of improvements across the Wallet Manager app:

1. **Core Business Logic Fixes** — Correct transaction counting, wallet type enum deserialization, and number formatting.
2. **UX Adjustments** — Add "Add Balance" quick action, simplify the Wallets screen FAB, and filter transaction list UI.
3. **UI Redesign** — Implement a new WalletCard design fetched from Google Stitch (Project ID: `17710906945534389850`, Screen ID: `84cff1ca188a4264bff171511a7713bf`).

## Type

Refactor (mixed: bug fixes + UX improvements + UI redesign)

## Functional Requirements

### FR-1: Fix Transaction Counts (Ignore Deposits/Debt Settlements)

**Target:** `transaction_provider.dart`, `statistics_provider.dart`, `transactions_screen.dart`

- In `transaction_provider.dart` (`_deriveSummaryLocally`), modify length checks and `.fold` functions to **only** include items where `transactionType == TransactionType.debit || transactionType == TransactionType.credit`.
- In `statistics_provider.dart` (`addTransactionOptimistically`), wrap increment logic in an `if` statement. Only increment `transactionCount`, `totalTransactions`, `totalSent`, or `totalReceived` when the incoming `type` is exactly `'credit'` or `'debit'`.
- Deposits, add_balance, and debt settlement types must NOT affect transaction counters.
- **UI List Filtering:** In `transactions_screen.dart` (or wherever the daily transactions list is built), the ListView itself MUST be filtered to only display items where `transactionType == TransactionType.debit || transactionType == TransactionType.credit`. This ensures the summary numbers at the top match the visual list of items below.

### FR-2: Fix Wallet Type Enum Deserialization ("أخرى" Bug)

**Target:** `wallet_enums.dart` (`fromString`)

- Sanitize input string before switch/match: `final sanitized = type.toLowerCase().trim().replaceAll(' ', '_');`
- Match against normalized keys: `'vodafone_cash'`, `'instapay'`, `'orange_cash'`, `'etisalat_cash'`, `'we_pay'`, etc.
- Prevent fallback to `WalletType.other` due to casing or whitespace differences from database values.

### FR-3: Enforce English Numbers & Smart Decimals

**Target:** `number_formatter.dart`

- Force locale to English: `NumberFormat('#,##0.##', 'en_US')`.
- Pattern `#,##0.##` ensures whole numbers drop decimals (e.g., `1500` not `1500.00`) while preserving necessary fractions.
- Apply to all currency formatting methods.
- **CRITICAL:** `formatPhoneNumber` must NOT use the `NumberFormat` class — it would add thousands separators to phone numbers (e.g., `010,123,456`). Phone numbers must be sanitized via simple string replacement (Arabic-to-English digit mapping) and formatting logic, distinct from currency math.

### FR-4: Add "Add Balance" to Quick Actions

**Target:** `dashboard_quick_actions.dart` (or equivalent quick actions grid widget)

- Add a new quick action card/button for "Add Balance" (إضافة رصيد).
- Route to `RouteConstants.addBalance` on tap.
- Follow existing quick action card pattern for styling and localization.

### FR-5: Simplify Wallets Screen FAB

**Target:** `wallets_list_screen.dart`

- **Delete** the `_buildSpeedDialFab` and `_buildFabOptions` methods entirely.
- Replace with a simple `FloatingActionButton.extended`:
  - `label`: `Text(AppLocalizations.of(context)!.addWallet)`
  - `icon`: `Icon(Icons.add)`
  - `onPressed`: `_navigateToAddWallet`

### FR-6: Implement New WalletCard Design (via Stitch)

**Target:** `wallet_card.dart`

- Fetch the new design from Google Stitch MCP (Project: `17710906945534389850`, Screen: `84cff1ca188a4264bff171511a7713bf`).
- Adapt the fetched Stitch UI into Flutter code inside `wallet_card.dart`.
- The new `WalletCard` **must** remain a `StatelessWidget`.
- **Must NOT** wrap in `Selector` or `Consumer`.
- Accepts `WalletModel wallet`, `bool isFrozen`, and callback functions (`onTap`, `onEdit`, `onDelete`) exclusively via constructor.
- Parent `wallets_list_screen.dart` handles all reactivity.

## Architectural Constraints

### Widget Architecture (Hybrid Model)

- **Child/item widgets** (WalletCard and similar extracted components): Pure "dumb" components. Receive all data via constructor parameters only. No `Selector`, `Consumer`, or `context.read/watch` inside.
- **Parent/screen widgets** (e.g., `wallets_list_screen.dart`, `main_dashboard_screen.dart`): **Must** use `Consumer` or `context.watch` to listen to Providers and pass dynamically updated data down to child widgets.

### Existing Patterns

- All providers extend `SafeChangeNotifier` (not `ChangeNotifier`).
- Optimistic UI pattern: mutate RAM first, `safeNotify()`, then Firestore in background.
- Localization via `AppLocalizations.of(context)!`.
- Navigation via `RouteConstants` and `NavigationService`/`AppRouter`.

## Acceptance Criteria

### AC-1: Transaction Count Accuracy
- [ ] Adding a deposit/add_balance transaction does NOT increment `transactionCount`, `totalSent`, or `totalReceived` in statistics.
- [ ] Only `credit` and `debit` types contribute to transaction summaries and counts.
- [ ] Transaction list UI only displays `debit` and `credit` transactions — summary numbers match the visible list.
- [ ] **Unit test:** `statistics_provider_test.dart` verifies deposit/add_balance exclusion.

### AC-2: Wallet Type Parsing
- [ ] `WalletType.fromString('vodafone cash')` → `WalletType.vodafoneCash` (not `other`).
- [ ] `WalletType.fromString('  Vodafone_Cash ')` → `WalletType.vodafoneCash`.
- [ ] All supported wallet types parse correctly regardless of casing, whitespace, or underscore variations.
- [ ] **Unit test:** `wallet_enums_test.dart` covers messy input parsing.

### AC-3: Number Formatting
- [ ] Integer amounts display without `.00` (e.g., `1,500` not `1,500.00`).
- [ ] Fractional amounts display correctly (e.g., `1,500.75`).
- [ ] All displayed numbers use English (Western) numerals regardless of device locale.
- [ ] Phone numbers formatted without thousands separators via string replacement (not `NumberFormat`).
- [ ] **Unit test:** `number_formatter_test.dart` verifies decimal trimming and locale enforcement.

### AC-4: Quick Action Presence
- [ ] "Add Balance" button appears in dashboard quick actions.
- [ ] Tapping it navigates to the add balance screen.

### AC-5: Simplified FAB
- [ ] Wallets screen shows a simple `FloatingActionButton.extended` with "Add Wallet" label.
- [ ] SpeedDial/expandable FAB code is fully removed.
- [ ] Tapping FAB navigates to add wallet screen.

### AC-6: New WalletCard Design
- [ ] WalletCard renders the new Stitch-designed layout.
- [ ] WalletCard is a `StatelessWidget` with constructor-only data injection.
- [ ] No Provider access inside WalletCard.
- [ ] Frozen state visually indicated.
- [ ] `onTap`, `onEdit`, `onDelete` callbacks function correctly.

## Out of Scope

- Changes to Firestore schema or security rules.
- Adding new wallet providers or transaction types.
- Dashboard layout redesign beyond the quick actions addition.
- Multi-store support.
- Changes to SMS automation or overlay window.
- Performance optimization beyond the scope of these 6 tasks.
