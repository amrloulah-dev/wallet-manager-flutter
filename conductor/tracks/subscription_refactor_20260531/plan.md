# Implementation Plan: Subscription & Monetization Refactor

## Phase 1: Dashboard Expiry Banner & Utilities
- [ ] Task: Create unit tests for subscription days-remaining calculation and banner logic
- [ ] Task: Implement subscription days-remaining calculation utility
- [ ] Task: Create widget tests for the persistent Expiry Banner rendering and edge cases
- [ ] Task: Implement the Dashboard Expiry Banner UI and inject into `OwnerDashboard`
- [ ] Task: Conductor - User Manual Verification 'Phase 1: Dashboard Expiry Banner & Utilities' (Protocol in workflow.md)

## Phase 2: Protect Business Logic (SMS Automation)
- [ ] Task: Create widget tests for SMS Automation toggle states based on roles and subscription
- [ ] Task: Implement SMS Automation toggle protection logic and Role Guard toasts in Settings Screen
- [ ] Task: Conductor - User Manual Verification 'Phase 2: Protect Business Logic (SMS Automation)' (Protocol in workflow.md)

## Phase 3: Paywall Pricing & Copywriting
- [ ] Task: Update Annual Pro Plan price and features in Paywall Screen
- [ ] Task: Update Lifetime Plan price, seats badge, and features in Paywall Screen
- [ ] Task: Conductor - User Manual Verification 'Phase 3: Paywall Pricing & Copywriting' (Protocol in workflow.md)

## Phase 4: Payment Details Update
- [ ] Task: Update target transfer number to `01091264053` for Vodafone Cash and InstaPay
- [ ] Task: Update Checkout UI text field hint/label to "رقم الهاتف الذي تم التحويل منه"
- [ ] Task: Conductor - User Manual Verification 'Phase 4: Payment Details Update' (Protocol in workflow.md)

## Phase 5: Fix Zero Active Wallets/Employees Bug
- [ ] Task: Refactor Subscription Details Screen to use `WalletProvider` and `EmployeeProvider` lengths instead of `store.stats`
- [ ] Task: Implement loading indicator handling for provider `isLoading` states
- [ ] Task: Conductor - User Manual Verification 'Phase 5: Fix Zero Active Wallets/Employees Bug' (Protocol in workflow.md)

## Phase 6: Settings Screen Reorganization
- [ ] Task: Rename "الترخيص" to "الاشتراكات" in Settings Screen
- [ ] Task: Add "باقات الاشتراك" item routing to Paywall
- [ ] Task: Conductor - User Manual Verification 'Phase 6: Settings Screen Reorganization' (Protocol in workflow.md)
