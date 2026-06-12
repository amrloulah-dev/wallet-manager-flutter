# Plan: Firebase Schema Refactor & Data Source Decoupling

## Phase 1: Data Model Rebuild

- [x] Task: Write failing tests for `StatsSummaryModel` cleanup (FR-1) bd0bd03
    - [x] Test that `StatsSummaryModel` has exactly 8 fields (no `totalCommissionToday`, `totalReceivedAmountToday`, `totalSentAmountToday`, `totalTransactionsToday`, `totalServiceFee`, `totalServiceFeeToday`) bd0bd03
    - [x] Test `fromMap` gracefully defaults missing fields to 0/0.0 bd0bd03
    - [x] Test `toMap` only serializes the 8 kept fields bd0bd03
    - [x] Test `copyWith` works correctly for all 8 fields bd0bd03
- [x] Task: Implement `StatsSummaryModel` cleanup (FR-1) bd0bd03
    - [x] Remove the 6 dead fields from the class definition bd0bd03
    - [x] Update `fromMap` to only read kept fields with `?? 0` / `?? 0.0` defaults bd0bd03
    - [x] Update `toMap` to only serialize kept fields bd0bd03
    - [x] Update `copyWith` to only include kept fields bd0bd03
    - [x] Run tests and confirm all pass bd0bd03
- [x] Task: Write failing tests for `DailyStatsModel` redefine (FR-2) bd0bd03
    - [x] Test that `DailyStatsModel` has exactly 11 fields (`date` + 10 numeric) bd0bd03
    - [x] Test `fromMap` gracefully defaults missing fields to 0/0.0 bd0bd03
    - [x] Test `toMap` only serializes the new schema fields bd0bd03
    - [x] Test `copyWith` works correctly for all 11 fields bd0bd03
- [x] Task: Implement `DailyStatsModel` redefine (FR-2) bd0bd03
    - [x] Remove `totalAmount` and `totalServiceFee` from the class definition bd0bd03
    - [x] Update `fromMap`, `toMap`, and `copyWith` accordingly bd0bd03
    - [x] Run tests and confirm all pass bd0bd03
- [x] Task: Conductor - User Manual Verification 'Phase 1: Data Model Rebuild' (Protocol in workflow.md) bd0bd03

## Phase 2: Data Layer & Aggregation Fix

- [ ] Task: Write failing tests for `getStatsByDateRange` aggregation fix (FR-3)
    - [ ] Test that aggregation only folds keys from new `DailyStatsModel` schema
    - [ ] Test that dead keys (`totalAmount`, `totalServiceFee`) are NOT aggregated even if present in source documents
    - [ ] Test correct summation across multiple daily_stats documents
- [ ] Task: Implement `getStatsByDateRange` aggregation fix (FR-3)
    - [ ] Update the loop to only aggregate the exact keys in the new `DailyStatsModel`
    - [ ] Remove any references to dead keys
    - [ ] Run tests and confirm all pass
- [ ] Task: Write failing tests for `fetchFilteredStats` rewrite (FR-4)
    - [ ] Test that "today" stats are fetched via `getStatsByDateRange` with today's date
    - [ ] Test that no `if (isToday)` branching exists (always delegates to repository)
    - [ ] Test that result map uses new schema field names
- [ ] Task: Implement `fetchFilteredStats` rewrite (FR-4)
    - [ ] Delete the `if (isToday)` logic that mixes lifetime and daily variables
    - [ ] Always call `getStatsByDateRange` for all date ranges including today
    - [ ] Map the result directly to the UI map using new schema names
    - [ ] Run tests and confirm all pass
- [ ] Task: Write failing tests for `addTransactionOptimistically` rewrite (FR-4, FR-1, FR-2)
    - [ ] Test that only new `StatsSummaryModel` fields are incremented
    - [ ] Test that only new `DailyStatsModel` fields are incremented
    - [ ] Test that no deleted fields (`totalServiceFee`, `totalServiceFeeToday`, `totalCommissionToday`, etc.) are referenced
- [ ] Task: Implement `addTransactionOptimistically` rewrite (FR-4, FR-1, FR-2)
    - [ ] Update increments to strictly use new schema fields
    - [ ] Remove all references to deleted fields
    - [ ] Maintain Optimistic UI pattern (mutate RAM first, `safeNotify()`, Firestore write in background)
    - [ ] Run tests and confirm all pass
- [ ] Task: Conductor - User Manual Verification 'Phase 2: Data Layer & Aggregation Fix' (Protocol in workflow.md)

## Phase 3: UI Data Routing

- [ ] Task: Write failing tests for Dashboard Quick Stats routing (FR-5)
    - [ ] Test "Total Wallets" reads from `provider.dashboardSummary.totalWallets`
    - [ ] Test "Open Debts" reads from `provider.dashboardSummary.openDebtsCount`
    - [ ] Test "Total Transactions" reads from `provider.todayStats?.totalTransactions`
    - [ ] Test "Total Commission" reads from `provider.todayStats?.totalCommission`
    - [ ] Test no references to deleted fields remain
- [ ] Task: Implement Dashboard Quick Stats routing fix (FR-5)
    - [ ] Update card data bindings to correct provider properties
    - [ ] Remove any references to deleted model fields
    - [ ] Run tests and confirm all pass
- [ ] Task: Write failing tests for Statistics Screen UI update (FR-6)
    - [ ] Test `_buildStatistics` reads only from defined schema properties
    - [ ] Test no calls to `.totalAmount` or `.totalServiceFee` exist
- [ ] Task: Implement Statistics Screen UI update (FR-6)
    - [ ] Update all UI builders to use new schema property names
    - [ ] Remove references to `.totalAmount`, `.totalServiceFee`, and any other deleted property
    - [ ] Run tests and confirm all pass
- [ ] Task: Conductor - User Manual Verification 'Phase 3: UI Data Routing' (Protocol in workflow.md)

## Phase 4: Final Verification & Cleanup

- [ ] Task: Run `flutter analyze` and fix any new warnings/errors
    - [ ] Execute `flutter analyze` across the entire project
    - [ ] Fix any issues introduced by the refactor
- [ ] Task: Run full test suite and verify zero regressions
    - [ ] Execute `CI=true flutter test`
    - [ ] Confirm all existing and new tests pass
- [ ] Task: Code review and dead-code sweep
    - [ ] Grep codebase for any remaining references to deleted fields
    - [ ] Remove any orphaned imports, unused variables, or dead code paths
    - [ ] Verify no `.arb` localization files reference deleted fields
- [ ] Task: Conductor - User Manual Verification 'Phase 4: Final Verification & Cleanup' (Protocol in workflow.md)
