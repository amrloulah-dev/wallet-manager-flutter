# Specification: i18n & RTL/LTR Master Blueprint

## Overview
An exhaustive Localization (i18n) and Directionality (RTL/LTR) refactoring for the Wallet Manager application. The application targets the Egyptian market and must flawlessly support both English (LTR) and Arabic (RTL) user interfaces. The core objective is to transition from physical layout constraints and forced directionality to logical constraints and ambient locale propagation.

## Functional Requirements
1. **Directionality & Forced RTL/LTR (Axis 1)**
   - Remove hardcoded `TextDirection.ltr` in `transaction_overlay_screen.dart` and replace manual language checks with `Directionality.of(context)` or `Localizations.localeOf(context)`.
   - Strip `textDirection: TextDirection.rtl` from: `paywall_screen.dart`, `subscription_details_screen.dart`, `payment_success_modal.dart`, `payment_modal_screen.dart`, `admin_block_screen.dart`, `subscription_banner.dart`, `custom_text_field.dart`, `wallet_stats_card.dart`, and `wallet_limit_bar.dart`.
   - Conduct a global audit for `TextDirection.rtl` and `TextDirection.ltr` across `lib/presentation/` and remove unless strictly required for specific bidirectional text spans.
2. **Physical to Logical Layout Migration (Axis 2)**
   - Convert all `EdgeInsets.fromLTRB` and `EdgeInsets.only(right: X, left: Y)` instances to `EdgeInsetsDirectional.fromSTEB` and `EdgeInsetsDirectional.only(end: X, start: Y)` across the project (e.g., `app_drawer.dart`, `wallet_details_screen.dart`, `create_transaction_screen.dart`).
   - Convert `Positioned(...)` widgets using `left`/`right` to `PositionedDirectional(...)` using `start`/`end` (e.g., `wallet_card.dart`, `employee_card.dart`, `paywall_screen.dart`).
   - Add `matchTextDirection: true` to all `Icons.arrow_forward_ios` and `Icons.arrow_forward_ios_rounded` icons.
3. **Formatting, Dates, and L10n Cleanups (Axis 3)**
   - Remove hardcoded `' EGP'` concatenations in `create_transaction_screen.dart` and `transaction_overlay_screen.dart`, relying on `NumberFormatter.formatAmount()`.
   - Replace `.toString().split(' ')[0]` with `DateFormat.yMd(Localizations.localeOf(context).languageCode).format(date)` in `dashboard_quick_stats.dart`, `subscription_details_screen.dart`, and `employee_details_screen.dart`.
   - Update the default `format = 'dd/MM/yyyy'` in `lib/core/utils/date_helper.dart` to align with the current locale using `DateFormat.yMd(locale)`.
   - Fix `app_en.arb` by changing the `"loggingIn"` key value to `"Logging in..."`.
   - In `app_en.arb`, remove the hardcoded "EGP" from keys like `"proYearlyPrice": "999 EGP / year"` to allow programmatical formatting.
   - Extract hardcoded strings (e.g., `'Wallet Manager'` in `login_landing_screen.dart`, error strings in `transaction_overlay_screen.dart`) to `.arb` files.
   - Extract the hardcoded SnackBar error messages in `payment_modal_screen.dart` and map them to `.arb` localized strings.
   - Reconcile duplicate/mismatched keys (e.g., `instapay` vs `instaPay`) across ARB files.
   - **Translations:** Halt and ask the user for specific translations if missing translations or mismatched keys are found during the audit.

## Non-Functional Requirements
1. **Verification & Testing:**
   - Use Flutter's built-in locale override for testing.
   - Manually verify layouts on iOS/Android emulators with RTL languages set.
   - Employ widget tests with `Directionality` wrappers to guarantee no visual regressions occur.

## Acceptance Criteria
- [ ] No layout widget enforces `TextDirection.rtl` or `TextDirection.ltr` globally.
- [ ] `wallet_stats_card.dart` and `wallet_limit_bar.dart` have hardcoded `TextDirection` removed.
- [ ] Zero instances of `EdgeInsets.only(right:...)` or `EdgeInsets.fromLTRB` exist (all converted to `Directional` equivalents).
- [ ] Zero instances of `Positioned` with `left`/`right` exist (all converted to `PositionedDirectional`).
- [ ] All forward/back arrows use `matchTextDirection: true`.
- [ ] Dates are formatted using `DateFormat` with the correct context locale, completely removing `.toString().split(' ')[0]`.
- [ ] `DateHelper` uses `DateFormat.yMd(locale)` instead of hardcoded formats.
- [ ] Concatenated `' EGP'` strings are removed from UI layers to rely on internal formatters.
- [ ] `app_en.arb` is free of Arabic translations, hardcoded "EGP", and hardcoded strings are mapped to ARB keys.
- [ ] SnackBar error messages in `payment_modal_screen.dart` are extracted to ARB keys.

## Out of Scope
- Adding new wallet providers or features not related to i18n/RTL adaptation.
- Refactoring business logic outside of formatting and string mapping.