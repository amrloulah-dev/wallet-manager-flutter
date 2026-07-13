# Plan: Final Polish & Bug Squashing

## Phase 1: Dashboard & Overlay Fixes (FR-1, FR-3)

- [x] Task: Separate Transfer Transaction Counter (FR-1) [e101da9]
    - [x] Write failing tests: Unit test for `DashboardQuickStats` (or `StatisticsProvider`) asserting that the displayed transaction count only includes `TransactionType.transfer` items, excluding top-ups and other types.
    - [x] Implement: Modify the logic in `DashboardQuickStats` / `StatisticsProvider` to filter the transaction list by `TransactionType.transfer` before computing the count. Ensure the "Latest Transactions" list remains unaffected.
    - [x] Refactor: Extract filtering logic into a reusable helper if applicable.

- [x] Task: Overlay Commission State Reset (FR-3) [3cd92ea]
    - [x] Write failing tests: Unit/widget test for `OverlayProvider` and `TransactionOverlayScreen` asserting that after a successful submission, `commission` is reset to `0` and the commission `TextEditingController` is cleared.
    - [x] Implement: In the successful submission callback, add `context.read<OverlayProvider>().setCommission(0)` and `.clear()` on the commission controller.
    - [x] Refactor: Verify no other state fields leak between overlay transactions.

- [x] Task: Conductor - User Manual Verification 'Phase 1: Dashboard & Overlay Fixes' (Protocol in workflow.md) [0cdee25]

## Phase 2: Wallet Form Fixes (FR-4, FR-5)

- [x] Task: Wallet Status UI Label Fix (FR-4) [4cd7f79]
    - [x] Write failing tests: Widget test for `WalletFormScreen` asserting that `WalletStatus.active` renders the correct active label (نشطة) and `WalletStatus.inactive` renders the correct inactive label (غير نشطة).
    - [x] Implement: Fix the status-to-localization-key mapping in `WalletFormScreen`. Map `WalletStatus.active` → `wallet_status_active` and `WalletStatus.inactive` → the correct inactive key.
    - [x] Refactor: Consider extracting the mapping into a utility/extension if it's duplicated elsewhere.

- [x] Task: Smart Carrier Prefix Validation (FR-5) [5034938]
    - [x] Write failing tests: Unit test for the prefix validation logic (Vodafone→010, Etisalat→011, Orange→012, WE→015, InstaPay→skip). Widget test asserting that a mismatched prefix shows the warning `AlertDialog` with "Edit" and "Confirm Anyway" buttons.
    - [x] Implement: In `WalletFormScreen._handleSubmit`, add prefix validation before `walletProvider.createWallet` / update calls. Show localized `AlertDialog` on mismatch. Wire "Edit" to pop dialog, "Confirm Anyway" to proceed.
    - [x] Add localization keys: Add warning message and button labels to both `app_ar.arb` and `app_en.arb`. Run `flutter gen-l10n`.
    - [x] Refactor: Extract prefix validation into a pure utility function (e.g., `Validators.validateCarrierMatch(walletType, phoneNumber)`) for testability and reuse.

- [x] Task: Conductor - User Manual Verification 'Phase 2: Wallet Form Fixes' (Protocol in workflow.md) [f82a9b7]

## Phase 3: Localization & Subscription Fixes (FR-2, FR-6)

- [x] Task: Targeted Localization Enforcement (FR-2)
    - [x] Write failing tests: Widget test asserting that `OverlayErrorApp` and other error handlers in `main.dart` display localized strings rather than hardcoded English. Widget test for `PaymentModalScreen` verifying all user-visible strings are localized.
    - [x] Implement: Audit `lib/main.dart` (error blocks, `OverlayErrorApp`, `runZonedGuarded`), `lib/presentation/screens/subscriptions/payment_modal_screen.dart`, and any closely related error screens. Replace all hardcoded English strings with `AppLocalizations.of(context)!` calls or safe fallbacks.
    - [x] Add localization keys: Add any new keys to both `app_ar.arb` and `app_en.arb`. Run `flutter gen-l10n`.
    - [x] Refactor: Ensure error fallback widgets handle the case where `AppLocalizations` is unavailable (e.g., during fatal init failure) with a hardcoded Arabic/English dual fallback.

- [x] Task: Persistent Payment Success Dialog (FR-6)
    - [x] Write failing tests: Unit test for `LocalStorageService` verifying read/write of the composite `endDate+planType` key. Unit test for the decision logic in `_maybeShowSuccessModal` asserting the dialog shows only when the stored key differs from the current subscription state.
    - [x] Implement: Add `getLastSeenPaymentKey()` and `setLastSeenPaymentKey(String key)` methods to `LocalStorageService`. In `MainDashboardScreen._maybeShowSuccessModal`, replace the RAM-based `hasSeenSuccessModal` flag with a `SharedPreferences` check using the composite key (`"${subscription.endDate}_${subscription.planType}"`).
    - [x] Refactor: Clean up any remaining RAM-only flag references. Ensure the dialog-dismiss callback writes the key immediately.

- [x] Task: Conductor - User Manual Verification 'Phase 3: Localization & Subscription Fixes' (Protocol in workflow.md) [56c17c9]

## Phase 4: Final Verification

- [x] Task: Run full test suite and static analysis
    - [x] Execute `CI=true flutter test` and confirm all tests pass.
    - [x] Execute `flutter analyze` and confirm no new warnings or errors.
    - [x] Verify all acceptance criteria (AC-1 through AC-8) are met.

- [x] Task: Conductor - User Manual Verification 'Phase 4: Final Verification' (Protocol in workflow.md)
