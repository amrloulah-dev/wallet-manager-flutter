# Specification: Phase 1 (Steps 1.1-1.4) - Critical Stabilization

## Overview
This track implements Steps 1.1 through 1.4 of Phase 1 (Critical Stabilization) from the Business Logic & Domain Integrity Correction Plan. The goal is to eliminate active revenue leakage, prevent negative wallet balances, fix audit-trail gaps for deposits, and correct the accounting logic for commissions and service fees.

## Functional Requirements
1. **Fee Calculation Hardening (Step 1.1)**
   - In `fee_calculator.dart`: Replace the `default` fallback of `0.0` with `throw DomainException`.
   - In `transaction_fee_calculator.dart`: Guard against null `transactionType` by explicitly throwing an error.
   - Fix the `totalAmount` calculation to correctly sum: `amount + commission + fee`.
   - Enforce positive amounts at entry points using `AmountValidator.ensurePositive(amount)`.
   - Ensure all `DomainException`s thrown here are visibly surfaced to the user.

2. **Balance Precision & Negative-Balance Prevention (Step 1.2)**
   - In `transaction_validator_service.dart`: Update the balance check to use a system-favorable epsilon (`if ((balance + 0.01) < totalDeduction)`) to prevent floating-point rejection on exact-balance transactions.
   - In `wallet_repository.dart`: Introduce robust `creditWallet` and `debitWallet` methods. `debitWallet` must assert balance sufficiency inside a Firestore transaction.
   - Deprecate the old `updateWalletBalance` method.

3. **Deposit Audit Trail Gap (Step 1.3)**
   - In `transaction_validator_service.dart`: Remove the early return.
   - Wrap the Deposit flow (transaction document write + wallet balance update) in a `Firestore WriteBatch` or `runTransaction` to guarantee atomicity.

4. **Commission/ServiceFee Accounting (Step 1.4)**
   - In `transaction_validator_service.dart`: Change the receive balance calculation formula to `amount` only (omitting `commission`, which is collected as physical cash globally).
   - Track `totalServiceFee` in `WalletStats` and `StoreStats`. Update related models and Firestore writes.
   - Ensure UI getters (e.g., `totalEarnings`) aggregate both `commission` and `serviceFee` to maintain backward-compatible display values.

## Non-Functional Requirements
- **Data Resilience:** Application code must be updated defensively to gracefully handle any legacy data without crashing, complementing a separate one-time Firestore migration script.
- **Error Visibility:** Domain errors (like invalid types or insufficient funds) must trigger visible UI feedback (e.g., Snackbars) rather than failing silently.

## Acceptance Criteria
- [ ] Attempting a transaction with an unrecognized wallet type throws a visible `DomainException` instead of resulting in a 0.0 fee.
- [ ] Attempting to debit a wallet below 0.0 EGP is mathematically prevented (with 0.01 epsilon allowance for exact transactions).
- [ ] Processing a Deposit transaction creates a corresponding transaction document in Firestore atomically alongside the balance update.
- [ ] Processing a Receive transaction only credits the base amount to the digital wallet balance, accurately keeping the commission separate.

## Out of Scope
- Steps 1.5 through 1.9 of the Critical Stabilization phase.
- Phase 2 (Structural Corrections) and Phase 3 (Optimization & Hardening).