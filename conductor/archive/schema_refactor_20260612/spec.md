# Spec: Firebase Schema Refactor & Data Source Decoupling

## Overview

The statistics data layer suffers from severe mapping conflicts and data redundancy. `StatsSummaryModel` contains redundant "today" fields that duplicate data already available in `DailyStatsModel`. The provider layer has tangled `if (isToday)` logic that mixes lifetime aggregates with daily documents, and the UI reads a blend of legacy and current fields. The service fee concept is being permanently retired from the product.

This refactor will:
1. **Rebuild the data models** — strip dead/redundant fields from `StatsSummaryModel` and `DailyStatsModel`.
2. **Fix the data layer** — ensure repository aggregation and provider logic only operate on the new schema.
3. **Correct UI data routing** — make dashboard and statistics screens read exclusively from the correct, newly-defined sources.

**Scope:** Dart code only. Existing Firestore documents will NOT be migrated; `fromMap` will gracefully default missing/orphaned fields via `?? 0`.

## Functional Requirements

### FR-1: `StatsSummaryModel` Cleanup
- **Remove** the following 6 fields: `totalCommissionToday`, `totalReceivedAmountToday`, `totalSentAmountToday`, `totalTransactionsToday`, `totalServiceFee`, `totalServiceFeeToday`.
- **Keep** exactly: `totalTransactions`, `totalSentAmount`, `totalReceivedAmount`, `totalCommission`, `totalOpenAmount`, `totalPaidAmount`, `totalWallets`, `openDebtsCount`.
- Update `fromMap`, `toMap`, and `copyWith` accordingly.
- All `fromMap` numeric fields must default via `?? 0` (int) or `?? 0.0` (double) to handle legacy documents.

### FR-2: `DailyStatsModel` Redefine
- **Remove** `totalAmount` and `totalServiceFee`.
- **Final schema:** `date`, `sendCount`, `receiveCount`, `totalSentAmount`, `totalReceivedAmount`, `totalTransactions`, `totalCommission`, `openDebtsCount`, `paidDebtsCount`, `totalOpenAmount`, `totalPaidAmount`.
- Update `fromMap`, `toMap`, and `copyWith` accordingly.
- All `fromMap` numeric fields must default via `?? 0` / `?? 0.0`.

### FR-3: Repository Aggregation Fix (`stats_repository.dart`)
- `getStatsByDateRange` loop aggregation must ONLY fold the exact numerical keys present in the newly defined `DailyStatsModel`.
- Dead/deleted keys (`totalAmount`, `totalServiceFee`) must NOT be aggregated.

### FR-4: Provider Rewrite (`statistics_provider.dart`)
- **`fetchFilteredStats`**: Remove the `if (isToday)` branching that mixes lifetime and daily variables. Always use `getStatsByDateRange` to fetch daily_stats document(s). "Today" stats come from `daily_stats/{today's date}` via `getStatsByDateRange`. Map results directly to the UI map using new schema names.
- **`addTransactionOptimistically`**: Increment counters strictly according to the new `StatsSummaryModel` and `DailyStatsModel` fields only. Remove all references to deleted fields (`totalServiceFee`, `totalServiceFeeToday`, `totalCommissionToday`, `totalTransactionsToday`, `totalSentAmountToday`, `totalReceivedAmountToday`).

### FR-5: Dashboard Quick Stats UI Routing (`dashboard_quick_stats.dart`)
- "Total Wallets" card → reads `provider.dashboardSummary.totalWallets`
- "Open Debts" card → reads `provider.dashboardSummary.openDebtsCount`
- "Total Transactions" card → reads `provider.todayStats?.totalTransactions`
- "Total Commission" card → reads `provider.todayStats?.totalCommission`
- Remove any references to deleted fields.

### FR-6: Statistics Screen UI Update (`general_statistics_screen.dart`)
- Update `_buildStatistics` (or similar UI builders) to read strictly from the defined schema properties.
- Remove all calls to `.totalAmount`, `.totalServiceFee`, or any other deleted property.

## Non-Functional Requirements

- **NFR-1: Backward Compatibility** — `fromMap` methods must handle legacy Firestore documents gracefully (default missing fields to 0). No Firestore migration required.
- **NFR-2: No Regressions** — Existing unit tests must continue to pass; new tests must be written for changed logic.
- **NFR-3: Type Safety** — All model fields must remain strongly typed. No `dynamic` casts.
- **NFR-4: Constitution Compliance** — Maintain Optimistic UI pattern, `SafeChangeNotifier` usage, `Selector`-based rebuilds per project constitution.

## Acceptance Criteria

1. `StatsSummaryModel` has exactly 8 fields (no "today" or service fee fields).
2. `DailyStatsModel` has exactly 11 fields (including `date`; no `totalAmount` or `totalServiceFee`).
3. `getStatsByDateRange` only aggregates keys from the new `DailyStatsModel` schema.
4. `fetchFilteredStats` has no `if (isToday)` branching — always delegates to `getStatsByDateRange`.
5. `addTransactionOptimistically` does not reference any deleted field.
6. Dashboard quick stats cards read from the correct provider properties.
7. Statistics screen has zero references to deleted fields.
8. All existing tests pass; new tests cover the changed model, repository, and provider logic.
9. `flutter analyze` reports no new warnings or errors.

## Out of Scope

- Firestore document migration or cleanup scripts.
- Changes to Firestore security rules or indexes.
- Adding new statistical fields or metrics.
- Changes to the SMS automation / overlay system.
- Localization string changes (unless a deleted field surfaces in `.arb` files).
