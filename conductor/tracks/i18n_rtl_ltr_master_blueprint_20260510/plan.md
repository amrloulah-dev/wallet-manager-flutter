# Implementation Plan: i18n & RTL/LTR Master Blueprint

## Phase 1: Directionality & Forced RTL/LTR (Axis 1) [checkpoint: 0f78b01]
- [x] Task: Refactor `transaction_overlay_screen.dart`
    - [x] Remove hardcoded `TextDirection.ltr`.
    - [x] Replace manual language checks with `Directionality.of(context)` or `Localizations.localeOf(context)`.
- [x] Task: Strip hardcoded RTL text direction globally
    - [x] Remove `textDirection: TextDirection.rtl` from `paywall_screen.dart`, `subscription_details_screen.dart`, `payment_success_modal.dart`, `payment_modal_screen.dart`, `admin_block_screen.dart`, `subscription_banner.dart`, `custom_text_field.dart`, `wallet_stats_card.dart`, and `wallet_limit_bar.dart`.
- [x] Task: Global Audit for Forced Directionality
    - [x] Search for `TextDirection.rtl` and `TextDirection.ltr` across `lib/presentation/`.
    - [x] Remove forced directionality unless strictly required for specific bidirectional text spans.
- [x] Task: Conductor - User Manual Verification 'Directionality & Forced RTL/LTR (Axis 1)' (Protocol in workflow.md)

## Phase 2: Physical to Logical Layout Migration (Axis 2) [checkpoint: 4598d0b]
- [x] Task: Convert `EdgeInsets` to `EdgeInsetsDirectional`
    - [x] Convert all `EdgeInsets.fromLTRB` to `EdgeInsetsDirectional.fromSTEB` across the project.
    - [x] Convert all `EdgeInsets.only(right: X, left: Y)` to `EdgeInsetsDirectional.only(end: X, start: Y)` across the project.
- [x] Task: Convert `Positioned` to `PositionedDirectional`
    - [x] Convert `Positioned(...)` widgets using `left`/`right` properties to `PositionedDirectional(...)` using `start`/`end`.
- [x] Task: Update Icon Directionality
    - [x] Add `matchTextDirection: true` to all `Icons.arrow_forward_ios` and `Icons.arrow_forward_ios_rounded` icons.
- [x] Task: Conductor - User Manual Verification 'Physical to Logical Layout Migration (Axis 2)' (Protocol in workflow.md)

## Phase 3: Formatting, Dates, and L10n Cleanups (Axis 3)
- [x] Task: Refactor Currency Formatting
    - [x] Remove hardcoded `' EGP'` concatenations in `create_transaction_screen.dart` and `transaction_overlay_screen.dart`.
- [x] Task: DateHelper & Date Formatting Refactor
    - [x] Update `format = 'dd/MM/yyyy'` in `lib/core/utils/date_helper.dart` to use `DateFormat.yMd(locale)`.
    - [x] Replace `.toString().split(' ')[0]` with `DateFormat.yMd(Localizations.localeOf(context).languageCode).format(date)` in `dashboard_quick_stats.dart`, `subscription_details_screen.dart`, and `employee_details_screen.dart`.
- [x] Task: Fix ARB Files
    - [x] In `app_en.arb`, change the `"loggingIn"` key value to `"Logging in..."`.
    - [x] In `app_en.arb`, remove the hardcoded "EGP" from keys like `"proYearlyPrice"`.
    - [x] Reconcile duplicate/mismatched keys (e.g., `instapay` vs `instaPay`) across both ARB files.
- [x] Task: Extract Hardcoded Strings to ARB
    - [x] Extract `'Wallet Manager'` in `login_landing_screen.dart` to `.arb` files.
    - [x] Extract error strings in `transaction_overlay_screen.dart` to `.arb` files.
    - [x] Extract SnackBar error messages in `payment_modal_screen.dart` and map to `.arb` localized strings.
- [x] Task: Conductor - User Manual Verification 'Formatting, Dates, and L10n Cleanups (Axis 3)' (Protocol in workflow.md)