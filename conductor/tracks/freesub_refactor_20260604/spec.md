# Specification: Monetization & Business Logic Refactor (freesub_refactor)

## Overview
This track addresses key tasks in the "Monetization & Business Logic" phase. It aims to enforce subscription rules on premium features (like SMS Automation), update paywall pricing and features details, fix display bugs and prevent flickering in the Subscription Details screen, add a subscription expiry banner to the dashboard, and reorganize the Settings navigation.

## Functional Requirements

### 1. SMS Automation Subscription Guarding (Task 1)
- Restrict the SMS Automation toggle in Settings Screen (`sms_automation_section.dart`) to users with active subscriptions (Trial, Annual Pro, or Lifetime VIP).
- If the subscription is expired (Trial ended, Annual expired) and the user is an owner, tapping the switch must:
  - Trigger a light haptic feedback vibration (`HapticFeedback.lightImpact()`).
  - Display a localized error/toast: "هذه الميزة تتطلب ترقية الحساب" / "This feature requires a plan upgrade".
  - Route the user to the Paywall Screen (`RouteConstants.upgradeScreen`).
- If the user is an employee, display: "يرجى طلب ترقية الحساب من صاحب المحل" / "Please request a plan upgrade from the store owner".
- The toggle switch must be visually disabled (grayed out) when the subscription is expired.

### 2. Paywall Pricing & Copywriting (Task 2)
- In `paywall_screen.dart`:
  - Update the Annual Pro Plan price to "1200 جنيه / سنة" (Arabic) and "1200 EGP / year" (English).
  - Update features for Annual Pro Plan exactly to:
    1. قراءة المعاملات تلقائيا (Auto-sync transactions)
    2. إدارة مرنة حتى 50 محفظة (Flexible management of up to 50 wallets)
    3. بناء فريق عمل حتى 20 موظف (Build a team of up to 20 employees)
    4. دعم فني مخصص (Dedicated technical support)
  - Update the Lifetime VIP Plan price to "2500 EGP" / "2500 جنيه فقط مرة واحدة".
  - Change the "seats remaining" badge/limit default to 50.
  - Update features for Lifetime Plan exactly to:
    1. قراءة المعاملات تلقائيا (Auto-sync transactions)
    2. عدد لا نهائي من المحافظ (Unlimited wallets)
    3. عدد لا نهائي من الموظفين (Unlimited employees)
    4. أولوية الدعم الفني VIP (VIP priority support)

### 3. Payment Details Update (Task 3)
- In `payment_modal_screen.dart` / Manual Checkout:
  - Set the target transfer phone number to `01091264053` for both Vodafone Cash and InstaPay instructions.
  - Replace the receipt number TextFormField with a phone number field.
  - Change its label/hint text to "رقم الهاتف الذي تم التحويل منه" (Arabic) and "The phone number you transferred from" (English).
  - Use phone number validation for this field instead of general receipt string validation.

### 4. Fix Zero Active Wallets/Employees & Prevent Flickering (Task 4)
- In `subscription_details_screen.dart`:
  - Convert the screen to a `StatefulWidget`.
  - In `initState`, check if the list of wallets or employees is empty/initial. If so, trigger the fetch/sync functions from `WalletProvider` and `EmployeeProvider` to ensure the counters are populated on first launch.
  - Read the real-time active wallets length and employee count from the provider lists.
  - **Flickering Prevention (Loading Indicator):** If `WalletProvider` or `EmployeeProvider` is in an `isLoading` state or has not yet loaded (e.g. `WalletProviderStatus.idle` with empty wallets or `EmployeeProviderStatus.initial`), display a loading indicator (`CircularProgressIndicator`) instead of a hard '0'.

### 5. Dashboard Expiry Banner & Edge Cases (Task 5)
- In `main_dashboard_screen.dart` (Dashboard):
  - Display a persistent, non-dismissible `SubscriptionBanner` at the top of the dashboard.
  - If the plan is Trial, always show the banner: "متبقي [X] أيام على انتهاء الفترة التجريبية. قم بالترقية الآن!" (Arabic) / "Only [X] days left on your trial. Upgrade now!" (English).
  - If the plan is Annual Pro and remaining days is <= 14, show the warning banner: "اشتراكك السنوي ينتهي خلال [X] أيام. جدد الآن!" (Arabic) / "Your annual subscription expires in [X] days. Renew now!" (English).
  - If the plan is Lifetime or Annual Pro with > 14 days remaining, hide the banner.
  - **Days Formatting Edge Cases:**
    - If remaining days `days == 0`: Display "ينتهي اشتراكك اليوم!" (Arabic) / "Your subscription expires today!" (English). Do NOT show "0 days".
    - If remaining days `days < 0`: Display "انتهت صلاحية اشتراكك!" (Arabic) / "Your subscription has expired!" (English). Do NOT show negative numbers.

### 6. Settings Screen Reorganization (Task 6)
- Rename the Settings section header from "الترخيص" (License) to "الاشتراكات" (Subscriptions).
- Ensure the "My Subscription" ("اشتراكي") tile exists and routes to `subscriptionDetails`.
- Add a new "Subscription Plans" ("باقات الاشتراك") tile directly below it with a star/premium icon that routes to `RouteConstants.upgradeScreen` (Paywall Screen).

### 7. Security & Freemium Limits Enforcement (Task 7)
- **Resource Limits:** Update the expired/free-tier limit for Wallets to exactly 2, and Employees to exactly 0.
- **Anti-Cycling Lock:** If the store subscription is expired, block the "Edit" and "Delete" actions for existing Wallets in both details screen and lists. When a user attempts to edit or delete, show a toast: "أنت على الخطة المجانية. لإدارة وإعادة هيكلة محافظك برجاء الترقية" (Arabic) / "You are on the free plan. Please upgrade to manage and restructure your wallets" (English) and route them to the Paywall Screen. (Note: Adding balance must remain unrestricted).
- **Employee Login Guard:** If an employee tries to log in and the store subscription is expired (employee limit is 0), abort the login during submission and show a toast: "تم إيقاف صلاحيات الدخول مؤقتا. برجاء التواصل مع مالك المتجر لتجديد الاشتراك." (Arabic) / "Access permissions have been temporarily suspended. Please contact the store owner to renew the subscription." (English). Do NOT route to the legacy hard-block screen.

## Non-Functional Requirements
- **Performance:** Rebuilds should be optimized; use granular selectors where possible.
- **RTL/LTR Layout mirroring:** Support mirroring for Arabic and English locales.
- **Vibration:** Haptic feedback must be integrated safely without crashing if running on platforms without vibrators.

## Acceptance Criteria
- SMS toggle displays grayed out when expired, vibrates, toasts, and redirects on tap.
- Paywall displays correct prices (1200 EGP, 2500 EGP) and feature bullet points.
- Payment modal displays `01091264053` and asks for the sender phone number.
- Subscription details screen shows accurate active wallets/employees counters on load.
- Expiry banner shows up on Dashboard with accurate remaining days under specified conditions, handles 0 and negative days correctly, and hides otherwise.
- Settings screen navigation and titles match updated specifications.
- Expired/free plan restricts wallets to 2 and employees to 0.
- Wallet edit and delete actions are blocked with a toast and paywall redirect when expired.
- Employee login is aborted with a toast when store subscription is expired.
- All unit and widget tests pass.

## Out of Scope
- Direct automated credit card integration (payment is manual transfer).
- Advanced analytics dashboards.
