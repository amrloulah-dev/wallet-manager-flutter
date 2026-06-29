# Implementation Plan: Transaction Engine Dynamic Settings Refactor

## Phase 1: Dynamic Settings Model & Cached Provider

- [x] Task: Create `PlatformSettingsModel` [7b76eaf]
    - [x] Define `PlatformSettingsModel` class at `lib/data/models/platform_settings_model.dart`
    - [x] Map nested Firestore structure: `limits`, `feeLimits`, `serviceFees`, `subscriptions`
    - [x] Implement `fromJson(Map<String, dynamic>)` factory with null-safe parsing via `NumberParser`
    - [x] Implement `toJson()` for serialization to `LocalStorageService`
    - [x] Define safe defaults mirroring current `AppConstants` hardcoded values
    - [x] Add `kDebugMode`-guarded warning log when defaults are active

- [x] Task: Write Tests — `PlatformSettingsModel` [7b76eaf]
    - [x] Test `fromJson` with complete valid data
    - [x] Test `fromJson` with partial/missing fields (safe defaults kick in)
    - [x] Test `fromJson` with null input (full defaults)
    - [x] Test `toJson` round-trip serialization
    - [x] Test that default values match current `AppConstants` values exactly

- [ ] Task: Create `PlatformSettingsProvider`
    - [ ] Define `PlatformSettingsProvider` extending `SafeChangeNotifier` at `lib/providers/platform_settings_provider.dart`
    - [ ] Inject `LocalStorageService` and Firestore instance via constructor
    - [ ] Implement `initialize()` method with 24-hour TTL check logic:
        - Read `last_platform_settings_fetch_time` from `LocalStorageService`
        - If null or > 24h: fetch from Firestore `settings/global`, cache JSON + timestamp, load into RAM, `safeNotify()`
        - If < 24h: deserialize from `LocalStorageService` cache synchronously
    - [ ] Implement `forceRefresh()` method bypassing TTL check
    - [ ] Expose `PlatformSettingsModel` via public `settings` getter
    - [ ] Handle Firestore fetch failure gracefully (fall back to cache or defaults)

- [ ] Task: Write Tests — `PlatformSettingsProvider`
    - [ ] Test initialization with no cache (first launch) — fetches from Firestore
    - [ ] Test initialization with fresh cache (< 24h) — loads from local storage
    - [ ] Test initialization with stale cache (> 24h) — re-fetches from Firestore
    - [ ] Test `forceRefresh()` bypasses TTL and fetches fresh data
    - [ ] Test Firestore fetch failure falls back to cached/default values
    - [ ] Test `safeNotify()` is called after successful fetch

- [ ] Task: Register `PlatformSettingsProvider` in DI & Widget Tree
    - [ ] Register as lazy singleton in `service_locator.dart` via `sl.registerLazySingleton<PlatformSettingsProvider>(...)`
    - [ ] Add `ChangeNotifierProvider` for `PlatformSettingsProvider` in the app's provider tree (`app.dart`)
    - [ ] Call `initialize()` during app startup in `main.dart` (after `setupServiceLocator()`)

- [ ] Task: Conductor - User Manual Verification 'Phase 1: Dynamic Settings Model & Cached Provider' (Protocol in workflow.md)

## Phase 2: Hardcoded Logic Cleanup & Injection

- [ ] Task: Write Tests — Dynamic `FeeCalculator`
    - [ ] Test Vodafone same-network fee using dynamic settings value
    - [ ] Test cross-network percentage fee using dynamic settings rates/min/max
    - [ ] Test InstaPay fee using dynamic settings rates/min/max
    - [ ] Test with non-default settings values (verify no residual hardcoding)
    - [ ] Test edge cases: zero amount, boundary amounts at min/max fees

- [ ] Task: Refactor `FeeCalculator` to Accept Dynamic Settings
    - [ ] Add `PlatformSettingsModel settings` parameter to `calculateTransactionFee()`
    - [ ] Replace hardcoded `1.0` (same-network fee) with `settings.serviceFees.sameNetworkFee`
    - [ ] Replace hardcoded `0.005`, `1.0`, `15.0` (cross-network) with `settings.serviceFees` / `settings.feeLimits` paths
    - [ ] Replace hardcoded `0.001`, `0.5`, `20.0` (InstaPay) with dynamic settings paths
    - [ ] Update all call-sites:
        - `overlay_usecase.dart` (line ~63)
        - `transaction_fee_calculator.dart` (line ~54)
        - `overlay_provider.dart` (lines ~139, ~203)

- [ ] Task: Write Tests — Dynamic Limit Validation in `TransactionProvider`
    - [ ] Test `createTransaction` rejects amount exceeding dynamic InstaPay transaction limit
    - [ ] Test `createTransaction` rejects amount exceeding dynamic wallet-tier transaction limit
    - [ ] Test `createTransaction` allows amount within dynamic limits
    - [ ] Test with modified settings values (different from defaults)

- [ ] Task: Refactor `TransactionProvider` for Dynamic Limits
    - [ ] Inject `PlatformSettingsProvider` into `TransactionProvider` (via `sl<PlatformSettingsProvider>()`)
    - [ ] Replace hardcoded IF conditions in `createTransaction()` with dynamic limit reads from `PlatformSettingsModel`
    - [ ] Verify existing optimistic UI / fetch-shield / rollback logic is untouched

- [ ] Task: Clean Up `AppConstants` and Update Call-Sites
    - [ ] Remove 8 hardcoded limit constants from `app_constants.dart`
    - [ ] Update `wallet_model.dart` (lines ~371-384): replace `AppConstants.*Limit` references with dynamic settings
    - [ ] Update `wallet_form_screen.dart` (lines ~338-359): replace `AppConstants.*Limit` references with dynamic settings
    - [ ] Verify `flutter analyze` passes cleanly after all changes

- [ ] Task: Conductor - User Manual Verification 'Phase 2: Hardcoded Logic Cleanup & Injection' (Protocol in workflow.md)

## Phase 3: WriteBatch Enhancement & Admin UI

- [ ] Task: Write Tests — WriteBatch Global Stats Increment
    - [ ] Test that `createTransaction` WriteBatch includes 5th operation for `stats/global`
    - [ ] Test that `totalTransactions` is incremented by 1 via `FieldValue.increment(1)`
    - [ ] Test that `SetOptions(merge: true)` is used (no overwrite of other fields)
    - [ ] Test that existing 4 batch operations remain untouched

- [ ] Task: Add Global Stats Increment to `TransactionRepository.createTransaction()`
    - [ ] Add 5th WriteBatch operation: `batch.set(globalStatsRef, {'totalTransactions': FieldValue.increment(1)}, SetOptions(merge: true))`
    - [ ] Verify existing 4 batch operations are not modified

- [ ] Task: Add Manual Refresh UI to Admin/Settings Screen
    - [ ] Add "Refresh Platform Settings" button/tile to the settings or admin screen
    - [ ] On tap, call `PlatformSettingsProvider.forceRefresh()`
    - [ ] Display success/failure feedback (SnackBar or similar)
    - [ ] Use `Consumer` or `Selector` for reactive UI (not blanket `watch`)

- [ ] Task: Write Tests — Manual Refresh UI
    - [ ] Widget test: verify refresh button is rendered
    - [ ] Widget test: verify tapping refresh button triggers `forceRefresh()`
    - [ ] Widget test: verify success/failure feedback is displayed

- [ ] Task: Final Static Analysis & Integration Verification
    - [ ] Run `flutter analyze` — zero new warnings/errors
    - [ ] Run full test suite `CI=true flutter test` — all tests pass
    - [ ] Verify coverage > 80% for new code

- [ ] Task: Conductor - User Manual Verification 'Phase 3: WriteBatch Enhancement & Admin UI' (Protocol in workflow.md)
