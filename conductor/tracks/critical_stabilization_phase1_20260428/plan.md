# Implementation Plan: Phase 1 (Steps 1.1-1.4) - Critical Stabilization

## Phase 1.1: Fee Calculation Hardening [checkpoint: 7f9a19b]
- [x] Task: Write failing tests for fee calculation and validation [7291a52]
    - [x] Unit test: `transactionType` is null -> throws `DomainException`
    - [x] Unit test: unknown wallet type -> throws `DomainException`
    - [x] Unit test: verify `totalAmount == amount + commission + serviceFee`
    - [x] Unit test: negative amount -> throws `DomainException`
- [x] Task: Implement fee calculation hardening [7291a52]
    - [x] `fee_calculator.dart`: Replace `default` return 0.0 with `throw DomainException`
    - [x] `transaction_fee_calculator.dart`: Enforce non-null `transactionType` guard
    - [x] `transaction_fee_calculator.dart`: Fix `totalAmount` formula
    - [x] `transaction_fee_calculator.dart`: Add `AmountValidator.ensurePositive(amount)`
- [x] Task: Conductor - User Manual Verification 'Phase 1.1: Fee Calculation Hardening' (Protocol in workflow.md)

## Phase 1.2: Balance Precision & Negative-Balance Prevention
- [ ] Task: Write failing tests for balance precision
    - [ ] Unit test: exact balance transaction (100.0 vs 100.0) -> succeeds with epsilon tolerance
    - [ ] Unit test: debitWallet with amount > balance -> throws `DomainException`
- [ ] Task: Implement strict balance and Firestore transactions
    - [ ] `transaction_validator_service.dart`: Update balance check to use system-favorable epsilon: `if ((balance + 0.01) < totalDeduction)`
    - [ ] `wallet_repository.dart`: Add `creditWallet` method
    - [ ] `wallet_repository.dart`: Add `debitWallet` method using Firestore `runTransaction`
    - [ ] `wallet_repository.dart`: Mark `updateWalletBalance` as `@Deprecated`
- [ ] Task: Conductor - User Manual Verification 'Phase 1.2: Balance Precision & Negative-Balance Prevention' (Protocol in workflow.md)

## Phase 1.3: Deposit Audit Trail Gap
- [ ] Task: Write failing test for deposit audit trail
    - [ ] Integration test: Deposit transaction creates a valid document in Firestore
- [ ] Task: Implement atomic deposit write
    - [ ] `transaction_validator_service.dart`: Remove early return that skips document write
    - [ ] `transaction_validator_service.dart`: Wrap deposit logic (write doc + update balance) in a `Firestore WriteBatch` or `runTransaction` for atomicity
- [ ] Task: Conductor - User Manual Verification 'Phase 1.3: Deposit Audit Trail Gap' (Protocol in workflow.md)

## Phase 1.4: Commission/ServiceFee Accounting
- [ ] Task: Write failing tests for commission/service fee
    - [ ] Unit test: Send transaction increments `totalServiceFee` and `totalCommission`
    - [ ] Unit test: Receive transaction balance calculation is `amount` only
- [ ] Task: Implement new accounting logic
    - [ ] `wallet_model.dart` / `store_model.dart`: Add `totalServiceFee` field and update UI getters (`totalEarnings`)
    - [ ] `transaction_validator_service.dart`: Update receive balance formula (`amount` only)
    - [ ] `transaction_validator_service.dart`: Update stats tracking to increment `totalServiceFee`
- [ ] Task: Conductor - User Manual Verification 'Phase 1.4: Commission/ServiceFee Accounting' (Protocol in workflow.md)