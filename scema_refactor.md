Act as an Elite Cloud/Software Architect. We are executing a massive Firebase Schema Refactor and decoupling our data sources. The current state has severe mapping conflicts and data redundancy. 

Execute the following 3-Part Master Plan immediately and in sequence. Do NOT stop for approvals, output the corrected files once everything is implemented.

### Part 1: Schema Rebuild (Data Models)
**Targets:** `stats_summary_model.dart` & `daily_stats_model.dart`
1. **Update `StatsSummaryModel`:** - STRICTLY REMOVE these 6 fields: `totalCommissionToday`, `totalReceivedAmountToday`, `totalSentAmountToday`, `totalTransactionsToday`, `totalServiceFee`, `totalServiceFeeToday`.
   - KEEP: `totalTransactions`, `totalSentAmount`, `totalReceivedAmount`, `totalCommission`, `totalOpenAmount`, `totalPaidAmount`, `totalWallets`, `openDebtsCount`.
   - Update `fromMap` and `toMap` accordingly. Ensure default values (`?? 0`) are used to prevent null errors with old documents.
2. **Update `DailyStatsModel`:**
   - REDEFINE to match this exact schema: `sendCount`, `receiveCount`, `totalSentAmount`, `totalReceivedAmount`, `totalTransactions`, `totalCommission`, `openDebtsCount`, `paidDebtsCount`, `totalOpenAmount`, `totalPaidAmount`. 
   - REMOVE old fields like `totalAmount` or `totalServiceFee` completely. 
   - Update `fromMap` and `toMap` to gracefully default missing fields to `0`.

### Part 2: Fix Data Layer & Aggregation
**Targets:** `stats_repository.dart` & `statistics_provider.dart`
3. **Update `getStatsByDateRange` (Repository):** - Ensure the loop aggregation ONLY folds the exact numerical keys present in the newly defined `DailyStatsModel`. Do NOT aggregate dead/deleted keys.
4. **Rewrite `fetchFilteredStats` (Provider):** - Delete the messy `if (isToday)` logic that mixes lifetime and daily variables. 
   - Always rely on the Repository `getStatsByDateRange` to fetch the specific daily_stats document(s). Map the result directly to the UI map using the new schema names.
5. **Rewrite `addTransactionOptimistically` (Provider):**
   - Ensure this method increments `totalSentAmount`, `totalReceivedAmount`, etc., strictly according to the new `StatsSummaryModel` and `DailyStatsModel` variables.

### Part 3: UI Data Routing
**Targets:** `dashboard_quick_stats.dart` & `general_statistics_screen.dart`
6. **Dashboard Quick Stats Routing:**
   - "Total Wallets" card -> reads `provider.dashboardSummary.totalWallets`.
   - "Open Debts" card -> reads `provider.dashboardSummary.openDebtsCount`.
   - "Total Transactions" card -> reads `provider.todayStats?.totalTransactions`.
   - "Total Commission" card -> reads `provider.todayStats?.totalCommission`.
7. **Statistics Screen UI Mapping:**
   - Update `_buildStatistics` (or similar UI builders) to read the strictly defined schema properties. Ensure it no longer calls `.totalAmount` or any deleted properties.

Review your code thoroughly for missing getters or type mismatches. Provide the full code for `stats_summary_model.dart`, `daily_stats_model.dart`, `statistics_provider.dart`, and `dashboard_quick_stats.dart`.