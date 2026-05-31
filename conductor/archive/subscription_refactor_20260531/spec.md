# Specification: Subscription & Monetization Refactor

## Overview
This track addresses 6 critical modifications related to the application's subscription logic, upgrade user experience (UX), pricing and marketing copy, and accurate data presentation. The main goal is to protect premium features, improve the paywall experience, fix bugged stats, and add clear indications of subscription expiry.

## Functional Requirements

### 1. Protect Business Logic (SMS Automation)
- The SMS Automation toggle in the Settings Screen must check the user's active subscription status (Trial, Annual, or Lifetime) and expiry.
- If the subscription is active, the toggle works normally.
- If the subscription is expired, the toggle is visually disabled (grayed out or locked).
- **Role Guard:** If a user interacts with a locked toggle:
  - If role is `Employee`: Display a toast "برجاء طلب ترقية الباقة من مالك المتجر" (Please ask the store owner to upgrade the plan). DO NOT route them to the Paywall.
  - If role is `Owner`: Display a toast or dialog stating "هذه الميزة تتطلب ترقية الحساب" and route the user to the Paywall/Upgrade Screen.

### 2. Paywall Pricing & Copywriting
- **Annual Pro Plan:** Update price to 1200 EGP / year. Update features:
  1. قراءة المعاملات تلقائيا
  2. إدارة مرنة حتى 50 محفظة
  3. بناء فريق عمل حتى 20 موظف
  4. دعم فني مخصص
- **Lifetime Plan:** Update price to 2500 EGP. Change "seats remaining" badge to 50. Update features:
  1. قراءة المعاملات تلقائيا
  2. عدد لا نهائي من المحافظ
  3. عدد لا نهائي من الموظفين
  4. أولوية الدعم الفني VIP

### 3. Payment Details Update
- Update the target transfer number for both Vodafone Cash and InstaPay to: `01091264053`.
- In the Checkout UI, change the hint text / label for the transaction receipt number `TextField` from "رقم الإيصال / رقم العملية" to "رقم الهاتف الذي تم التحويل منه".

### 4. Fix Zero Active Wallets/Employees Bug
- In the Subscription Details Screen, remove the reliance on the static `store.stats` object.
- Inject `WalletProvider` and `EmployeeProvider` to get the real-time `.length` of the active wallets and employees lists.
- **Edge Case Handling:** If either provider is in an `isLoading` state, display a loading indicator instead of a hard '0'.

### 5. Dashboard Expiry Banner
- Inject a persistent, non-dismissible banner at the top of the `OwnerDashboard` screen.
- **Logic & Edge Cases:**
  - **Plan == Trial:** ALWAYS show banner.
  - **Plan == Annual AND remaining days <= 14:** Show warning banner.
  - **Plan == Lifetime OR (Annual with > 14 days):** Hide the banner completely.
  - **Days String Formatting (CRITICAL):**
    - If `days > 0`: Display "متبقي [X] أيام..." (or "ينتهي خلال [X] أيام...").
    - If `days == 0`: Display "ينتهي اشتراكك اليوم!" (Expires Today!). Do not show "0 days".
    - If `days < 0`: Display "انتهت صلاحية اشتراكك!" (Subscription Expired!). Do not show negative days.

### 6. Settings Screen Reorganization
- Rename the "الترخيص" section header to "الاشتراكات".
- Keep the existing "اشتراكي" item (routes to Subscription Details).
- Add a new item "باقات الاشتراك" with a premium/star icon directly below it, routing to the Paywall/Upgrade screen.

### 7. Automated Testing
- **Unit Tests:** Must include unit tests for the exact days-remaining calculation logic.
- **Widget Tests:** Must include widget tests to verify the correct rendering of the Dashboard Banner and locked SMS Toggle based on subscription states and user roles.

## Non-Functional Requirements
- Ensure smooth transitions to the Paywall/Upgrade screen.
- Banner must be visually distinct but elegant, matching the app's theme.

## Acceptance Criteria
- SMS Automation toggle behaves correctly based on subscription status and user role.
- Paywall displays correct prices, seats, and marketing copy.
- Manual payment instructions use the new number and updated text field label.
- Subscription details screen shows accurate wallet and employee counts, or loading indicators when fetching.
- Dashboard banner appears, disappears, and adapts text accurately according to the exact business logic and edge cases.
- Settings screen has the new "الاشتراكات" section with both correct items.
- All unit and widget tests pass.

## Out of Scope
- Server-side calculation of `store.stats` (handled client-side).
