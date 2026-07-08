# Implementation Plan: Subscription Model Unification & Store Cleanup

## Phase 1: Model Unification & Cache Safety

- [x] Task: Create `SubscriptionPlanModel` (FR-1) [d690dd1]
    - [x] Write unit tests for `SubscriptionPlanModel` serialization — `fromMap()` with valid data, missing fields (defaults), and `price` as both `int` and `double` values; `toMap()` round-trip
    - [x] Implement `SubscriptionPlanModel` at `lib/data/models/subscription_plan_model.dart` with all 7 fields (`name`, `description`, `isActive`, `price` as `num`, `maxWallets`, `maxEmployees`, `smsEnabled`), `fromMap()` factory, and `toMap()` method
    - [x] Verify all tests pass

- [x] Task: Update `PlatformSettingsModel` — Remove legacy fields & add plans + global variables (FR-2) [4e1501c]
    - [x] Write unit tests for updated `PlatformSettingsModel` — parse new-format JSON with `plans` map and global variables (`gracePeriodHours`, `trialDays`, `lifetimeCountLimit`); parse old-format JSON (with `proPrice`/`lifetimePrice`, no `plans`) verifying graceful handling; round-trip `toJson()`/`fromJson()`; verify `defaults()` returns correct new defaults
    - [x] Remove `proPrice` and `lifetimePrice` fields, their parsing from `fromJson()`, serialization in `toJson()`, and values in `defaults()`
    - [x] Retain `lifetimeCountLimit`; add `gracePeriodHours` (int, default 48) and `trialDays` (int, default 14) — parse from `subscriptions` map in `fromJson()`, serialize in `toJson()`
    - [x] Add `Map<String, SubscriptionPlanModel> plans` field — parse from `subscriptions['plans']` in `fromJson()`, serialize in `toJson()`, default to empty map
    - [x] Verify all tests pass

- [x] Task: Implement self-healing cache mechanism (FR-3) [4099207]
    - [x] Write unit tests for cache invalidation — mock `LocalStorageService` returning malformed JSON, empty string, and schema-mismatched JSON; verify `clearPlatformSettings()` is called and `_fetchFromFirestore()` is triggered; verify no exceptions propagate
    - [x] Add `clearPlatformSettings()` method to `LocalStorageService` if not present (removes both `_kPlatformSettingsJson` and `_kPlatformSettingsFetchTime` keys)
    - [x] Wrap JSON deserialization in `PlatformSettingsProvider.initialize()` with `try-catch`; on failure: clear cache, log via `AppErrorHandler`, and trigger fresh Firestore fetch
    - [x] Verify all tests pass

- [x] Task: Conductor — User Manual Verification 'Phase 1: Model Unification & Cache Safety' (Protocol in workflow.md)

## Phase 2: Store Cleanup & Repository Fix

- [x] Task: Remove `StoreStats` class (FR-4) [f899620]
    - [x] Write unit tests for `StoreModel` without `StoreStats` — verify `fromFirestore()` and `toFirestore()` work correctly without the `stats` field; verify no `StoreStats` references remain
    - [x] Delete the `StoreStats` class from `lib/data/models/store_model.dart`
    - [x] Remove the `StoreStats stats` field from `StoreModel`, and all references in `fromFirestore()` and `toFirestore()`
    - [x] Audit and fix all other files that import or reference `StoreStats`
    - [x] Verify all tests pass

- [x] Task: Clean `StoreSubscription` — remove feature-limit fields (FR-5) [fd7e69c]
    - [x] Write unit tests for trimmed `StoreSubscription` — verify `fromMap()` and `toMap()` only handle state fields (`planId`, `status`, `endDate`, `trialConsumed`, `pendingRequestDate`); verify `migratedLifetime()` works without the removed fields
    - [x] Remove `maxWallets`, `maxEmployees`, and `smsEnabled` fields from the `StoreSubscription` class declaration
    - [x] Remove these fields from `StoreSubscription.fromMap()`, `toMap()`, and the `migratedLifetime()` factory constructor
    - [x] Audit all consumers of the removed fields across the codebase — stub or adapt references (Phase 3 will provide the permanent fix for `SubscriptionProvider` and UI consumers)
    - [x] Verify all tests pass

- [x] Task: Fix `EmployeeRepository` architectural trap (FR-6) [cbec0ff]
    - [x] Write unit tests for `addEmployee()` using `.count()` — mock Firestore aggregate query returning employee count; mock `PlatformSettingsProvider` providing `maxEmployees` from catalog; verify limit enforcement (under limit, at limit, unlimited `-1`)
    - [x] Write unit tests for `deactivateEmployee()` — verify `stats.totalEmployees` decrement on store document is removed
    - [x] In `addEmployee()`: replace `storeData['stats']['totalEmployees']` with Firestore `.count()` aggregate query on the employees collection for the store
    - [x] In `addEmployee()`: replace `storeData['subscription']['maxEmployees']` with lookup from centralized `PlatformSettingsProvider` catalog (via DI `sl<PlatformSettingsProvider>()`)
    - [x] In `deactivateEmployee()`: remove `stats.totalEmployees` decrement on the store document
    - [x] Verify all tests pass

- [~] Task: Conductor — User Manual Verification 'Phase 2: Store Cleanup & Repository Fix' (Protocol in workflow.md)
