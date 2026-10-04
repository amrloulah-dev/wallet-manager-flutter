# 🚀 Wallet Manager - i18n & RTL/LTR Master Blueprint (Phase 10)

## 📌 1. General Context & Strict System Prompt
**To the AI Agent (Antigravity / Gemini CLI):**
You are performing an exhaustive Localization (i18n) and Directionality (RTL/LTR) refactoring for "Wallet Manager". The application is exclusively for the Egyptian market, but it must perfectly support both English (LTR) and Arabic (RTL) UIs.
**Core Constraints:**
1. **No Forced Directionality:** Never hardcode `TextDirection.ltr` or `TextDirection.rtl` on layout components. Always rely on the ambient `Directionality.of(context)` or `Localizations.localeOf(context)`.
2. **Logical Over Physical Layouts:** Physical constraints (`left`, `right`, `LTRB`) are strictly forbidden. You must use logical constraints (`start`, `end`, `STEB`) for all margins, padding, and positioning.
3. **GLOBAL AUDIT DIRECTIVE:** For every axis fixed, scan the entire `lib/` directory to ensure no physical constraints or hardcoded directions remain.

---

## 📌 2. CRITICAL: Directionality & Forced RTL/LTR (Axis 1)

### Context
Various screens and overlays bypass the Flutter locale propagation pipeline by hardcoding `TextDirection`, causing broken layouts (e.g., Arabic users seeing LTR amounts, or English users seeing mirrored RTL screens).

### The Fix (Surgical + Global Audit)
1. **Overlay Fixes:** In `transaction_overlay_screen.dart`, remove the hardcoded `TextDirection.ltr` on the amount Text. Replace the manual language check (`languageCode != 'en'`) with proper dependency on `Directionality.of(context)` or `Localizations.localeOf(context)`.
2. **Remove Forced RTL:** Strip `textDirection: TextDirection.rtl` from `paywall_screen.dart`, `subscription_details_screen.dart`, `payment_success_modal.dart`, `payment_modal_screen.dart`, `admin_block_screen.dart`, `subscription_banner.dart`, and `custom_text_field.dart`.
3. **Global Audit:** Grep for `TextDirection.rtl` and `TextDirection.ltr` across `lib/presentation/`. Remove them unless strictly required for specific bidirectional text spans.

---

## 📌 3. HIGH: Physical to Logical Layout Migration (Axis 2)

### Context
The UI uses absolute physical coordinates (`left`, `right`) causing content to overlap or misalign when the system locale changes to Arabic (RTL).

### The Fix (Surgical + Global Audit)
1. **EdgeInsets Migration:** Convert all instances of `EdgeInsets.fromLTRB` to `EdgeInsetsDirectional.fromSTEB`. Convert all `EdgeInsets.only(right: X, left: Y)` to `EdgeInsetsDirectional.only(end: X, start: Y)`. (Targets include `app_drawer.dart`, `wallet_details_screen.dart`, `create_transaction_screen.dart`, etc.).
2. **Positioned Migration:** Convert `Positioned(...)` widgets using `left`/`right` properties to `PositionedDirectional(...)` using `start`/`end` properties (Targets: `wallet_card.dart`, `employee_card.dart`, `paywall_screen.dart`).
3. **Directional Icons:** Add `matchTextDirection: true` to all `Icons.arrow_forward_ios` and `Icons.arrow_forward_ios_rounded` so they correctly point left in RTL mode.

---

## 📌 4. MEDIUM: Formatting, Dates, and L10n Cleanups (Axis 3)

### Context
Dates are parsed using `.toString().split(' ')[0]` avoiding localization, currencies have duplicated 'EGP' suffixes, and ARB files contain mismatched or hardcoded fallback strings.

### The Fix (Surgical + Global Audit)
1. **Currency Suffix Fix:** In `create_transaction_screen.dart` and `transaction_overlay_screen.dart`, remove the hardcoded string concatenation of `' EGP'` (e.g., `'$amount EGP'`). Rely purely on `NumberFormatter.formatAmount()` to prevent duplicated `"1,000.00 EGP EGP"` outputs.
2. **Date Localization:** In `dashboard_quick_stats.dart`, `subscription_details_screen.dart`, and `employee_details_screen.dart`, replace fragile `.toString()` parsing with proper `intl` formatting: `DateFormat.yMd(Localizations.localeOf(context).languageCode).format(date)`.
3. **ARB Cleanup:** - Fix `app_en.arb`: Change the `"loggingIn"` key value from Arabic text to `"Logging in..."`.
    - Extract hardcoded strings like `'Wallet Manager'` (in `login_landing_screen.dart`) and hardcoded Arabic/English error strings (in `transaction_overlay_screen.dart`) into `.arb` keys.
    - Reconcile duplicate/mismatched keys (e.g., `instapay` vs `instaPay`) across both ARB files.

---

## 📌 Acceptance Criteria
- [ ] No layout widget enforces `TextDirection.rtl` or `TextDirection.ltr` globally.
- [ ] Zero instances of `EdgeInsets.only(right:...)` or `EdgeInsets.fromLTRB` exist (all converted to `Directional` equivalents).
- [ ] Zero instances of `Positioned` with `left`/`right` exist (all converted to `PositionedDirectional`).
- [ ] All forward/back arrows use `matchTextDirection: true`.
- [ ] Dates are formatted using `DateFormat` with the correct context locale, completely removing `.toString().split(' ')[0]`.
- [ ] Concatenated `' EGP'` strings are removed from UI layers to rely on internal formatters.
- [ ] `app_en.arb` is free of Arabic translations and hardcoded strings are mapped to ARB keys.