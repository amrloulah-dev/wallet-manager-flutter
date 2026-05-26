You are acting as a Senior Software Architect. We have 5 specific bugs (BUG-01 to BUG-05) that require precise architectural fixes. Please execute the following 4-Phase implementation plan perfectly. Do NOT refactor logic outside of these explicit instructions.

### PHASE 1: Fix Firestore Security Rules (BUG-02)
**Goal:** Fix `permission-denied` on employee `list` queries.
- **File:** `firestore.rules`
- **Action:** Locate the `employees` or `users` collection rules. Split the `read` rule into `get` and `list`.
- **Logic:** - `allow get: if isAuthenticated() && isStoreOwner(resource.data.storeId);`
  - `allow list: if isAuthenticated() && isStoreOwner(request.auth.uid);` (or rely on query validation). Firestore cannot evaluate `resource.data` on list queries. Ensure `addEmployee` and fetching lists works for the store owner.

### PHASE 2: Fix UI Overflow (BUG-05)
**Goal:** Prevent RenderFlex overflow on the Balance stat card.
- **File:** `lib/presentation/screens/statistics/general_statistics_screen.dart`
- **Action:** In the `StatItemWidget`, locate the `Row` holding the labels and values.
- **Logic:** Wrap the `Column` containing the `label` and `subtitle` inside a `Flexible` widget (with `fit: FlexFit.loose`). Add `overflow: TextOverflow.ellipsis` to the `label` Text widget as a fallback edge-case handler.

### PHASE 3: Refactor Wallet Creation (BUG-01)
**Goal:** Fix `wallet_error_create_failed` caused by illegal async calls inside `runTransaction`.
- **Files:** `wallet_repository.dart` and `stats_repository.dart`.
- **Action:** Migrate wallet creation from `Transaction` to `WriteBatch`.
- **Logic:**
  1. In `StatsRepository.updateStatsOnWalletChange`, change the optional `Transaction` parameter to accept a `WriteBatch batch` instead. Use `batch.update(...)` or `batch.set(...)` accordingly.
  2. In `WalletRepository.createWallet`, remove `_firestore.runTransaction`. Instead, initialize a `final batch = _firestore.batch();`.
  3. Add the wallet to the batch: `batch.set(walletRef, wallet.toFirestore());`.
  4. Call `await _statsRepository.updateStatsOnWalletChange(..., batch: batch);`.
  5. Finally, commit the batch: `await batch.commit();`. This guarantees atomicity without async/await violations.

### PHASE 4: Implement Time-Series Rollup Architecture (BUG-03 & BUG-04)
**Goal:** Fix Daily Summary Zeros and Stats Date Filter using efficient Pre-aggregation.
- **Files:** `stats_repository.dart`, `transaction_provider.dart`, `statistics_provider.dart`.
- **Logic Details:**
  1. **Schema Expansion:** In `StatsRepository` (where daily stats are updated, likely `updateStatsOnTransaction`), expand the `daily_stats` document fields. Ensure it increments ALL these fields correctly based on the transaction/debt type: `sendCount`, `receiveCount`, `totalSentAmount`, `totalReceivedAmount`, `openDebtsCount`, `totalOpenAmount`, `paidDebtsCount`, `totalPaidAmount`, `totalCommission`, `totalAmount`, `transactionCount`. (Edge case: use `FieldValue.increment()` safely).
  2. **Daily Summary (BUG-03):** In `TransactionProvider`, remove the local filtering for `_todayTransactions` summary. Add a method `fetchTodaySummary()` that directly reads `daily_stats/{YYYY-MM-DD}` (using the local current date formatted as the document ID). Map this single document to the `_summary` variable. Handle the edge case where the document doesn't exist yet (return 0 for all fields).
  3. **Date Filter (BUG-04):** Add `Future<Map<String, dynamic>> getStatsByDateRange(String storeId, DateTime start, DateTime end)` in `StatsRepository`.
     - Query `daily_stats` where document ID (or date string field) is `>= format(start)` and `<= format(end)`.
     - Iterate through the returned documents.
     - *Edge Case Handling:* Initialize a map with 0 for all fields. Sum up all numeric fields locally. EXCLUDE `totalBalance` from the aggregation (as balances cannot be summed across days).
     - Update `StatisticsProvider.fetchFilteredStats(DateTimeRange)` to call this new method and set `_filteredStats` to the aggregated result.

Please confirm once you have applied all 4 phases, and provide a brief summary of the updated code blocks.