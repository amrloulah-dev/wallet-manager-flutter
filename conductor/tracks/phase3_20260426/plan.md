# Implementation Plan: Phase 3 - Business Logic & Domain Integrity

## Phase 1: Financial Fortification & Guard Implementation
- [x] Task: Create `AmountValidator` utility [428f24c]
    - [x] Write failing test for `ensurePositive(double value)`
    - [x] Implement `AmountValidator` throwing `DomainException` for values <= 0
    - [x] Ensure tests pass
- [x] Task: Apply `AmountValidator` guards in repositories [d262f43]
    - [x] Write failing test for `processPayment` rejecting negative/zero values
    - [x] Update `processPayment`, `addExpense`, and balance-modifying methods with `ensurePositive`
    - [x] Ensure tests pass
- [x] Task: Implement atomic ceiling checks for `DebtRepository.processPayment` [976af45]
    - [x] Write failing test for overpayment throwing `InvalidAmountException`
    - [x] Refactor `DebtRepository.processPayment` using `runTransaction` to enforce `paymentAmount <= amountDue`
    - [x] Ensure tests pass
- [x] Task: Enforce counter integrity for statistics [8d5ed7e]
    - [x] Write failing test to prevent counter from decrementing below zero
    - [x] Update counter logic to prevent sub-zero decrements
    - [x] Ensure tests pass
- [x] Task: Conductor - User Manual Verification 'Phase 1: Financial Fortification & Guard Implementation' (Protocol in workflow.md)

## Phase 2: Stream Reliability & Cost Optimization
- [x] Task: Propagate errors in Stream repositories
    - [x] Write failing test for error emission in `UserRepository`, `StoreRepository`, and `EmployeeRepository`
    - [x] Replace empty `.handleError` blocks with `AppErrorHandler.handle(e)` and re-emit via `Stream.error(e)`
    - [x] Ensure tests pass
- [ ] Task: Implement cost capping in snapshots
    - [ ] Update employee-related snapshots in `EmployeeRepository` and `UserRepository` with `.limit(100)`
- [ ] Task: Ensure listener safety across providers
    - [ ] Update `SystemConfigProvider` and other `.listen()` callers to include explicit `onError` handling (surfacing via Toasts/Snackbars)
- [ ] Task: Conductor - User Manual Verification 'Phase 2: Stream Reliability & Cost Optimization' (Protocol in workflow.md)

## Phase 3: Domain Purity & Enum Migration
- [ ] Task: Create Enhanced Enums
    - [ ] Create enums: `DebtStatus`, `WalletType`, `SubscriptionStatus`, and Enums for `EmployeeModel` & `StoreModel`
- [ ] Task: Refactor Domain Models to use Enums
    - [ ] Write failing tests for model serialization using the new Enums
    - [ ] Update `WalletModel`, `DebtModel`, `TransactionModel`, `EmployeeModel`, and `StoreModel` to use Enums instead of strings
    - [ ] Ensure tests pass
- [ ] Task: Implement safe serialization with logging
    - [ ] Write failing tests for handling missing timestamps and hard casts
    - [ ] Refactor `fromFirestore` methods to return null for missing timestamps, log corrupt data occurrences, and use safe fallbacks (`as String? ?? ''`)
    - [ ] Ensure tests pass
- [ ] Task: Conductor - User Manual Verification 'Phase 3: Domain Purity & Enum Migration' (Protocol in workflow.md)

## Phase 4: UX Responsiveness & Precision Handling
- [ ] Task: Ensure immediate feedback in Providers
    - [ ] Write failing tests to verify `setLoading(true)` or `safeNotify()` is called immediately and `_errorMessage = null;` is reset before async work
    - [ ] Update Provider action methods accordingly
    - [ ] Ensure tests pass
- [ ] Task: Format UI for precision
    - [ ] Update presentation layer to use `.toStringAsFixed(2)` for monetary values to prevent precision drift artifacts
- [ ] Task: Conductor - User Manual Verification 'Phase 4: UX Responsiveness & Precision Handling' (Protocol in workflow.md)