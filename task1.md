# Phase 1: Critical Stabilization — Steps 1.1–1.4

## Step 1.1 — Fee Calculation Pipeline Hardening
- `[ ]` `fee_calculator.dart`: Replace `default` return 0.0 with `throw DomainException`
- `[ ]` `transaction_fee_calculator.dart`: Add null-guard for `transactionType` (keep nullable, throw explicitly)
- `[ ]` `transaction_fee_calculator.dart`: Fix `totalAmount = amount + commission + fee`
- `[ ]` `transaction_fee_calculator.dart`: Add `AmountValidator.ensurePositive(amount)` at entry

## Step 1.2 — Balance Precision & Negative-Balance Prevention
- `[ ]` `transaction_validator_service.dart`: Fix epsilon direction in balance check
- `[ ]` `wallet_repository.dart`: Add `creditWallet` method (simple increment)
- `[ ]` `wallet_repository.dart`: Add `debitWallet` method (Firestore runTransaction with balance check)
- `[ ]` `wallet_repository.dart`: Deprecate `updateWalletBalance`

## Step 1.3 — Deposit Audit Trail Gap
- `[ ]` `transaction_validator_service.dart`: Fix deposit path to write transaction document before returning

## Step 1.4 — Commission/ServiceFee Accounting
- `[ ]` `transaction_validator_service.dart`: Fix receive balance formula (`amount` only, not `amount + commission`)
- `[ ]` `transaction_validator_service.dart`: Add `totalServiceFee` tracking in wallet stats and store stats
- `[ ]` `wallet_model.dart` (WalletStats): Add `totalServiceFee` field + `totalEarnings` getter
- `[ ]` UI getters: Ensure `totalEarnings` combines commission + serviceFee for backward-compatible display
