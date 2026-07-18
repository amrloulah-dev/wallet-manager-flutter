# Implementation Plan: Optimistic Validation for Receive Transactions

## Phase 1: Domain Layer — WalletModel Getters (FR-4) [checkpoint: ed928e4]

- [x] Task: Write Tests — `isInstaPay` getter (2797c4b)
    - [x] Create test file `test/data/models/wallet_model_receive_getters_test.dart`
    - [x] Test `isInstaPay` returns `true` for `WalletType.instaPay` and `false` for all other `WalletType` values
    - [x] Run tests and confirm they fail (Red)

- [x] Task: Implement — `isInstaPay` getter (2797c4b)
    - [x] Add `bool get isInstaPay => walletType == WalletType.instaPay;` to `WalletModel`
    - [x] Run tests and confirm they pass (Green)

- [x] Task: Write Tests — `availableToReceiveDaily` getter (2797c4b)
    - [x] Test returns `receiveLimits.dailyRemaining` for telecom wallets
    - [x] Test returns `receiveLimits.dailyRemaining` for InstaPay wallets
    - [x] Test returns `0.0` when daily limit is fully used
    - [x] Run tests and confirm they fail (Red)

- [x] Task: Implement — `availableToReceiveDaily` getter (2797c4b)
    - [x] Add `double get availableToReceiveDaily` to `WalletModel` returning `receiveLimits.dailyRemaining`
    - [x] Run tests and confirm they pass (Green)

- [x] Task: Write Tests — `availableToReceiveMonthly` getter (2797c4b)
    - [x] Test for telecom wallets: returns `min(receiveLimits.monthlyRemaining, monthlyLimit - balance)` — the lesser of flow remaining and balance-capacity remaining
    - [x] Test for telecom wallets: when balance is high, capacity constrains below flow limit
    - [x] Test for telecom wallets: when flow is low, flow constrains below capacity
    - [x] Test for InstaPay wallets: returns `receiveLimits.monthlyRemaining` (pure flow, no balance deduction)
    - [x] Test returns `0.0` when monthly limit is fully used
    - [x] Run tests and confirm they fail (Red)

- [x] Task: Implement — `availableToReceiveMonthly` getter (2797c4b)
    - [x] Add `double get availableToReceiveMonthly` to `WalletModel` with dual-constraint logic for telecom and flow-only for InstaPay
    - [x] Run tests and confirm they pass (Green)

- [x] Task: Conductor - User Manual Verification 'Phase 1: Domain Layer' (Protocol in workflow.md) (ed928e4)

## Phase 2: Localization — New ARB Strings (NFR-2) [checkpoint: dc1741c]

- [x] Task: Add localization strings to `app_ar.arb` and `app_en.arb` (b737ff9)
    - [x] Add `exceedsDailyLimit`: "يتجاوز الحد اليومي" / "Exceeds daily limit"
    - [x] Add `exceedsMonthlyLimitOrCapacity`: "يتجاوز الحد الشهري أو سعة المحفظة" / "Exceeds monthly limit or wallet capacity"
    - [x] Add `maxButtonLabel`: "الحد الأقصى" / "Max"
    - [x] Add `zoneUsedLabel`, `zoneAvailableLabel`, `zoneBlockedLabel` for progress bar zone labels
    - [x] Run `flutter gen-l10n` and verify generation succeeds

- [x] Task: Conductor - User Manual Verification 'Phase 2: Localization' (Protocol in workflow.md) (dc1741c)

## Phase 3: UI — Amount Field Validation & Max Button (FR-1, FR-2) [checkpoint: 9336930]

- [x] Task: Write Tests — Amount validation color feedback (6d40caf)
    - [x] Create test file `test/presentation/screens/transactions/create_transaction_validation_test.dart`
    - [x] Test: telecom Receive with amount > `maxAvailable` → Red border, Submit disabled
    - [x] Test: telecom Receive with amount <= `maxAvailable` → normal border, Submit enabled
    - [x] Test: InstaPay Receive with amount > `maxAvailable` → Orange border, Submit enabled
    - [x] Test: contextual error text shows daily message when daily limit breached
    - [x] Test: contextual error text shows monthly/capacity message when monthly limit breached
    - [x] Run tests and confirm they fail (Red)

- [x] Task: Implement — Amount validation with `ValueListenableBuilder` (6d40caf)
    - [x] Add `_maxAvailable` calculation method consuming `wallet.availableToReceiveDaily` and `wallet.availableToReceiveMonthly`
    - [x] Wrap amount field decoration in `ValueListenableBuilder` on `_amountController`
    - [x] Implement dynamic border color: Red for telecom exceeding, Orange for InstaPay exceeding
    - [x] Implement contextual `errorText` with strict evaluation order (daily first, then monthly)
    - [x] Implement Submit button disable logic for telecom wallets when amount exceeds `maxAvailable`
    - [x] Run tests and confirm they pass (Green)

- [x] Task: Write Tests — Max button (6d40caf)
    - [x] Test: Max button visible only for Receive transactions
    - [x] Test: Max button hidden for Send transactions
    - [x] Test: Tapping Max button populates `_amountController` with `maxAvailable`
    - [x] Test: Tapping Max button triggers validation
    - [x] Run tests and confirm they fail (Red)

- [x] Task: Implement — Max button in `suffixIcon` (6d40caf)
    - [x] Add `TextButton` labeled "الحد الأقصى" (Max) inside the amount field `suffixIcon`
    - [x] Conditionally render only for Receive transaction type
    - [x] On tap: populate `_amountController.text` with formatted `maxAvailable` and trigger validation
    - [x] Run tests and confirm they pass (Green)

- [x] Task: Conductor - User Manual Verification 'Phase 3: Amount Validation & Max Button' (Protocol in workflow.md) (9336930)

## Phase 4: UI — 3-Zone Dynamic Progress Bar (FR-3)

- [ ] Task: Write Tests — 3-Zone progress bar widget
    - [ ] Create test file `test/presentation/widgets/wallet/three_zone_progress_bar_test.dart`
    - [ ] Test: telecom Receive renders 3 zones (Used/Red, Available/Green, Blocked/Grey)
    - [ ] Test: zone widths are proportional to `monthlyUsed`, `maxAvailable`, and `blocked` values
    - [ ] Test: InstaPay Receive renders standard 2-zone bar (no Grey zone)
    - [ ] Test: Send transactions render standard 2-zone bar
    - [ ] Run tests and confirm they fail (Red)

- [ ] Task: Implement — `ThreeZoneProgressBar` widget
    - [ ] Create `lib/presentation/widgets/wallet/three_zone_progress_bar.dart`
    - [ ] Implement `Row` of `AnimatedContainer` zones with:
        - Duration: `300ms`, Curve: `Curves.easeOutCubic`
        - Zone widths calculated from `LayoutBuilder` constraints
    - [ ] Implement Grey/Hatched styling for Zone 3 (Blocked by Balance)
    - [ ] Run tests and confirm they pass (Green)

- [ ] Task: Integrate progress bar into `CreateTransactionScreen`
    - [ ] Replace `WalletLimitBar` in `_buildLimitsPreview()` with `ThreeZoneProgressBar` for telecom Receive
    - [ ] Wrap progress bar in `ValueListenableBuilder` on `_amountController` for isolated rebuilds
    - [ ] Preserve standard 2-zone `WalletLimitBar` for InstaPay and Send transactions
    - [ ] Run full test suite and confirm all tests pass

- [ ] Task: Conductor - User Manual Verification 'Phase 4: 3-Zone Progress Bar' (Protocol in workflow.md)

## Phase 5: Polish & Final Verification

- [ ] Task: Performance audit
    - [ ] Verify `ValueListenableBuilder` isolation prevents full-form rebuilds
    - [ ] Test typing responsiveness in the amount field (no jank)
    - [ ] Run `flutter analyze` and resolve any warnings/errors

- [ ] Task: Run full test suite and verify coverage
    - [ ] Run `CI=true flutter test`
    - [ ] Verify all acceptance criteria (AC-1 through AC-9) are covered by tests
    - [ ] Verify coverage > 80% for new code

- [ ] Task: Conductor - User Manual Verification 'Phase 5: Polish & Final Verification' (Protocol in workflow.md)
