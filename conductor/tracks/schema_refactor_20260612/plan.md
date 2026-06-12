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

- [x] Task: Write failing tests for `getStatsByDateRange` aggregation fix (FR-3) 25d2785
    - [x] Test that aggregation only folds keys from new `DailyStatsModel` schema 25d2785
    - [x] Test that dead keys (`totalAmount`, `totalServiceFee`) are NOT aggregated even if present in source documents 25d2785
    - [x] Test correct summation across multiple daily_stats documents 25d2785
- [x] Task: Implement `getStatsByDateRange` aggregation fix (FR-3) 25d2785
    - [x] Update the loop to only aggregate the exact keys in the new `DailyStatsModel` 25d2785
    - [x] Remove any references to dead keys 25d2785
    - [x] Run tests and confirm all pass 25d2785
- [x] Task: Write failing tests for `fetchFilteredStats` rewrite (FR-4) 25d2785
    - [x] Test that "today" stats are fetched via `getStatsByDateRange` with today's date 25d2785
    - [x] Test that no `if (isToday)` branching exists (always delegates to repository) 25d2785
    - [x] Test that result map uses new schema field names 25d2785
- [x] Task: Implement `fetchFilteredStats` rewrite (FR-4) 25d2785
    - [x] Delete the `if (isToday)` logic that mixes lifetime and daily variables 25d2785
    - [x] Always call `getStatsByDateRange` for all date ranges including today 25d2785
    - [x] Map the result directly to the UI map using new schema names 25d2785
    - [x] Run tests and confirm all pass 25d2785
- [x] Task: Write failing tests for `addTransactionOptimistically` rewrite (FR-4, FR-1, FR-2) 25d2785
    - [x] Test that only new `StatsSummaryModel` fields are incremented 25d2785
    - [x] Test that only new `DailyStatsModel` fields are incremented 25d2785
    - [x] Test that no deleted fields (`totalServiceFee`, `totalServiceFeeToday`, `totalCommissionToday`, etc.) are referenced 25d2785
- [x] Task: Implement `addTransactionOptimistically` rewrite (FR-4, FR-1, FR-2) 25d2785
    - [x] Update increments to strictly use new schema fields 25d2785
    - [x] Remove all references to deleted fields 25d2785
    - [x] Maintain Optimistic UI pattern (mutate RAM first, `safeNotify()`, Firestore write in background) 25d2785
    - [x] Run tests and confirm all pass 25d2785
- [x] Task: Conductor - User Manual Verification 'Phase 2: Data Layer & Aggregation Fix' (Protocol in workflow.md) 25d2785

## Phase 3: UI Data Routing

- [x] Task: Write failing tests for Dashboard Quick Stats routing (FR-5) 6ca4e89
    - [x] Test "Total Wallets" reads from `provider.dashboardSummary.totalWallets` 6ca4e89
    - [x] Test "Open Debts" reads from `provider.dashboardSummary.openDebtsCount` 6ca4e89
    - [x] Test "Total Transactions" reads from `provider.todayStats?.totalTransactions` 6ca4e89
    - [x] Test "Total Commission" reads from `provider.todayStats?.totalCommission` 6ca4e89
    - [x] Test no references to deleted fields remain 6ca4e89
- [x] Task: Implement Dashboard Quick Stats routing fix (FR-5) 6ca4e89
    - [x] Update card data bindings to correct provider properties 6ca4e89
    - [x] Remove any references to deleted model fields 6ca4e89
    - [x] Run tests and confirm all pass 6ca4e89
- [x] Task: Write failing tests for Statistics Screen UI update (FR-6) 6ca4e89
    - [x] Test `_buildStatistics` reads only from defined schema properties 6ca4e89
    - [x] Test no calls to `.totalAmount` or `.totalServiceFee` exist 6ca4e89
- [x] Task: Implement Statistics Screen UI update (FR-6) 6ca4e89
    - [x] Update all UI builders to use new schema property names 6ca4e89
    - [x] Remove references to `.totalAmount`, `.totalServiceFee`, and any other deleted property 6ca4e89
    - [x] Run tests and confirm all pass 6ca4e89
- [x] Task: Conductor - User Manual Verification 'Phase 3: UI Data Routing' (Protocol in workflow.md) 6ca4e89

## Phase 4: Final Verification & Cleanup

- [x] Task: Run `flutter analyze` and fix any new warnings/errors 6ca4e89
    - [x] Execute `flutter analyze` across the entire project 6ca4e89
    - [x] Fix any issues introduced by the refactor 6ca4e89
- [x] Task: Run full test suite and verify zero regressions 6ca4e89
    - [x] Execute `CI=true flutter test` 6ca4e89
    - [x] Confirm all existing and new tests pass 6ca4e89
- [x] Task: Code review and dead-code sweep 6ca4e89
    - [x] Grep codebase for any remaining references to deleted fields 6ca4e89
    - [x] Remove any orphaned imports, unused variables, or dead code paths 6ca4e89
    - [x] Verify no `.arb` localization files reference deleted fields 6ca4e89
- [x] Task: Conductor - User Manual Verification 'Phase 4: Final Verification & Cleanup' (Protocol in workflow.md) 6ca4e89

## Phase: Review Fixes
- [x] Task: Apply review suggestions 6ca4e89
