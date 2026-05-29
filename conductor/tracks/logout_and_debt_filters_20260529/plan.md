# Plan: Fix Logout Navigation & Debt Filters

## Phase 1: Fix Infinite Loading on Logout (BUG-01)

This phase resolves the infinite loading screen during logout by making `AuthCheckWrapper` the Single Source of Truth for authentication navigation and resetting the instance-level `_isNavigating` flag when the user becomes unauthenticated or in an error state. Redundant routing from logout buttons is removed to prevent race conditions.

- [x] Task: Write failing unit/widget test for AuthCheckWrapper logout state reset [c76c878]
- [x] Task: Update `AuthCheckWrapper` in `lib/app.dart` to reset `_isNavigating` when unauthenticated or in error status [5a430f6]
- [x] Task: Remove imperative navigation from UI logout elements in `app_drawer.dart` and `logout_button.dart` [5a430f6]
- [x] Task: Verify that all Auth tests pass successfully [5a430f6]
- [~] Task: Conductor - User Manual Verification 'Phase 1: Fix Infinite Loading on Logout (BUG-01)' (Protocol in workflow.md)

## Phase 2: Fix Debt Tabs & Filters (BUG-02)

This phase bridges the gap between the UI filters and the Firestore queries in the repository. We will pass the selected type and status filters down to `DebtRepository.getDebtsByDateRange()`, and clear pagination state inside the provider when changing filters to prevent state leakage.

- [ ] Task: Write failing unit test for `DebtRepository.getDebtsByDateRange` with filters and `DebtProvider` state updates
- [ ] Task: Update `getDebtsByDateRange` in `lib/data/repositories/debt_repository.dart` to apply dynamic `.where()` clauses for `debtType` and `debtStatus`
- [ ] Task: Update `DebtProvider` in `lib/providers/debt_provider.dart` to pass filters and clear previous data state on filter changes
- [ ] Task: Run all tests and handle any Firestore index exceptions or query failures
- [ ] Task: Verify all Debt repository and provider tests pass successfully
- [ ] Task: Conductor - User Manual Verification 'Phase 2: Fix Debt Tabs & Filters (BUG-02)' (Protocol in workflow.md)
