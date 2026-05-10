# Implementation Plan: i18n & RTL/LTR Master Blueprint

## Phase 1: Directionality & Forced RTL/LTR (Axis 1)
- [ ] Task: Refactor `transaction_overlay_screen.dart`
    - [ ] Remove hardcoded `TextDirection.ltr`.
    - [ ] Replace manual language checks with `Directionality.of(context)` or `Localizations.localeOf(context)`.
- [ ] Task: Strip hardcoded RTL text direction globally
    - [ ] Remove `textDirection: TextDirection.rtl` from `paywall_screen.dart`, `subscription_details_screen.dart`, `payment_success_modal.dart`, `payment_modal_screen.dart`, `admin_block_screen.dart`, `subscription_banner.dart`, `custom_text_field.dart`, `wallet_stats_card.dart`, and `wallet_limit_bar.dart`.
- [ ] Task: Global Audit for Forced Directionality
    - [ ] Search for `TextDirection.rtl` and `TextDirection.ltr` across `lib/presentation/`.
    - [ ] Remove forced directionality unless strictly required for specific bidirectional text spans.
- [ ] Task: Conductor - User Manual Verification 'Directionality & Forced RTL/LTR (Axis 1)' (Protocol in workflow.md)

## Phase 2: Physical to Logical Layout Migration (Axis 2)
- [ ] Task: Convert `EdgeInsets` to `EdgeInsetsDirectional`
    - [ ] Convert all `EdgeInsets.fromLTRB` to `EdgeInsetsDirectional.fromSTEB` across the project.
    - [ ] Convert all `EdgeInsets.only(right: X, left: Y)` to `EdgeInsetsDirectional.only(end: X, start: Y)` across the project.
- [ ] Task: Convert `Positioned` to `PositionedDirectional`
    - [ ] Convert `Positioned(...)` widgets using `left`/`right` properties to `PositionedDirectional(...)` using `start`/`end`.
- [ ] Task: Update Icon Directionality
    - [ ] Add `matchTextDirection: true` to all `Icons.arrow_forward_ios` and `Icons.arrow_forward_ios_rounded` icons.
- [ ] Task: Conductor - User Manual Verification 'Physical to Logical Layout Migration (Axis 2)' (Protocol in workflow.md)

## Phase 3: Formatting, Dates, and L10n Cleanups (Axis 3)
- [ ] Task: Refactor Currency Formatting
    - [ ] Remove hardcoded `' EGP'` concatenations in `create_transaction_screen.dart` and `transaction_overlay_screen.dart`.
- [ ] Task: DateHelper & Date Formatting Refactor
    - [ ] Update `format = 'dd/MM/yyyy'` in `lib/core/utils/date_helper.dart` to use `DateFormat.yMd(locale)`.
    - [ ] Replace `.toString().split(' ')[0]` with `DateFormat.yMd(Localizations.localeOf(context).languageCode).format(date)` in `dashboard_quick_stats.dart`, `subscription_details_screen.dart`, and `employee_details_screen.dart`.
- [ ] Task: Fix ARB Files
    - [ ] In `app_en.arb`, change the `"loggingIn"` key value to `"Logging in..."`.
    - [ ] In `app_en.arb`, remove the hardcoded "EGP" from keys like `"proYearlyPrice"`.
    - [ ] Reconcile duplicate/mismatched keys (e.g., `instapay` vs `instaPay`) across both ARB files.
- [ ] Task: Extract Hardcoded Strings to ARB
    - [ ] Extract `'Wallet Manager'` in `login_landing_screen.dart` to `.arb` files.
    - [ ] Extract error strings in `transaction_overlay_screen.dart` to `.arb` files.
    - [ ] Extract SnackBar error messages in `payment_modal_screen.dart` and map to `.arb` localized strings.
- [ ] Task: Conductor - User Manual Verification 'Formatting, Dates, and L10n Cleanups (Axis 3)' (Protocol in workflow.md)