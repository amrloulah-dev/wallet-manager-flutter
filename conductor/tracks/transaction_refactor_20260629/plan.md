# Implementation Plan: Transaction Engine Dynamic Settings Refactor

## Phase 1: Dynamic Settings Model & Cached Provider [checkpoint: 25e4f0f]

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

- [x] Task: Create `PlatformSettingsProvider` [5f5a1a2]
    - [x] Define `PlatformSettingsProvider` extending `SafeChangeNotifier` at `lib/providers/platform_settings_provider.dart`
    - [x] Inject `LocalStorageService` and Firestore instance via constructor
    - [x] Implement `initialize()` method with 24-hour TTL check logic:
        - Read `last_platform_settings_fetch_time` from `LocalStorageService`
        - If null or > 24h: fetch from Firestore `settings/global`, cache JSON + timestamp, load into RAM, `safeNotify()`
        - If < 24h: deserialize from `LocalStorageService` cache synchronously
    - [x] Implement `forceRefresh()` method bypassing TTL check
    - [x] Expose `PlatformSettingsModel` via public `settings` getter
    - [x] Handle Firestore fetch failure gracefully (fall back to cache or defaults)

- [x] Task: Write Tests — `PlatformSettingsProvider` [5f5a1a2]
    - [x] Test initialization with no cache (first launch) — fetches from Firestore
    - [x] Test initialization with fresh cache (< 24h) — loads from local storage
    - [x] Test initialization with stale cache (> 24h) — re-fetches from Firestore
    - [x] Test `forceRefresh()` bypasses TTL and fetches fresh data
    - [x] Test Firestore fetch failure falls back to cached/default values
    - [x] Test `safeNotify()` is called after successful fetch

- [x] Task: Register `PlatformSettingsProvider` in DI & Widget Tree [c9f0c0a]
    - [x] Register as lazy singleton in `service_locator.dart` via `sl.registerLazySingleton<PlatformSettingsProvider>(...)`
    - [x] Add `ChangeNotifierProvider` for `PlatformSettingsProvider` in the app's provider tree (`app.dart`)
    - [x] Call `initialize()` during app startup in `main.dart` (after `setupServiceLocator()`)

- [x] Task: Conductor - User Manual Verification 'Phase 1: Dynamic Settings Model & Cached Provider' (Protocol in workflow.md) [25e4f0f]

## Phase 2: Hardcoded Logic Cleanup & Injection

- [x] Task: Write Tests — Dynamic `FeeCalculator` [afc0f9f]
    - [x] Test Vodafone same-network fee using dynamic settings value
    - [x] Test cross-network percentage fee using dynamic settings rates/min/max
    - [x] Test InstaPay fee using dynamic settings rates/min/max
    - [x] Test with non-default settings values (verify no residual hardcoding)
    - [x] Test edge cases: zero amount, boundary amounts at min/max fees

- [x] Task: Refactor `FeeCalculator` to Accept Dynamic Settings [afc0f9f]
    - [x] Add `PlatformSettingsModel settings` parameter to `calculateTransactionFee()`
    - [x] Replace hardcoded `1.0` (same-network fee) with `settings.serviceFees.sameNetworkFee`
    - [x] Replace hardcoded `0.005`, `1.0`, `15.0` (cross-network) with `settings.serviceFees` / `settings.feeLimits` paths
    - [x] Replace hardcoded `0.001`, `0.5`, `20.0` (InstaPay) with dynamic settings paths
    - [x] Update all call-sites:
        - `overlay_usecase.dart` (line ~63)
        - `transaction_fee_calculator.dart` (line ~54)
        - `overlay_provider.dart` (lines ~139, ~203)

- [x] Task: Write Tests — Dynamic Limit Validation in `TransactionProvider` [1be1289]
    - [x] Test `createTransaction` rejects amount exceeding dynamic InstaPay transaction limit
    - [x] Test `createTransaction` rejects amount exceeding dynamic wallet-tier transaction limit
    - [x] Test `createTransaction` allows amount within dynamic limits
    - [x] Test with modified settings values (different from defaults)

- [x] Task: Refactor `TransactionProvider` for Dynamic Limits [1be1289]
    - [x] Inject `PlatformSettingsProvider` into `TransactionProvider` (via `sl<PlatformSettingsProvider>()`)
    - [x] Replace hardcoded IF conditions in `createTransaction()` with dynamic limit reads from `PlatformSettingsModel`
    - [x] Verify existing optimistic UI / fetch-shield / rollback logic is untouched

- [x] Task: Clean Up `AppConstants` and Update Call-Sites [1be1289]
    - [x] Remove 8 hardcoded limit constants from `app_constants.dart`
    - [x] Update `wallet_model.dart` (lines ~371-384): replace `AppConstants.*Limit` references with dynamic settings
    - [x] Update `wallet_form_screen.dart` (lines ~338-359): replace `AppConstants.*Limit` references with dynamic settings
    - [x] Verify `flutter analyze` passes cleanly after all changes

- [x] Task: Conductor - User Manual Verification 'Phase 2: Hardcoded Logic Cleanup & Injection' (Protocol in workflow.md)

## Phase 3: WriteBatch Enhancement & Admin UI

- [x] Task: Write Tests — WriteBatch Global Stats Increment [be56d3e]
    - [x] Test that `createTransaction` WriteBatch includes 5th operation for `stats/global`
    - [x] Test that `totalTransactions` is incremented by 1 via `FieldValue.increment(1)`
    - [x] Test that `SetOptions(merge: true)` is used (no overwrite of other fields)
    - [x] Test that existing 4 batch operations remain untouched

- [x] Task: Add Global Stats Increment to `TransactionRepository.createTransaction()` [be56d3e]
    - [x] Add 5th WriteBatch operation: `batch.set(globalStatsRef, {'totalTransactions': FieldValue.increment(1)}, SetOptions(merge: true))`
    - [x] Verify existing 4 batch operations are not modified

- [~] Task: Add Manual Refresh UI to Admin/Settings Screen
    - [ ] Add "Refresh Platform Settings" button/tile to the settings or admin screen
    - [ ] On tap, call `PlatformSettingsProvider.forceRefresh()`
    - [ ] Display success/failure feedback (SnackBar or similar)
    - [ ] Use `Consumer` or `Selector` for reactive UI (not blanket `watch`)

- [~] Task: Write Tests — Manual Refresh UI
    - [ ] Widget test: verify refresh button is rendered
    - [ ] Widget test: verify tapping refresh button triggers `forceRefresh()`
    - [ ] Widget test: verify success/failure feedback is displayed

- [~] Task: Final Static Analysis & Integration Verification
    - [ ] Run `flutter analyze` — zero new warnings/errors
    - [ ] Run full test suite `CI=true flutter test` — all tests pass
    - [ ] Verify coverage > 80% for new code

- [ ] Task: Conductor - User Manual Verification 'Phase 3: WriteBatch Enhancement & Admin UI' (Protocol in workflow.md)
