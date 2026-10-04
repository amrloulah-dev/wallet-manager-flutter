# Spec: Optimistic Validation for Receive Transactions

## Overview
Upgrade the `CreateTransactionScreen` UX to implement an enterprise-grade "Optimistic Validation" system for Receive transactions. This provides real-time visual feedback based on the wallet's dynamic capacity limit, including a color-coded amount field, a "Max" auto-fill button, and a 3-zone animated progress bar.

**Scope constraint:** No modifications to `TransactionProvider` or existing Firestore logic. Changes are limited to the UI/state management within `CreateTransactionScreen` and new convenience getters on `WalletModel`.

## Functional Requirements

### FR-1: Real-Time Amount Validation with Color Feedback

**FR-1.1: Calculate `maxAvailable`**
- For all **Receive** transactions, calculate:
  ```
  maxAvailable = min(wallet.availableToReceiveDaily, wallet.availableToReceiveMonthly)
  ```
  These are **new** computed getters on `WalletModel` (see FR-4) that encapsulate the dual-constraint logic (flow limits vs. balance capacity). The UI must **not** redefine or duplicate this calculation.
- For **InstaPay** wallets: Same formula, but `availableToReceiveMonthly` returns pure flow remaining (no balance capacity deduction), since InstaPay bypasses capacity constraints.
- For **Send** transactions: No change — existing validation behavior is preserved.

**FR-1.2: Visual State (Border & Submit Button)**
- **Telecom wallets (Receive):**
  - If `enteredAmount > maxAvailable`: Amount `TextFormField` border and text color turn **Red**. The "إنشاء المعاملة" Submit button is **disabled**.
  - If `enteredAmount <= maxAvailable`: Normal styling. Submit button is **enabled**.
- **InstaPay wallets (Receive):**
  - If `enteredAmount > maxAvailable`: Amount field border turns **Orange/Amber**. Submit button **remains enabled** (soft warning).
  - A warning text banner is shown below/within the field.

**FR-1.3: Contextual Error Text (Dynamic Feedback)**
- When `enteredAmount > maxAvailable`, the `errorText` of the `TextFormField` dynamically explains *which* limit was breached, evaluated in strict order:
  1. If `enteredAmount > wallet.availableToReceiveDaily` → Show: "يتجاوز الحد اليومي" (Exceeds daily limit).
  2. Else if `enteredAmount > wallet.availableToReceiveMonthly` → Show: "يتجاوز الحد الشهري أو سعة المحفظة" (Exceeds monthly limit or wallet capacity).
- For InstaPay, same text logic but displayed as a **warning** (orange styling) rather than a hard block (red styling).

**FR-1.4: Rebuild Optimization**
- Validation state changes must be isolated using `ValueListenableBuilder` on the `_amountController` to prevent full-form rebuilds. Typing in the text field must not cause lag.

### FR-2: "Max" Button

**FR-2.1: Placement**
- A `TextButton` or `IconButton` labeled "Max" (الحد الأقصى) is injected inside the `suffixIcon` of the amount `TextFormField`.

**FR-2.2: Behavior**
- Only visible/active for **Receive** transactions.
- When tapped, auto-populates `_amountController` with the formatted `maxAvailable` value.
- Triggers validation immediately after population.

### FR-3: 3-Zone Dynamic Progress Bar

**FR-3.1: Zone Layout (Receive transactions on e-wallets)**
- Replaces the current `WalletLimitBar` for **Receive** transactions on telecom wallets.
- Displays a `Row` of `AnimatedContainer` widgets representing 3 zones:
  - **Zone 1 (Used):** Red/Dark. Represents `receiveLimits.monthlyUsed`.
  - **Zone 2 (Available):** Green. Represents `maxAvailable`.
  - **Zone 3 (Blocked by Balance):** Grey/Hatched. Represents space unavailable due to the existing wallet balance. Calculated as `receiveLimits.monthlyLimit - (receiveLimits.monthlyUsed + maxAvailable)`.
- **Math constraint:** Total width = `receiveLimits.monthlyLimit`. `Zone1 + Zone2 + Zone3 = monthlyLimit`.

**FR-3.2: Animation**
- Zones use `AnimatedContainer` with:
  - Duration: `300ms`
  - Curve: `Curves.easeOutCubic`
- Zones smoothly resize as the user types.
- The progress bar widget is wrapped in a `ValueListenableBuilder` on `_amountController` to isolate rebuilds from the rest of the form.

**FR-3.3: Fallback (InstaPay / Send)**
- For **InstaPay** wallets or **Send** transaction types: Revert to the standard 2-zone progress bar (Used vs. Remaining) without the Grey/Blocked zone.

### FR-4: WalletModel Domain Getters

- **New getters to add to `WalletModel`:**
  - `bool get isInstaPay => walletType == WalletType.instaPay`
  - `double get availableToReceiveDaily` — For telecom wallets: `receiveLimits.dailyRemaining`. For InstaPay: same (flow-only).
  - `double get availableToReceiveMonthly` — For telecom wallets: `min(receiveLimits.monthlyRemaining, monthlyLimit - balance)` (the lesser of the flow remaining and the balance-capacity remaining). For InstaPay: `receiveLimits.monthlyRemaining` (flow-only, no balance capacity deduction).
- The UI **must strictly consume** `wallet.availableToReceiveDaily` and `wallet.availableToReceiveMonthly` rather than accessing `receiveLimits` directly for validation logic.

## Non-Functional Requirements

- **NFR-1: Performance** — No UI jank. All validation-driven rebuilds are isolated to the relevant widgets via `ValueListenableBuilder`.
- **NFR-2: Localization** — All new user-facing strings must have Arabic entries in `app_ar.arb` and English entries in `app_en.arb`. If `.arb` injection is not immediately feasible, hardcode Arabic strings as fallback.
- **NFR-3: No Provider/Firestore Changes** — `TransactionProvider`, `TransactionValidatorService`, and all Firestore logic remain untouched.

## Acceptance Criteria

- [ ] AC-1: Entering an amount > `maxAvailable` on a telecom Receive transaction turns the field Red with contextual error text and disables Submit.
- [ ] AC-2: Entering an amount > `maxAvailable` on an InstaPay Receive transaction turns the field Orange/Amber with warning text; Submit remains enabled.
- [ ] AC-3: Error text correctly identifies daily vs. monthly limit breach.
- [ ] AC-4: "Max" button appears only for Receive transactions, fills `maxAvailable`, and triggers validation.
- [ ] AC-5: 3-zone progress bar renders correctly for telecom Receive with animated transitions.
- [ ] AC-6: InstaPay Receive and all Send transactions show standard 2-zone bar.
- [ ] AC-7: Typing in the amount field is responsive with no observable lag.
- [ ] AC-8: All new strings are localized in Arabic (and English if applicable).
- [ ] AC-9: `WalletModel.availableToReceiveMonthly` correctly factors in balance capacity for telecom wallets.

## Out of Scope

- Modifications to `TransactionProvider` or `TransactionValidatorService`.
- Server-side validation changes.
- Changes to the Send transaction flow beyond preserving existing behavior.
- Introduction of new Firestore fields (e.g., `maxBalance`/`balanceCapacity`).
