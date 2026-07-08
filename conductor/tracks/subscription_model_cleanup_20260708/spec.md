# Specification: Subscription Model Unification & Store Cleanup

## Overview

The mobile application's subscription system currently suffers from fragmented data models, legacy fields, and an architectural trap in `EmployeeRepository`. This track restructures the foundation by:

1. **Phase 1 (Model Unification & Cache Safety):** Creating a `SubscriptionPlanModel` to replicate the centralized subscription catalog from Firestore (`settings/global`), updating `PlatformSettingsModel` to remove legacy pricing fields (`proPrice`, `lifetimePrice`) and replace them with the subscription catalog (`Map<String, SubscriptionPlanModel> plans`) plus three new global subscription variables (`gracePeriodHours`, `trialDays`, `lifetimeCountLimit`), and implementing a self-healing cache mechanism in `PlatformSettingsProvider` so that stale/incompatible cached JSON is silently invalidated and re-fetched.

2. **Phase 2 (Store Cleanup & Repository Fix):** Removing the `StoreStats` class entirely, stripping feature-limit fields (`maxWallets`, `maxEmployees`, `smsEnabled`) from `StoreSubscription` (keeping only state fields: `planId`, `endDate`, `status`, `trialConsumed`, `pendingRequestDate`), and fixing the `EmployeeRepository` architectural trap by replacing raw map access (`storeData['stats']['totalEmployees']`) with a Firestore `.count()` aggregate query and reading `maxEmployees` from the centralized subscription catalog via `PlatformSettingsProvider`.

> **Scope Boundary:** This track covers Phase 1 and Phase 2 only. Phases 3 (Centralized Logic Engine) and 4 (Dynamic UI & SMS Isolate) are deferred to a subsequent track.

## Functional Requirements

### FR-1: Create `SubscriptionPlanModel`
- Create a new model class at `lib/data/models/subscription_plan_model.dart`.
- Fields (exact match to Firestore catalog): `name` (String), `description` (String), `isActive` (bool), `price` (**num**), `maxWallets` (int), `maxEmployees` (int), `smsEnabled` (bool).
- The `price` field uses `num` (not `int`) to strictly match the Admin Panel's Firestore data type and prevent parsing crashes when Firestore returns a double.
- Implement `fromMap(Map<String, dynamic>)` factory constructor and `toMap()` method.
- All fields are required with sensible defaults for defensive parsing.

### FR-2: Update `PlatformSettingsModel`
- **Remove** the following legacy fields: `proPrice`, `lifetimePrice`.
- **Remove** all references to these fields from `fromJson()`, `toJson()`, `defaults()`, and any compatibility getters.
- **Retain** `lifetimeCountLimit` (int) as a global subscription variable (do NOT remove it).
- **Add** the following new global subscription variables to match the Admin Panel architecture:
  - `gracePeriodHours` (int) — parsed from `subscriptions['gracePeriodHours']`, default: `48`.
  - `trialDays` (int) — parsed from `subscriptions['trialDays']`, default: `14`.
- **Add** a new field: `Map<String, SubscriptionPlanModel> plans`.
- Parse `plans` from the `subscriptions.plans` path in the Firestore document JSON.
- Serialize `plans` back in `toJson()` under the same path.
- Default to an empty map if `plans` is absent.

### FR-3: Self-Healing Cache Mechanism
- In `PlatformSettingsProvider.initialize()`, wrap the JSON deserialization of cached platform settings inside a `try-catch` block.
- On deserialization failure (e.g., `FormatException`, `TypeError`, missing required fields):
  - Call `_storage.clearPlatformSettings()` (or equivalent) to purge the stale cache.
  - Trigger `_fetchFromFirestore()` to download fresh settings.
  - Log the cache invalidation event via `AppErrorHandler` for diagnostics.
- The invalidation and re-fetch must be **silent** — no user-facing toast, snackbar, or loading indicator.
- Add a `clearPlatformSettings()` method to `LocalStorageService` if one does not already exist.

### FR-4: Clean `StoreModel` — Remove `StoreStats`
- **Delete** the `StoreStats` class entirely from `lib/data/models/store_model.dart`.
- **Remove** the `StoreStats stats` field from `StoreModel`.
- **Remove** all `StoreStats` references from `StoreModel.fromFirestore()`, `StoreModel.toFirestore()`, and any other location.
- Verify that no other files import or reference `StoreStats`. If they do, remove or refactor those references.

### FR-5: Clean `StoreSubscription` — Remove Feature-Limit Fields
- **Remove** the following fields from `StoreSubscription`: `maxWallets`, `maxEmployees`, `smsEnabled`.
- **Keep** only subscription state fields: `planId`, `status`, `endDate`, `trialConsumed`, `pendingRequestDate`.
- **Update** `fromMap()` and `toMap()` accordingly.
- **Update** `migratedLifetime()` factory to no longer set the removed fields.
- **Audit** all consumers of `StoreSubscription.maxWallets`, `.maxEmployees`, `.smsEnabled` across the codebase and update or stub them (detailed fixes for consumers like `SubscriptionProvider` are deferred to Phase 3).

### FR-6: Fix `EmployeeRepository` Architectural Trap
- In `addEmployee()`, replace the raw Firestore map access pattern:
  ```dart
  storeData['stats']['totalEmployees']
  ```
  with a Firestore `.count()` aggregate query on the employees collection (e.g., `employees` subcollection or filtered by `storeId`).
- Replace the `maxEmployees` read from `storeData['subscription']['maxEmployees']` with a lookup against the centralized subscription catalog via `PlatformSettingsProvider` (injected via DI or passed as a parameter).
- In `deactivateEmployee()`, remove the decrement of `stats.totalEmployees` on the store document (the count is now derived from `.count()`, not maintained as a counter).
- Ensure the `.count()` query is consistent with the project's Zero-Unbounded-Read guarantee.

## Non-Functional Requirements

### NFR-1: Backward Compatibility
- The `PlatformSettingsModel.fromJson()` must gracefully handle both old-format JSON (with `proPrice`/`lifetimePrice` and no `plans`) and new-format JSON (with `plans`, `gracePeriodHours`, `trialDays`, and no legacy fields) during the migration window. Old fields should be silently ignored if present.

### NFR-2: Cache Resilience
- The self-healing cache must never cause a crash regardless of the cached JSON content (including empty strings, malformed JSON, or schema mismatches).

### NFR-3: Zero Data Loss
- Removing `StoreStats` and trimming `StoreSubscription` fields must not cause any Firestore writes that delete data from the database. These are model-layer-only changes — Firestore documents retain all fields.

### NFR-4: Test Coverage
- All new and modified code must have unit tests with >80% coverage.
- Tests must cover: `SubscriptionPlanModel` serialization (including `num` price handling), `PlatformSettingsModel` migration (old→new JSON including new global variables), cache invalidation scenarios, `StoreSubscription` trimmed serialization, and `EmployeeRepository` `.count()` integration.

## Acceptance Criteria

1. `SubscriptionPlanModel` correctly deserializes all 7 fields (with `price` as `num`) from a Firestore map and re-serializes them.
2. `PlatformSettingsModel` no longer contains `proPrice` or `lifetimePrice`.
3. `PlatformSettingsModel` retains `lifetimeCountLimit` and adds `gracePeriodHours` (default 48) and `trialDays` (default 14).
4. `PlatformSettingsModel` parses `plans` from Firestore JSON and serializes them back.
5. Cached old-format JSON triggers silent cache invalidation and fresh Firestore fetch — no crash.
6. `StoreStats` class is fully removed; no references remain in the codebase.
7. `StoreSubscription` retains only state fields (`planId`, `status`, `endDate`, `trialConsumed`, `pendingRequestDate`).
8. `EmployeeRepository.addEmployee()` uses `.count()` for employee count and reads `maxEmployees` from the centralized catalog.
9. `EmployeeRepository.deactivateEmployee()` no longer decrements `stats.totalEmployees` on the store document.
10. All tests pass with >80% coverage on new/modified code.
11. `flutter analyze` reports no new errors or warnings.

## Out of Scope

- **Phase 3:** Centralized Logic Engine — `SubscriptionProvider.currentPlanLimits` getter, strict enforcement in `canAddWallet`/`canAddEmployee`, UI fixes in `AddEmployeeScreen`.
- **Phase 4:** Dynamic UI & SMS Isolate — `PaywallScreen` dynamic pricing, `_syncToStorage()` refactor, removal of `_deduceAmount()`.
- Firestore security rules changes.
- Admin panel changes.
- Migration scripts for existing Firestore documents.
