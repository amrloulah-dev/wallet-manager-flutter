# Phase 10: Exhaustive Localization (i18n) & Directionality Audit Report

## 🚨 CRITICAL PRIORITY: Hardcoded Arabic Strings in Business Logic & Services
The most severe violation of i18n principles found is the hardcoding of Arabic strings directly into backend services, validation layers, and exception throwing. These will completely break if the user switches to English.

### 1. Data Services & Exceptions (`lib/data/services/`)
*   **`transaction_validator_service.dart`**: Contains dozens of hardcoded exception messages.
    *   *Examples:* `'المحفظة غير موجودة.'`, `'لا يمكن إجراء معاملة: المحفظة غير مفعلة أو تم حذفها'`, `'الحد الأقصى للمعاملة الواحدة لإنستاباي هو 70,000 جنيه.'`
*   **`google_sign_in_service.dart`**: Authentication errors are hardcoded.
    *   *Examples:* `'فشل تسجيل الدخول باستخدام جوجل: ${e.message}'`, `'حدث خطأ غير متوقع أثناء تسجيل الدخول.'`
*   **`migration_service.dart`**:
    *   *Examples:* `'فشل إعادة حساب الإحصائيات: ${e.message}'`

### 2. State Management & Extensions (`lib/providers/` & `lib/presentation/utils/`)
*   **`theme_provider.dart`**: Returns raw Arabic strings for theme names.
    *   *Examples:* `'فاتح'` (Light), `'غامق'` (Dark), `'حسب النظام'` (System).
*   **`wallet_extensions.dart`**: Extension methods explicitly return Arabic names instead of taking a BuildContext for `AppLocalizations` lookup.
    *   *Wallet Names:* `'فودافون كاش'`, `'إنستاباي'`, `'أورانج كاش'`, etc.
    *   *Wallet Status:* `'نشطة'`, `'غير نشطة'`, `'معلقة'`.

---

## ⚠️ MEDIUM PRIORITY: Hardcoded RTL Directionality Constraints (Physical Layouts)
Several UI components use "physical" layout constraints (`left`/`right`) instead of "logical" directional constraints (`start`/`end`). When the app switches between LTR (English) and RTL (Arabic), these UI elements will not mirror correctly, leading to broken padding and misaligned corners.

### 1. Padding & Margins (`EdgeInsets.only`)
*   **`partial_payment_bottom_sheet.dart`** (Lines 112-113): `left: 16`, `right: 16`.
*   **`login_landing_screen.dart`** (Lines 404-405): `left: 24`, `right: 24`.
    *   *Recommendation:* Must be migrated to `EdgeInsetsDirectional.only(start: ..., end: ...)`.

### 2. Border Radii (`BorderRadius.only`)
*   **`debts_list_screen.dart`** (Lines 115-116): Uses `topLeft: Radius.circular(20)` and `topRight: Radius.circular(20)`.
*   **`toast_utils.dart`** (Lines 124-125): Uses `topRight` and `bottomRight`. If this toast is designed to hug one edge of the screen, it will fail to flip in English.
    *   *Recommendation:* Must be migrated to `BorderRadiusDirectional.only(topStart: ..., bottomEnd: ...)`.

### 3. Visual Gradients (`Alignment`)
*   **`paywall_screen.dart`** (Lines 146-147): Uses `begin: Alignment.topLeft`, `end: Alignment.bottomRight`.
    *   *Recommendation:* Consider `AlignmentDirectional.topStart` to `AlignmentDirectional.bottomEnd` if the gradient flow should mirror the reading direction.

---

## 🟡 LOW PRIORITY: Locale-Specific Formatting & Hardcoded Symbols
While technically functional in Arabic, the current formatting approaches bypass standard ICU locale capabilities, leading to brittle localization switching.

### 1. Currency Formatting overrides
*   **`localization_provider.dart`** (Line 43): 
    ```dart
    final currencySymbol = languageCode == 'ar' ? 'ج' : 'EGP';
    ```
    *   *Issue:* The currency symbol is being manually patched based on a string check. This should ideally be handled intrinsically by the `NumberFormat.simpleCurrency(locale: 'ar_EG')` from the `intl` package.

### 2. Untranslated UI labels passing directly to Widgets
*   **`wallet_limit_bar.dart`** (Line 7): Comment indicates usage `// e.g. 'إرسال يومي'`. Need to ensure the parent passing this label is pulling from `.arb` files.

---

## 📋 Recommended Remediation Plan
1. **ARB Key Generation:** We need to harvest every Arabic string found in the services and extensions, generate equivalent camelCase keys, and inject them into `app_ar.arb` and `app_en.arb`.
2. **Context Injection:** Modify services (like `TransactionValidatorService`) to either accept `BuildContext` (less ideal for Clean Architecture) OR throw specific strongly-typed error codes (e.g., `'error_wallet_not_found'`) that the Presentation layer catches and translates via `AppLocalizations.of(context)`.
3. **Geometry Replacement:** Execute a global regex replace for `EdgeInsets.only(left: \d+, right: \d+)` with `EdgeInsets.symmetric(horizontal: ...)` or `EdgeInsetsDirectional.only(start: ..., end: ...)`.
4. **Formatter Standardization:** Upgrade `currency_formatter.dart` to strictly rely on standard `intl` features initialized at app boot.
