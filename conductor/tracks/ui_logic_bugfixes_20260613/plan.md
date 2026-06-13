# Implementation Plan: UI/Logic Bug-Fix Sweep

## Phase 1: Fix Transaction Creator Name [checkpoint: 1f9a5c7]

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

## Phase 2: Fix Wallet Card Display [checkpoint: c7bcca4]

- [x] Task: Write Failing Tests — Phone Number RTL [c7bcca4]
    - [x] Create/update test file for `number_formatter.dart` (e.g., `test/core/utils/number_formatter_test.dart`)
    - [x] Write test: `formatPhoneNumber` returns the normalized number without naive substring reversal
    - [x] Run tests and confirm they fail (Red Phase)

- [x] Task: Implement Fix — Phone Number RTL [c7bcca4]
    - [x] Update `formatPhoneNumber` in `number_formatter.dart` to return the number logically (no naive concatenation)
    - [x] In `wallet_card.dart`, wrap the phone number `Text` widget with `Directionality(textDirection: TextDirection.ltr, child: ...)`
    - [x] Run tests and confirm they pass (Green Phase)

- [x] Task: Write Failing Tests — Inactive Badge Logic [c7bcca4]
    - [x] Create/update widget test for `wallet_card.dart` (e.g., `test/presentation/widgets/wallet_card_test.dart`)
    - [x] Write test: inactive badge shows when `wallet.walletStatus == WalletStatus.suspended`
    - [x] Write test: inactive badge does NOT show when wallet is active (even if `isFrozen` is true)
    - [x] Run tests and confirm they fail (Red Phase)

- [x] Task: Implement Fix — Inactive Badge & Card Scale [c7bcca4]
    - [x] In `wallet_card.dart`, update inactive badge condition from `isFrozen` to `wallet.walletStatus == WalletStatus.suspended`
    - [x] Wrap the outermost wallet card container with `Transform.scale(scale: 0.85)`
    - [x] Run tests and confirm they pass (Green Phase)

- [x] Task: Refactor — Wallet Card Fixes [c7bcca4]
    - [x] Review wallet card code for clarity and consistency with project patterns
    - [x] Ensure no duplicate directionality wrappers or redundant badge logic
    - [x] Re-run all tests to confirm they still pass

- [x] Task: Conductor - User Manual Verification 'Phase 2: Fix Wallet Card Display' (Protocol in workflow.md) [c7bcca4]

## Phase 3: Fix Employee Limit Validation [checkpoint: 3ef5dd4]

- [x] Task: Write Failing Tests — Employee Limit Boundary [3ef5dd4]
    - [x] Create/update test file (e.g., `test/providers/employee_provider_test.dart` or `test/providers/subscription_provider_test.dart`)
    - [x] Write test: `canAddEmployee` returns `true` when `currentEmployees == 0`
    - [x] Write test: `canAddEmployee` returns `true` when `currentEmployees == maxLimit - 1`
    - [x] Write test: `canAddEmployee` returns `false` when `currentEmployees == maxLimit`
    - [x] Write test: `canAddEmployee` returns `false` when `currentEmployees > maxLimit`
    - [x] Run tests and confirm they fail (Red Phase)

- [x] Task: Implement Fix — Employee Limit Validation [3ef5dd4]
    - [x] In `subscription_provider.dart`, fix `canAddEmployee` to strictly return `true` when `currentEmployees < maxLimit`
    - [x] In `employee_provider.dart`, verify that `addEmployee` correctly passes the current employee count to `canAddEmployee`
    - [x] Run tests and confirm they pass (Green Phase)

- [x] Task: Refactor — Employee Limit Validation [3ef5dd4]
    - [x] Review the conditional logic for readability
    - [x] Ensure error message `employee_error_max_limit_reached` is only triggered at the correct boundary
    - [x] Re-run all tests to confirm they still pass

- [x] Task: Conductor - User Manual Verification 'Phase 3: Fix Employee Limit Validation' (Protocol in workflow.md) [3ef5dd4]
