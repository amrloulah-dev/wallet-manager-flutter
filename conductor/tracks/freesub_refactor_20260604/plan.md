# Implementation Plan: Monetization & Business Logic Refactor (freesub_refactor)

## Phase 1: Localization & Model Constraints Updates
- [x] Task: Update localization files and model limits
    - [x] Subtask: Add `employeeLoginBlockedSubscriptionExpired` and `walletsLimitExceededFree` to `app_ar.arb` and `app_en.arb`
    - [x] Subtask: Update features and plan pricing strings in `.arb` files to match exactly
    - [x] Subtask: Run `flutter gen-l10n` to update Dart localized strings
    - [x] Subtask: Write unit tests for `SubscriptionProvider` validating `maxWallets == 2` and `maxEmployees == 0` when expired or free plan
    - [x] Subtask: Update `SubscriptionProvider` getters `maxWallets` and `maxEmployees` to enforce these limits
    - [x] Subtask: Run tests to verify `SubscriptionProvider` limits pass
- [x] Task: Conductor - User Manual Verification 'Phase 1: Localization & Model Constraints Updates' (Protocol in workflow.md)

## Phase 2: Settings Screen & SMS Automation Guarding
- [x] Task: SMS Automation toggling restrictions and settings styling
    - [x] Subtask: Write unit tests for `SmsAutomationSection` toggle interactions when expired
    - [x] Subtask: Modify `sms_automation_section.dart` to perform haptic feedback, toast warning, and paywall redirect on tap when expired
    - [x] Subtask: Rename Settings section title to "الاشتراكات" / "Subscriptions" and verify tile structure in `app_info_section.dart`
    - [x] Subtask: Verify Settings UI looks clean and navigation flows to Paywall and Subscription Details screens correctly
- [x] Task: Conductor - User Manual Verification 'Phase 2: Settings Screen & SMS Automation Guarding' (Protocol in workflow.md)

## Phase 3: Paywall Screen & Payment Details Updates
- [x] Task: Update Paywall copywriting and payment modal fields
    - [x] Subtask: Verify and update features lists in `paywall_screen.dart`
    - [x] Subtask: Write tests verifying `PaymentModalScreen` replaces the receipt field with a phone number field and validates phone numbers
    - [x] Subtask: Update `payment_modal_screen.dart` to collect and validate sender phone number instead of receipt number, with localized labels
    - [x] Subtask: Confirm target manual transfer number is `01091264053`
- [x] Task: Conductor - User Manual Verification 'Phase 3: Paywall Screen & Payment Details Updates' (Protocol in workflow.md)

## Phase 4: Subscription Details Screen & Dashboard Expiry Banner Updates
- [x] Task: Subscription Details widget update and dashboard banner formatting
    - [x] Subtask: Write tests verifying `SubscriptionDetailsScreen` fetches data on load and displays loading indicator when status is loading or idle/empty
    - [x] Subtask: Convert `subscription_details_screen.dart` to a `StatefulWidget` and fetch initial provider data in `initState`
    - [x] Subtask: Show `CircularProgressIndicator` instead of '0' when lists are loading/empty
    - [x] Subtask: Modify `main_dashboard_screen.dart` to inject the persistent SubscriptionBanner at the top of the layout, applying the exact trial/annual visibility logic and the days-formatting edge cases (0 and negative days).
    - [x] Subtask: Verify `SubscriptionBanner` formatting for `days == 0` and `days < 0` matches spec
- [x] Task: Conductor - User Manual Verification 'Phase 4: Subscription Details Screen & Dashboard Expiry Banner Updates' (Protocol in workflow.md)

## Phase 5: Security Guards: Anti-Cycling Lock & Employee Login Guard
- [x] Task: Implement edit/delete blocks and employee login block
    - [x] Subtask: Write tests verifying wallet edit and delete actions are blocked with toast and redirect when expired
    - [x] Subtask: Block edit and delete actions in `wallet_details_screen.dart` and `wallets_list_screen.dart` when subscription is expired
    - [x] Subtask: Write tests verifying employee login is aborted when store subscription is expired
    - [x] Subtask: Update `employee_login_screen.dart` to abort login, display toast warning, and stay on page when store subscription is expired
    - [x] Subtask: Run all project unit tests and verify they pass
- [x] Task: Conductor - User Manual Verification 'Phase 5: Security Guards: Anti-Cycling Lock & Employee Login Guard' (Protocol in workflow.md)
