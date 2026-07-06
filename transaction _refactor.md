# Context & Objective
We are executing the refactor of the mobile app's financial transaction engine. 
Goal: Replace hardcoded fees and limits with dynamic values fetched from Firestore (`settings/global`), implement a 24-hour local cache using `SharedPreferences`, and add a global stats increment.
CRITICAL: Do NOT alter the Optimistic UI (snapshot) logic, `_activateFetchShield`, or `_rollbackLocalTx` mechanisms.

# Phase 1: Dynamic Settings & 24-Hour Cache
1. **Model**: Create `PlatformSettingsModel` mapping the structure of `/settings/global` (limits, feeLimits, serviceFees, subscriptions). Include `fromJson`/`toJson` and robust Safe Default values for all fields in case of offline first-launch.
2. **Service/Provider**: Create `PlatformSettingsProvider` using `SharedPreferences`. 
   - Logic: Check `last_fetch_time`. If null or > 24 hours old, fetch from Firestore (`settings/global`), save JSON to SharedPreferences, update timestamp, and load into RAM. 
   - If < 24 hours old, load directly from SharedPreferences JSON into RAM synchronously.

# Phase 2: Cleanup Hardcoded Logic (Injection Phase)
1. **AppConstants**: Open `c:\src\walletmanager\lib\core\constants\app_constants.dart` and REMOVE all hardcoded transaction/monthly limits (e.g., `instapayTransactionLimit`, `newWalletMonthlyLimit`, etc.).
2. **Provider Limits Validation**: Open `c:\src\walletmanager\lib\providers\transaction_provider.dart`. 
   - Locate the hardcoded IF conditions in `createTransaction` (e.g., `if (isInstaPay && amount > 70000)`). 
   - Replace these with dynamic validation reading from the injected `PlatformSettingsModel`.
3. **Fee Calculator Engine**: Open `c:\src\walletmanager\lib\core\utils\fee_calculator.dart`.
   - Update `calculateTransactionFee` to accept `PlatformSettingsModel settings`.
   - Replace the hardcoded numbers (`1.0`, `0.005`, `15.0`, `0.001`, `20.0`) inside the switch cases with the dynamic paths from `settings.serviceFees` and `settings.feeLimits`.

# Phase 3: The WriteBatch Enhancement
1. Open `c:\src\walletmanager\lib\data\repositories\transaction_repository.dart`.
2. Locate `createTransaction` and its `WriteBatch`.
3. The current batch does 4 things (txRef, walletUpdateData, statsSummaryRef, dailyStatsRef). Keep them exactly as they are.
4. Add a 5th operation to the batch: 
   ```dart
   final globalStatsRef = _firestore.collection('stats').doc('global');
   batch.set(globalStatsRef, {
     'totalTransactions': FieldValue.increment(1)
   }, SetOptions(merge: true));
Deliverables
Execute these changes step-by-step. Provide the updated code for:

platform_settings_model.dart and platform_settings_provider.dart

app_constants.dart (cleaned up)

fee_calculator.dart (dynamic math)

transaction_provider.dart (dynamic validation logic)

transaction_repository.dart (WriteBatch updated)
Ensure flutter analyze passes perfectly.