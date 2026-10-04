# Specification: UI/Logic Bug-Fix Sweep

## Overview
A targeted bug-fix track to resolve 3 remaining UI/Logic edge cases identified after the database schema refactor. These bugs affect transaction attribution, wallet card display (RTL, scaling, inactive badge), and employee limit validation.

## Type
Bug Fix

## Functional Requirements

### FR-1: Fix Transaction Creator Name ("Unknown" / غير معروف)
- **Affected Area:** Transaction creation flow (`transaction_provider.dart` or equivalent)
- **Current Behavior:** `transaction_details_screen` displays "Unknown" (غير معروف) for the creator because `createdByName` and `creatorRole` are not populated when creating a new transaction.
- **Required Behavior:** When creating a `TransactionModel`, the system MUST:
  1. First check `EmployeeProvider` for the logged-in employee's name and role.
  2. If the user is not an employee (i.e., is the store owner), fall back to `AuthProvider` for the display name and assign the owner role.
  3. Populate both `createdByName` and `creatorRole` fields on the new `TransactionModel` before persisting.

### FR-2: Fix Wallet Card Display (RTL Phone, Scale, Inactive Badge)
- **Affected Areas:** `number_formatter.dart`, `wallet_card.dart`

#### FR-2a: Phone Number RTL Fix
- **Current Behavior:** `formatPhoneNumber` in `number_formatter.dart` uses naive substring concatenation that reverses phone numbers in Arabic (RTL) locales.
- **Required Behavior:** Return the normalized phone number logically. In `wallet_card.dart`, wrap the phone number `Text` widget with `Directionality(textDirection: TextDirection.ltr, child: ...)` to force left-to-right rendering regardless of locale.

#### FR-2b: Card Scale (15% Shrink)
- **Current Behavior:** Wallet cards are rendered at full size.
- **Required Behavior:** Wrap the outermost wallet card container with `Transform.scale(scale: 0.85)` to uniformly shrink the card by 15%. This applies to ALL screen sizes.

#### FR-2c: Inactive Badge Logic Fix
- **Current Behavior:** The inactive/red badge is shown when `wallet.isFrozen` is `true`.
- **Required Behavior:** The red/inactive badge ("غير نشطة") MUST only show when `wallet.walletStatus == WalletStatus.suspended`. Active wallets must NOT display any inactive badge, regardless of `isFrozen` state.

### FR-3: Fix Employee Limit Validation
- **Affected Areas:** `employee_provider.dart`, `subscription_provider.dart`
- **Current Behavior:** `employee_error_max_limit_reached` error is thrown even when the employee count is well below the limit (e.g., `0 / 999`).
- **Required Behavior:** The `canAddEmployee` method in `subscription_provider.dart` MUST return `true` strictly when `currentEmployees < maxLimit`. The conditional check in `addEmployee` (`employee_provider.dart`) must correctly pass the current count and respect the boundary.
- **Testing:** Unit tests MUST be added to verify:
  - Adding is allowed when `currentEmployees == 0` (empty)
  - Adding is allowed when `currentEmployees == maxLimit - 1` (one below)
  - Adding is blocked when `currentEmployees == maxLimit` (at limit)
  - Adding is blocked when `currentEmployees > maxLimit` (over limit)

## Non-Functional Requirements
- No regressions to existing transaction, wallet, or employee flows.
- All fixes must respect the project's RTL/LTR bilingual support.
- Code must follow existing patterns (SafeChangeNotifier, Selector-based rebuilds, O(1) lookups).

## Acceptance Criteria
- [ ] New transactions display the correct creator name and role on the transaction details screen for both owners and employees.
- [ ] Phone numbers on wallet cards render left-to-right in both Arabic and English locales.
- [ ] Wallet cards are uniformly scaled to 85% on all screen sizes.
- [ ] The inactive badge shows ONLY for `WalletStatus.suspended` wallets.
- [ ] Employees can be added when under the subscription limit without errors.
- [ ] Unit tests for employee limit boundary conditions pass.
- [ ] No existing tests are broken.

## Out of Scope
- Redesigning the wallet card layout beyond the specified scale and badge changes.
- Modifying subscription tier logic or pricing.
- Changes to the SMS automation or overlay flows.
- Any database schema modifications.
