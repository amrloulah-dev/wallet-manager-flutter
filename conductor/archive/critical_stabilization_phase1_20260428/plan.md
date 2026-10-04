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

## Phase 1.2: Balance Precision & Negative-Balance Prevention [checkpoint: f484f5e]
- [x] Task: Write failing tests for balance precision [f484f5e]
    - [x] Unit test: exact balance transaction (100.0 vs 100.0) -> succeeds with epsilon tolerance
    - [x] Unit test: debitWallet with amount > balance -> throws `DomainException`
- [x] Task: Implement strict balance and Firestore transactions [f484f5e]
    - [x] `transaction_validator_service.dart`: Update balance check to use system-favorable epsilon: `if ((balance + 0.01) < totalDeduction)`
    - [x] `wallet_repository.dart`: Add `creditWallet` method
    - [x] `wallet_repository.dart`: Add `debitWallet` method using Firestore `runTransaction`
    - [x] `wallet_repository.dart`: Mark `updateWalletBalance` as `@Deprecated`
- [x] Task: Conductor - User Manual Verification 'Phase 1.2: Balance Precision & Negative-Balance Prevention' (Protocol in workflow.md) [f484f5e]

## Phase 1.3: Deposit Audit Trail Gap [checkpoint: f484f5e]
- [x] Task: Write failing test for deposit audit trail [f484f5e]
    - [x] Integration test: Deposit transaction creates a valid document in Firestore
- [x] Task: Implement atomic deposit write [f484f5e]
    - [x] `transaction_validator_service.dart`: Remove early return that skips document write
    - [x] `transaction_validator_service.dart`: Wrap deposit logic (write doc + update balance) in a `Firestore WriteBatch` or `runTransaction` for atomicity
- [x] Task: Conductor - User Manual Verification 'Phase 1.3: Deposit Audit Trail Gap' (Protocol in workflow.md) [f484f5e]

## Phase 1.4: Commission/ServiceFee Accounting [checkpoint: f484f5e]
- [x] Task: Write failing tests for commission/service fee [f484f5e]
    - [x] Unit test: Send transaction increments `totalServiceFee` and `totalCommission`
    - [x] Unit test: Receive transaction balance calculation is `amount` only
- [x] Task: Implement new accounting logic [f484f5e]
    - [x] `wallet_model.dart` / `store_model.dart`: Add `totalServiceFee` field and update UI getters (`totalEarnings`)
    - [x] `transaction_validator_service.dart`: Update receive balance formula (`amount` only)
    - [x] `transaction_validator_service.dart`: Update stats tracking to increment `totalServiceFee`

## Phase: Review Fixes
- [x] Task: Apply review suggestions b1ff084
- [x] Task: Finalize Phase 1 (Getters, Error Surfacing, Legacy Resilience) ef49b5d

