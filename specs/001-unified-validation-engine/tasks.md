# Implementation Tasks: Unified Validation Engine

## Dependencies
- Phase 2 (Foundational) blocks all subsequent User Stories.
- US1 and US2 can be executed in parallel once Phase 2 is complete.

## Implementation Strategy
- MVP: Complete Phase 2 to secure the database layer.
- Incremental Delivery: Ship US1 to fix the background overlay bugs, then follow with US2 to deliver real-time reactivity to the dashboard.

## Phase 1: Setup
- [x] T001 Create `lib/data/services/transaction_validator_service.dart`.
- [x] T002 Register the new service in the dependency injection container or base providers routing.

## Phase 2: Foundational (Centralized Validator)
*Goal: Create the core engine that enforces atomic transactions, positive amount rules, and wallet capacity limits.*
- [x] T003 Implement `TransactionValidatorService` class skeleton with `validateAndSave` signature in `lib/data/services/transaction_validator_service.dart`.
- [x] T004 Implement positive amount and balance sufficiency checks inside `validateAndSave` in `lib/data/services/transaction_validator_service.dart`.
- [x] T005 Implement explicit wallet capacity and network limits (InstaPay/Telecom) checks in `lib/data/services/transaction_validator_service.dart`.
- [x] T006 Wrap the successful validation states inside `FirebaseFirestore.instance.runTransaction()` logic in `lib/data/services/transaction_validator_service.dart` to strictly avoid dirty writes.
- [x] T007 Refactor manual entry saving (e.g., in `lib/presentation/widgets/debt/debt_card.dart` or transaction routes) to route clicks exclusively through `TransactionValidatorService`.

## Phase 3: [US1] Overlay State & Error Handling
*Goal: Auto-inject commission, reset stale state, and gracefully handle transaction errors in the overlay.*
- [x] T008 [P] [US1] Add `_resetOverlayState` method to `lib/presentation/providers/overlay_provider.dart` that nullifies `currentCommission` and associated values upon launch.
- [x] T009 [US1] Integrate `FeeCalculator.calculateFee` directly into the overlay initialization sequence in `lib/presentation/providers/overlay_provider.dart` so Default commission is always present and mathematically exact.
- [x] T010 [US1] Update the "Confirm" action workflow in `lib/presentation/providers/overlay_provider.dart` to execute `TransactionValidatorService.validateAndSave()`.
- [x] T011 [US1] Wrap the overlay "Confirm" logic within a try/catch block executing `BotToast.showText()` for any validation/network errors, leaving the overlay open to retry in `lib/presentation/providers/overlay_provider.dart`.

## Phase 4: [US2] Reactive Main UI
*Goal: Update main dashboard Wallets in real-time avoiding pull-to-refresh.*
- [x] T012 [P] [US2] Subscribe to `FirebaseFirestore.instance.collection('wallets').doc(id).snapshots()` inside `lib/providers/transaction_provider.dart` or `wallet_provider.dart` initialization.
- [x] T013 [US2] Route snapshot emission events to `notifyListeners()` within the target provider so UI automatically detects current limits/amounts.
- [x] T014 [US2] Verify `WalletCard` (e.g., inside dashboard code) strips out one-time `FutureBuilder`/`get()` logic in favor of straightforward `context.watch()`/`Consumer` structures.

## Phase 5: Polish & Cross-Cutting Concerns
- [x] T015 [P] Ensure `awesome_dialog` gracefully catches and displays error strings originating from foreground manual transaction errors.
- [x] T016 [P] Check the entire codebase using text search to identify and completely eradicate any orphaned `firestore.instance.collection(...).add()` logic for transactions to guarantee Singleton entry.
