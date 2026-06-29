# Specification: Transaction Engine Dynamic Settings Refactor

## Overview
Refactor the mobile app's financial transaction engine to replace all hardcoded fees and limits with dynamic values fetched from Firestore (`settings/global`), implement a 24-hour local cache using `LocalStorageService`, add a manual refresh capability from the admin/settings screen, and append a global stats increment to the `WriteBatch` in the transaction repository.

**CRITICAL CONSTRAINT:** The Optimistic UI (snapshot) logic, `_activateFetchShield`, and `_rollbackLocalTx` mechanisms in the existing transaction flow MUST NOT be altered.

## Track Type
Refactor

## Functional Requirements

### FR-1: PlatformSettingsModel
- Create `PlatformSettingsModel` at `lib/data/models/platform_settings_model.dart`.
- The model MUST map the full structure of the Firestore `settings/global` document, including nested maps for: `limits`, `feeLimits`, `serviceFees`, `subscriptions`.
- Provide `fromJson(Map<String, dynamic>)` factory and `toJson()` method.
- Provide robust **safe default values** for every field that mirror the current hardcoded values in `app_constants.dart`:
  - `newWalletTransactionLimit`: 10000.0
  - `newWalletMonthlyLimit`: 60000.0
  - `oldWalletTransactionLimit`: 60000.0
  - `oldWalletMonthlyLimit`: 200000.0
  - `registeredStoreTransactionLimit`: 60000.0
  - `registeredStoreMonthlyLimit`: 400000.0
  - `instapayTransactionLimit`: 120000.0
  - `instapayMonthlyLimit`: 400000.0
  - Same-network fee: 1.0 EGP
  - Cross-network: rate 0.005, min 1.0, max 15.0
  - InstaPay: rate 0.001, min 0.5, max 20.0
- When defaults are used (Firestore unreachable on first launch), log a **warning** via `debugPrint` guarded by `kDebugMode`.

### FR-2: PlatformSettingsProvider
- Create `PlatformSettingsProvider` extending `SafeChangeNotifier` at `lib/providers/platform_settings_provider.dart`.
- **24-hour cache logic:**
  1. On initialization, check `last_platform_settings_fetch_time` via `LocalStorageService`.
  2. If null or > 24 hours old → fetch from Firestore `settings/global`, serialize JSON to `LocalStorageService`, update timestamp, load into RAM, call `safeNotify()`.
  3. If < 24 hours old → deserialize directly from `LocalStorageService` JSON into RAM synchronously.
- **Manual refresh:** Expose a `forceRefresh()` method that bypasses the TTL check, fetches fresh from Firestore, updates cache, calls `safeNotify()`.
- **DI Integration:**
  - Register as lazy singleton in GetIt (`sl<PlatformSettingsProvider>()`) for use by repositories/services.
  - Also wrap with `ChangeNotifierProvider` in the widget tree for UI reactivity.
- Expose the loaded `PlatformSettingsModel` as a public getter.

### FR-3: AppConstants Cleanup
- Remove all hardcoded transaction/monthly limit constants from `app_constants.dart`:
  - `newWalletTransactionLimit`, `newWalletMonthlyLimit`
  - `oldWalletTransactionLimit`, `oldWalletMonthlyLimit`
  - `registeredStoreTransactionLimit`, `registeredStoreMonthlyLimit`
  - `instapayTransactionLimit`, `instapayMonthlyLimit`
- Retain `appName`, `appVersion`, `trialDurationDays`.
- Update ALL call-sites to read from `PlatformSettingsModel` instead.

### FR-4: Dynamic Limit Validation in TransactionProvider
- In `TransactionProvider.createTransaction()`, replace all hardcoded IF conditions (e.g., `if (isInstaPay && amount > 70000)`) with dynamic validation reading limits from the injected `PlatformSettingsModel`.
- The provider MUST receive `PlatformSettingsProvider` via constructor injection or `sl<PlatformSettingsProvider>()`.

### FR-5: Dynamic Fee Calculator
- Update `FeeCalculator.calculateTransactionFee()` to accept a `PlatformSettingsModel settings` parameter.
- Replace all hardcoded fee numbers (`1.0`, `0.005`, `15.0`, `0.001`, `20.0`, `0.5`) with dynamic paths from `settings.serviceFees` and `settings.feeLimits`.
- All call-sites of `calculateTransactionFee` MUST be updated to pass the settings parameter.

### FR-6: WriteBatch Global Stats Increment
- In `TransactionRepository.createTransaction()`, add a 5th operation to the existing `WriteBatch`:
  ```dart
  final globalStatsRef = _firestore.collection('stats').doc('global');
  batch.set(globalStatsRef, {
    'totalTransactions': FieldValue.increment(1)
  }, SetOptions(merge: true));
  ```
- The existing 4 batch operations MUST remain untouched.

### FR-7: Admin Manual Refresh UI
- Add a "Refresh Platform Settings" action accessible from the settings/admin screen.
- On tap, invoke `PlatformSettingsProvider.forceRefresh()` and display a success/failure feedback.

## Non-Functional Requirements

### NFR-1: Backward Compatibility
- Safe defaults MUST mirror current hardcoded values exactly — the app should behave identically when offline on first launch.

### NFR-2: No Regression on Optimistic UI
- The existing snapshot, fetch-shield, and rollback mechanisms MUST NOT be modified.

### NFR-3: Unified Vault Architecture Compliance
- All local storage operations MUST go through `LocalStorageService`, NOT direct `SharedPreferences` access.

### NFR-4: Static Analysis
- `flutter analyze` MUST pass with zero new warnings or errors.

## Acceptance Criteria

1. ✅ `PlatformSettingsModel` correctly deserializes the `settings/global` Firestore document and provides safe defaults.
2. ✅ On first launch with Firestore available, settings are fetched, cached, and loaded into RAM.
3. ✅ On subsequent launches within 24 hours, settings load from `LocalStorageService` cache without a Firestore call.
4. ✅ After 24 hours, settings auto-refresh from Firestore on next app launch.
5. ✅ Manual refresh from admin screen bypasses TTL and fetches fresh settings.
6. ✅ All hardcoded limits removed from `AppConstants`; all call-sites use dynamic model.
7. ✅ `FeeCalculator` uses dynamic fee values from `PlatformSettingsModel`.
8. ✅ `TransactionProvider` validates against dynamic limits.
9. ✅ `WriteBatch` in transaction repository includes global stats increment.
10. ✅ Existing optimistic UI, fetch-shield, and rollback logic are untouched.
11. ✅ `flutter analyze` passes cleanly.
12. ✅ All new code has corresponding unit tests with >80% coverage.

## Out of Scope

- Changes to the Firestore `settings/global` document structure (already exists).
- Firestore Security Rules changes for the `settings/global` document.
- Changes to the Optimistic UI snapshot/rollback logic.
- Migration or versioning strategy for the `settings/global` schema.
- Background isolate integration (settings are main-isolate only for now).
