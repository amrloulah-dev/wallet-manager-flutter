We are executing the "Final Polish & Bug Squashing" phase for the application to prepare it for release. Please implement the following 6 targeted fixes. 

For each task, I have provided the context, the target file, and the exact required logic. Please implement them systematically and check them off.

### Task 1: Separate Transaction Counters (Dashboard)
- **Context:** The "Total Transactions" (إجمالي المعاملات) card on the dashboard currently shows the sum of ALL transactions (including wallet top-ups). We want this specific card to ONLY show the total number of "Transfer" transactions.
- **Target File:** `lib/presentation/screens/home/widgets/dashboard_quick_stats.dart` (or `StatisticsProvider`).
- **Fix:** Change the logic so the displayed number is calculated by filtering the transactions list for transfers only (e.g., `_transactionsList.where((t) => t.type == TransactionType.transfer).length`), rather than using the generic `todayStats?.totalTransactions`. Do not alter the "Latest Transactions" list below it.

### Task 2: Strict Localization Enforcement
- **Context:** Some fatal error handlers and UI elements still use hardcoded English strings, bypassing the Arabic/English toggle.
- **Target Files:** `lib/main.dart` (Error handling blocks like `OverlayErrorApp` or `runZonedGuarded`) and `lib/presentation/screens/subscriptions/payment_modal_screen.dart`.
- **Fix:** Audit these specific files. Replace hardcoded English strings (e.g., 'App initialization failed') with proper `AppLocalizations.of(context)` calls or safe localized fallbacks. Do not leak raw English system exceptions directly into the UI.

### Task 3: Overlay Window Commission State Reset
- **Context:** In the background SMS overlay, when a user enters a commission and successfully saves the transaction, the `commission` value persists in the memory/UI for the next transaction.
- **Target File:** `lib/presentation/overlays/transaction_overlay_screen.dart` (and `OverlayProvider`).
- **Fix:** Inside the successful submission logic, add code to reset the commission state to `0` (e.g., `context.read<OverlayProvider>().setCommission(0)`) and ensure the `TextEditingController` for the commission field is cleared (`.clear()`).

### Task 4: Wallet Status UI Flip (Incorrect Mapping)
- **Context:** The Wallet form incorrectly maps `WalletStatus.active` to a localization key named `newStatus`, and `inactive` to `oldStatus`, resulting in incorrect UI text ("غير نشطة" for active wallets).
- **Target File:** `lib/presentation/screens/wallets/wallet_form_screen.dart`.
- **Fix:** Fix the mapping dictionary. Map `WalletStatus.active` to `AppLocalizations.of(context)!.wallet_status_active` (نشطة) and `WalletStatus.inactive` to the correct inactive translation key.

### Task 5: Smart Carrier Validation (Add Wallet)
- **Context:** When creating a wallet, the app accepts any phone number for any wallet type. We need business logic to warn the user if the prefix doesn't match the Egyptian telecom network standards.
- **Target File:** `lib/presentation/screens/wallets/wallet_form_screen.dart` (inside `_handleSubmit`).
- **Fix:** Before calling `walletProvider.createWallet`, inject a prefix validation logic:
  - Vodafone must start with `010`, Etisalat `011`, Orange `012`, We `015`. InstaPay ignores this check.
  - If the prefix does NOT match the selected `walletType`, do NOT block the process. Instead, show an `AlertDialog` warning: "The phone number prefix does not match the selected network." Provide two buttons: "Edit" (returns to form) and "Confirm Anyway" (proceeds to create the wallet).

### Task 6: Persistent Payment Success Dialog
- **Context:** The "Payment Confirmed" modal triggers on every app restart for Pro/Lifetime users because the `hasSeenSuccessModal` flag is stored in RAM and resets when the app is closed.
- **Target File:** `lib/presentation/screens/home/main_dashboard_screen.dart` (inside `_maybeShowSuccessModal`) and `SubscriptionProvider` or `LocalStorageService`.
- **Fix:** Refactor this flag to be persistent. Use `SharedPreferences` (via `LocalStorageService`). When the dialog is shown, save the current subscription's `endDate` (or a unique payment ID). On app startup, only show the dialog if the user is Premium AND the current `endDate` is different from the stored one.

Please output your implementation plan for these 6 tasks and proceed to code them.