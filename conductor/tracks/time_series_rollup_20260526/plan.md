# Plan: Implement Time-Series Rollup Architecture (BUG-03 & BUG-04)

## Phase 1: Expand Schema and Update Increments [checkpoint: 6dc6672]

- [x] Task: Update `DailyStatsModel` schema [7997284]
    - [x] Add `sendCount`, `receiveCount`, `totalSentAmount`, `totalReceivedAmount`, `openDebtsCount`, `totalOpenAmount`, `paidDebtsCount`, `totalPaidAmount`.
    - [x] Update `fromMap`, `toMap`, `empty`, and `copyWith` methods.
- [x] Task: Update `StatsRepository` increments [cbd9b7a]
    - [x] Modify `updateStatsOnTransaction` to increment `sendCount`/`receiveCount` and `totalSentAmount`/`totalReceivedAmount` based on `transactionType`.
    - [x] Modify `incrementOpenDebtStats` and `decrementOpenDebtStats` to write to the `daily_stats` document for the current day.

## Phase 2: Fix BUG-03 (TransactionProvider Today Summary) [checkpoint: 7e67bd7]

- [x] Task: Implement `fetchTodaySummary` in `TransactionProvider` [7e67bd7]
    - [x] Add a method to fetch today's `daily_stats` via `StatsRepository`.
    - [x] Map the fetched `DailyStatsModel` properties to the `_summary` map.
    - [x] Remove local filtering logic for summary calculation.

## Phase 3: Fix BUG-04 (Stats Date Filter) [checkpoint: f7710ac]

- [x] Task: Implement `getStatsByDateRange` in `StatsRepository` [3b59523]
    - [x] Query `daily_stats` where document ID is between `start` and `end` formatted as strings (`yyyy-MM-dd`).
    - [x] Aggregate all numeric fields.
    - [x] Exclude `totalBalance` and `totalWallets`.
- [x] Task: Update `StatisticsProvider.fetchFilteredStats` [3b59523]
    - [x] Replace unbounded transaction fetch with `_statsRepository.getStatsByDateRange`.
    - [x] Update `_filteredStats` with the aggregated result.

## Phase 4: Verification

- [x] Task: Conductor - User Manual Verification 'Phase 4: Verification' (Protocol in workflow.md) [7036a8a]
