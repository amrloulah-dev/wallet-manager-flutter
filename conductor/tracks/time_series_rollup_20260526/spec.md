# Spec: Implement Time-Series Rollup Architecture (BUG-03 & BUG-04)

## Overview

Currently, the app computes daily summaries and date-filtered statistics by fetching and locally filtering `Transaction` documents. This is highly inefficient (O(N) unbounded reads) and inaccurate if the transaction list is paginated. The solution is to leverage the existing `daily_stats` subcollection (`stores/{storeId}/daily_stats/{date}`) to pre-aggregate all required metrics (Time-Series Rollup).

## Root Causes

1. **Incomplete Schema:** `DailyStatsModel` and `StatsRepository.updateStatsOnTransaction` only track `transactionCount`, `totalAmount`, `totalCommission`, and `totalServiceFee`. They lack necessary fields like send/receive counts and debt metrics.
2. **BUG-03 (Daily Summary):** `TransactionProvider.todaySummary` computes metrics by locally filtering `_transactions`.
3. **BUG-04 (Date Filter):** `StatisticsProvider.fetchFilteredStats` fetches ALL transactions and filters them locally. It falls back to global summary for non-today ranges because `StatsRepository` lacks a date range query.

## Functional Requirements

### FR-1: Expand `daily_stats` Schema
- **Update `DailyStatsModel`**: Add `sendCount`, `receiveCount`, `totalSentAmount`, `totalReceivedAmount`, `openDebtsCount`, `totalOpenAmount`, `paidDebtsCount`, `totalPaidAmount`. Provide default 0 values in `empty()` and handle in `fromMap`/`toMap`.
- **Update `StatsRepository.updateStatsOnTransaction`**: Increment the new fields based on `transactionType` (send/receive).
- **Update `StatsRepository.incrementOpenDebtStats` / `decrementOpenDebtStats`**: Ensure these methods also increment the corresponding fields in the `daily_stats` document for the current day.

### FR-2: Fix BUG-03 (TransactionProvider Today Summary)
- Remove the local filtering logic in `TransactionProvider._recomputeTodayTransactions` / `todaySummary`.
- Inside `TransactionProvider`, explicitly fetch today's `daily_stats` document from `StatsRepository` and map it to its `_summary` variable. This ensures the UI code remains completely untouched and safe from `ProviderNotFoundException`.

### FR-3: Fix BUG-04 (Stats Date Filter)
- **Add `StatsRepository.getStatsByDateRange`**:
  ```dart
  Future<Map<String, dynamic>> getStatsByDateRange(String storeId, DateTime start, DateTime end)
  ```
  - Query `stores/{storeId}/daily_stats` where document ID (or date field) is `>= format(start)` and `<= format(end)`.
  - Iterate and aggregate all numeric fields into a single Map.
  - *Crucial*: Exclude `totalBalance` and `totalWallets` (balances cannot be summed across days).
- **Update `StatisticsProvider.fetchFilteredStats`**:
  - Replace the unbounded `_transactionRepository.getTransactions` fetch.
  - Call `_statsRepository.getStatsByDateRange` and set the result to `_filteredStats`.

## Non-Functional Requirements

- **NFR-1: Efficiency**: Date filtering must perform exactly $O(days)$ reads, never $O(transactions)$.
- **NFR-2: Safe Field Increments**: Use `FieldValue.increment()` for all writes to prevent race conditions.

## Acceptance Criteria

- [ ] `DailyStatsModel` includes all required fields.
- [ ] `updateStatsOnTransaction` increments new fields correctly based on transaction type.
- [ ] `getStatsByDateRange` aggregates metrics correctly across multiple `daily_stats` documents.
- [ ] `StatisticsProvider` uses `getStatsByDateRange` for filtered stats.
- [ ] Date filtering in UI displays correct aggregated data.
- [ ] `TransactionProvider` fetches today's summary directly from `daily_stats`.
- [ ] Unit tests for `getStatsByDateRange` aggregation logic pass.

## Out of Scope
- Migrating existing historical transactions into the new `daily_stats` format (handled separately or assumed zero for old fields).
