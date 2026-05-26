# Plan: Implement Time-Series Rollup Architecture (BUG-03 & BUG-04)

## Phase 1: Expand Schema and Update Increments [checkpoint: 6dc6672]

- [x] Task: Update `DailyStatsModel` schema [7997284]
    - [x] Add `sendCount`, `receiveCount`, `totalSentAmount`, `totalReceivedAmount`, `openDebtsCount`, `totalOpenAmount`, `paidDebtsCount`, `totalPaidAmount`.
    - [x] Update `fromMap`, `toMap`, `empty`, and `copyWith` methods.
- [x] Task: Update `StatsRepository` increments [cbd9b7a]
    - [x] Modify `updateStatsOnTransaction` to increment `sendCount`/`receiveCount` and `totalSentAmount`/`totalReceivedAmount` based on `transactionType`.
    - [x] Modify `incrementOpenDebtStats` and `decrementOpenDebtStats` to write to the `daily_stats` document for the current day.

## Phase 2: Fix BUG-03 (TransactionProvider Today Summary)

- [x] Task: Implement `fetchTodaySummary` in `TransactionProvider` [7e67bd7]
    - [x] Add a method to fetch today's `daily_stats` via `StatsRepository`.
    - [x] Map the fetched `DailyStatsModel` properties to the `_summary` map.
    - [x] Remove local filtering logic for summary calculation.

## Phase 3: Fix BUG-04 (Stats Date Filter)

- [~] Task: Implement `getStatsByDateRange` in `StatsRepository`
    - [ ] Query `daily_stats` where document ID is between `start` and `end` formatted as strings (`yyyy-MM-dd`).
    - [ ] Aggregate all numeric fields.
    - [ ] Exclude `totalBalance` and `totalWallets`.
- [ ] Task: Update `StatisticsProvider.fetchFilteredStats`
    - [ ] Replace unbounded transaction fetch with `_statsRepository.getStatsByDateRange`.
    - [ ] Update `_filteredStats` with the aggregated result.

## Phase 4: Verification

- [ ] Task: Conductor - User Manual Verification 'Phase 4: Verification' (Protocol in workflow.md)
