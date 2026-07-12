# Spec: Final Polish & Bug Squashing

## Overview

A targeted sweep of 6 bug fixes and refinements to prepare the Wallet Manager app for release. This track addresses incorrect UI mappings, state leaks, localization gaps, and missing business validations across the dashboard, overlay, wallet forms, and subscription system.

## Track Type

Bug Fix / Refactor (Multi-Task)

## Functional Requirements

### FR-1: Separate Transfer Transaction Counter (Dashboard)

- **Current Behavior:** The "Total Transactions" (إجمالي المعاملات) card on the dashboard shows the sum of ALL transaction types, including wallet top-ups.
- **Required Behavior:** The card MUST display only the count of `TransactionType.transfer` transactions.
- **Constraint:** The "Latest Transactions" list below the stats cards MUST remain unchanged (showing all types).
- **Target Area:** `DashboardQuickStats` widget and/or `StatisticsProvider`.

### FR-2: Strict Localization Enforcement (Targeted Audit)

- **Current Behavior:** Hardcoded English strings exist in error handlers (`main.dart`) and payment screens (`payment_modal_screen.dart`).
- **Required Behavior:** ALL user-visible strings in the targeted files MUST use `AppLocalizations.of(context)!` or safe localized fallbacks. Raw English system exceptions MUST NOT leak into the UI.
- **Scope:** Limited to the two primary target files and any closely related error handling screens:
  1. `lib/main.dart` — error handling blocks (`OverlayErrorApp`, `runZonedGuarded`, fatal error handlers)
  2. `lib/presentation/screens/subscriptions/payment_modal_screen.dart`
  3. Any directly related error/fallback UI screens referenced by the above (e.g., dedicated error app widgets)
- **Explicitly Out of Scope:** A full codebase audit for hardcoded strings is NOT part of this task.
- **Constraint:** Non-UI strings (logs, analytics keys, Firestore field names) are excluded from this requirement.

### FR-3: Overlay Window Commission State Reset

- **Current Behavior:** After a successful transaction submission via the SMS overlay, the `commission` value persists in memory/UI for the next transaction.
- **Required Behavior:** Upon successful submission, the commission state MUST be reset to `0` in `OverlayProvider` and the commission `TextEditingController` MUST be cleared.
- **Target Area:** `TransactionOverlayScreen` and `OverlayProvider`.

### FR-4: Wallet Status UI Label Fix

- **Current Behavior:** The wallet form incorrectly maps `WalletStatus.active` → `newStatus` ("غير نشطة") and `WalletStatus.inactive` → `oldStatus`, displaying reversed labels.
- **Required Behavior:** `WalletStatus.active` MUST map to the correct active localization key (نشطة) and `WalletStatus.inactive` MUST map to the correct inactive localization key (غير نشطة).
- **Target Area:** `WalletFormScreen`.

### FR-5: Smart Carrier Prefix Validation (Wallet Form)

- **Current Behavior:** Any phone number is accepted for any wallet type without validation.
- **Required Behavior:** Before creating or editing a wallet, validate the phone number prefix against Egyptian telecom standards:
  - Vodafone Cash → `010`
  - Etisalat Cash → `011`
  - Orange Cash → `012`
  - WE Pay → `015`
  - InstaPay → Skip validation (no prefix requirement)
- **On Mismatch:** Show an `AlertDialog` warning: "The phone number prefix does not match the selected network" (localized). Provide two buttons:
  - "Edit" → Returns the user to the form (no action taken)
  - "Confirm Anyway" → Proceeds with wallet creation/update
- **Scope:** Applies to both wallet **creation** and **editing** flows.
- **Target Area:** `WalletFormScreen` (`_handleSubmit`).

### FR-6: Persistent Payment Success Dialog

- **Current Behavior:** The "Payment Confirmed" success modal re-appears on every app restart for Pro/Lifetime users because the `hasSeenSuccessModal` flag is stored only in RAM.
- **Required Behavior:** Persist the flag using `SharedPreferences` (via `LocalStorageService`). Store a composite key of `endDate` + `planType` when the dialog is shown. On app startup, only show the dialog if:
  1. The user has an active Premium/Lifetime subscription, AND
  2. The stored composite key differs from the current subscription's `endDate` + `planType`.
- **Target Area:** `MainDashboardScreen` (`_maybeShowSuccessModal`), `SubscriptionProvider` or `LocalStorageService`.

## Non-Functional Requirements

- **NFR-1:** All fixes MUST maintain existing unit/widget test coverage. New tests MUST be added for each fix.
- **NFR-2:** All new/modified user-facing strings MUST be added to both `app_ar.arb` and `app_en.arb` localization files.
- **NFR-3:** All changes MUST follow the project's Optimistic UI pattern and `SafeChangeNotifier` conventions where applicable.
- **NFR-4:** No breaking changes to existing Firestore schemas or security rules.

## Acceptance Criteria

- [ ] AC-1: Dashboard "Total Transactions" card shows only transfer-type transaction count.
- [ ] AC-2: No hardcoded English strings appear in any user-facing UI context within the targeted files (`main.dart` error handlers, `payment_modal_screen.dart`, and closely related error screens).
- [ ] AC-3: Commission field and state reset to 0 after each successful overlay transaction.
- [ ] AC-4: Wallet status labels display correctly (active → نشطة, inactive → غير نشطة).
- [ ] AC-5: Mismatched carrier prefix triggers a warning dialog on wallet create **and** edit; user can override.
- [ ] AC-6: Payment success dialog only appears once per unique `endDate+planType` combination, surviving app restarts.
- [ ] AC-7: All new functionality has corresponding unit tests with >80% coverage.
- [ ] AC-8: `flutter analyze` reports no new warnings or errors.

## Out of Scope

- Refactoring the overlay architecture beyond the commission reset.
- Adding new wallet provider types.
- Changing the subscription/payment backend logic.
- Migrating existing localization keys or restructuring ARB files.
- Any Firestore schema or security rule changes.
- Full codebase audit for hardcoded English strings (limited to targeted files only).
