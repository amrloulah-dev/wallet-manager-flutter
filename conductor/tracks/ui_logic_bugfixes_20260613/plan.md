# Implementation Plan: UI/Logic Bug-Fix Sweep

## Phase 1: Fix Transaction Creator Name

- [x] Task: Write Failing Tests — Transaction Creator Name [e3a8bcf]
    - [x] Create/update test file for transaction creation (e.g., `test/providers/transaction_provider_test.dart`)
    - [x] Write test: when an employee creates a transaction, `createdByName` equals the employee's name and `creatorRole` equals `employee`
    - [x] Write test: when the store owner creates a transaction, `createdByName` equals the owner's display name and `creatorRole` equals `owner`
    - [x] Write test: if both providers return null/empty, a sensible fallback is used (not "Unknown")
    - [x] Run tests and confirm they fail (Red Phase)

- [x] Task: Implement Fix — Transaction Creator Name [e3a8bcf]
    - [x] Locate the transaction creation method (e.g., `addTransaction` / `createTransaction` in `transaction_provider.dart`)
    - [x] Add logic to check `EmployeeProvider` first for the logged-in user's name and role
    - [x] Fall back to `AuthProvider` display name and assign `owner` role if not an employee
    - [x] Populate `createdByName` and `creatorRole` on the new `TransactionModel` before Firestore write
    - [x] Run tests and confirm they pass (Green Phase)

- [x] Task: Refactor — Transaction Creator Name [e3a8bcf]
    - [x] Review and refactor implementation for clarity (e.g., extract a `_resolveCreatorInfo()` helper if appropriate)
    - [x] Ensure no redundant provider lookups
    - [x] Re-run tests to confirm they still pass

- [x] Task: Conductor - User Manual Verification 'Phase 1: Fix Transaction Creator Name' (Protocol in workflow.md) [e3a8bcf]

## Phase 2: Fix Wallet Card Display

- [ ] Task: Write Failing Tests — Phone Number RTL
    - [ ] Create/update test file for `number_formatter.dart` (e.g., `test/core/utils/number_formatter_test.dart`)
    - [ ] Write test: `formatPhoneNumber` returns the normalized number without naive substring reversal
    - [ ] Run tests and confirm they fail (Red Phase)

- [ ] Task: Implement Fix — Phone Number RTL
    - [ ] Update `formatPhoneNumber` in `number_formatter.dart` to return the number logically (no naive concatenation)
    - [ ] In `wallet_card.dart`, wrap the phone number `Text` widget with `Directionality(textDirection: TextDirection.ltr, child: ...)`
    - [ ] Run tests and confirm they pass (Green Phase)

- [ ] Task: Write Failing Tests — Inactive Badge Logic
    - [ ] Create/update widget test for `wallet_card.dart` (e.g., `test/presentation/widgets/wallet_card_test.dart`)
    - [ ] Write test: inactive badge shows when `wallet.walletStatus == WalletStatus.suspended`
    - [ ] Write test: inactive badge does NOT show when wallet is active (even if `isFrozen` is true)
    - [ ] Run tests and confirm they fail (Red Phase)

- [ ] Task: Implement Fix — Inactive Badge & Card Scale
    - [ ] In `wallet_card.dart`, update inactive badge condition from `isFrozen` to `wallet.walletStatus == WalletStatus.suspended`
    - [ ] Wrap the outermost wallet card container with `Transform.scale(scale: 0.85)`
    - [ ] Run tests and confirm they pass (Green Phase)

- [ ] Task: Refactor — Wallet Card Fixes
    - [ ] Review wallet card code for clarity and consistency with project patterns
    - [ ] Ensure no duplicate directionality wrappers or redundant badge logic
    - [ ] Re-run all tests to confirm they still pass

- [ ] Task: Conductor - User Manual Verification 'Phase 2: Fix Wallet Card Display' (Protocol in workflow.md)

## Phase 3: Fix Employee Limit Validation

- [ ] Task: Write Failing Tests — Employee Limit Boundary
    - [ ] Create/update test file (e.g., `test/providers/employee_provider_test.dart` or `test/providers/subscription_provider_test.dart`)
    - [ ] Write test: `canAddEmployee` returns `true` when `currentEmployees == 0`
    - [ ] Write test: `canAddEmployee` returns `true` when `currentEmployees == maxLimit - 1`
    - [ ] Write test: `canAddEmployee` returns `false` when `currentEmployees == maxLimit`
    - [ ] Write test: `canAddEmployee` returns `false` when `currentEmployees > maxLimit`
    - [ ] Run tests and confirm they fail (Red Phase)

- [ ] Task: Implement Fix — Employee Limit Validation
    - [ ] In `subscription_provider.dart`, fix `canAddEmployee` to strictly return `true` when `currentEmployees < maxLimit`
    - [ ] In `employee_provider.dart`, verify that `addEmployee` correctly passes the current employee count to `canAddEmployee`
    - [ ] Run tests and confirm they pass (Green Phase)

- [ ] Task: Refactor — Employee Limit Validation
    - [ ] Review the conditional logic for readability
    - [ ] Ensure error message `employee_error_max_limit_reached` is only triggered at the correct boundary
    - [ ] Re-run all tests to confirm they still pass

- [ ] Task: Conductor - User Manual Verification 'Phase 3: Fix Employee Limit Validation' (Protocol in workflow.md)
