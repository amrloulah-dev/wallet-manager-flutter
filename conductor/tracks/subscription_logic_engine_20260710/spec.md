# Specification: Subscription Logic Engine & Dynamic UI

## Overview

This track is the direct continuation of `subscription_model_cleanup_20260708` (Phases 1 & 2) and implements **Phase 3 (Centralized Logic Engine & Rule Enforcement)** and **Phase 4 (Dynamic UI & SMS Isolate)** from the Subscription System Restructuring Document.

Phase 1 & 2 established the `SubscriptionPlanModel`, cleaned `StoreModel`/`StoreSubscription`, and fixed the `EmployeeRepository` architectural trap. This track now builds on that foundation to:

1. **Phase 3 (Centralized Logic Engine):** Extract a `currentPlanLimits` getter in `SubscriptionProvider` as the **Single Source of Truth** for all subscription limits, replace all duplicated plan-resolution logic (currently repeated 3× across `maxWallets`, `maxEmployees`, `isSmsEnabled`), implement a hybrid fallback strategy with catalog lookup + hardcoded safety net, enforce limits via unified `canAddWallet`/`canAddEmployee` methods, and add **retroactive enforcement** (auto-freeze wallets / auto-suspend employees that exceed plan limits on downgrade).

2. **Phase 4 (Dynamic UI & SMS Isolate):** Make `PaywallScreen` fully dynamic by reading plan data from the subscription catalog instead of hardcoded `.arb` strings, remove dead code (`_deduceAmount` in `SubscriptionProvider` and `SubscriptionRepository`), and refactor `_syncToStorage()` to read the SMS flag from `currentPlanLimits.smsEnabled` instead of the removed store subscription fields.

## Functional Requirements

### FR-1: Create `currentPlanLimits` Getter (Phase 3)
- Add a new getter `SubscriptionPlanModel get currentPlanLimits` to `SubscriptionProvider`.
- Resolution logic:
  1. Read the store's `planId` from `_subscription`.
  2. Resolve the plan key (handling both camelCase `proYearly` and snake_case `pro_yearly` keys) — consolidating the currently-duplicated dual-key lookup.
  3. Look up the plan in `PlatformSettingsProvider.settings.plans[key]`.
- **Hybrid Fallback Strategy:**
  - If the subscription is expired (`isExpired && !hasPendingRequest`) OR the plan cannot be found in the catalog:
    - First attempt: look up `settings.plans['free']`.
    - If `'free'` key is also missing (catalog empty/corrupted): return a hardcoded `SubscriptionPlanModel.fallback()` constant with absolute minimum safe defaults: `maxWallets: 1`, `maxEmployees: 1`, `smsEnabled: false`, `price: 0`, `name: 'Free'`, `isActive: true`.
  - This guarantees **zero crashes** regardless of catalog state.

### FR-2: Refactor Existing Limit Getters (Phase 3)
- Refactor `maxWallets`, `maxEmployees`, and `isSmsEnabled` getters to delegate entirely to `currentPlanLimits`.
- Remove all duplicated plan-resolution logic, dual-key lookups, and hardcoded fallback switch statements from these individual getters.
- After refactoring: `maxWallets` → `currentPlanLimits.maxWallets`, `maxEmployees` → `currentPlanLimits.maxEmployees`, `isSmsEnabled` → `currentPlanLimits.smsEnabled`.

### FR-3: Unify `canAddWallet` and `canAddEmployee` (Phase 3)
- Modify `canAddWallet(int currentWalletCount)` to use `currentPlanLimits.maxWallets` exclusively — remove the hardcoded `< 3` expired fallback.
- Modify `canAddEmployee(int currentEmployeeCount)` to use `currentPlanLimits.maxEmployees` exclusively — remove the hardcoded `< 1` expired fallback.
- Both methods must handle `maxWallets == -1` / `maxEmployees == -1` as "unlimited" (existing behavior preserved).
- Fix the off-by-one inconsistency: expired fallback currently allows 2 wallets via `< 3` while `maxWallets` returns `2` for free — after unification, behavior is consistent.

### FR-4: Retroactive Enforcement — Wallet Freezing (Phase 3)
- Add a method `enforceWalletLimits()` (or similar) to `SubscriptionProvider` or trigger it from the subscription state change listener.
- When the active plan changes (downgrade, expiry, or plan switch):
  - Compare `currentPlanLimits.maxWallets` against the current wallet count.
  - If wallets exceed the limit, automatically freeze excess wallets (set `WalletStatus.suspended` or equivalent) starting from the most recently created.
  - Follow **Optimistic UI** pattern: mutate RAM first, `safeNotify()`, then write to Firestore in background.
  - On Firestore failure: revert frozen wallets to active, `safeNotify()`, show error.

### FR-5: Retroactive Enforcement — Employee Suspension (Phase 3)
- Add a method `enforceEmployeeLimits()` (or similar) to `SubscriptionProvider` or trigger from subscription state change.
- When the active plan changes:
  - Compare `currentPlanLimits.maxEmployees` against the current active employee count.
  - If employees exceed the limit, automatically suspend excess employees (prevent login/access) starting from the most recently added.
  - Follow **Optimistic UI** pattern as described in FR-4.

### FR-6: `AddEmployeeScreen` Cleanup (Phase 3)
- Verify that `AddEmployeeScreen` relies exclusively on `SubscriptionProvider.maxEmployees` (which now delegates to `currentPlanLimits`) — no independent limit calculation.
- Current investigation shows this screen already delegates to the provider. Confirm no regressions after the refactor.

### FR-7: `_syncToStorage()` Refactor (Phase 4)
- Modify `_syncToStorage()` in `SubscriptionProvider` to read the SMS flag from `currentPlanLimits.smsEnabled` instead of the now-removed store subscription field.
- The `isSmsEnabled` getter already delegates to `currentPlanLimits` (after FR-2), so `_syncToStorage()` should use it consistently.
- Continue saving to `SharedPreferences` using the existing HMAC encryption mechanism.
- The SMS background isolate implementation must NOT be modified.

### FR-8: Remove Dead Code — `_deduceAmount` (Phase 4)
- Delete `_deduceAmount(SubscriptionPlan planId)` from `SubscriptionProvider` (L134-138, currently dead code).
- Delete `_deduceAmount` from `SubscriptionRepository` if it also exists there as dead code.
- Verify no callers reference these methods before deletion.

### FR-9: Dynamic `PaywallScreen` (Phase 4)
- Refactor `PaywallScreen` to generate subscription cards dynamically by iterating over the subscription catalog from `PlatformSettingsProvider.settings.plans`.
- **Filtering:** Skip any plan where `isActive == false`.
- **Sorting:** Use a predefined explicit order array: `['free', 'trial', 'proYearly', 'lifetime']`. Filter first, then sort. Plans not in the order array should be appended at the end.
- **Pricing Display:** Use String Interpolation to display `plan.price` directly from the database. Replace hardcoded `.arb` price strings (`proYearlyPrice`, `lifetimePrice`) with dynamic values.
- **Feature Lists:** Plan `description` from the catalog should be used where possible. If feature lists need to remain localized, they may stay in `.arb` files but must be keyed by plan ID for extensibility.
- **Lifetime Plan Availability:** Continue using `SystemConfigProvider` for `lifetimePlanEnabled` and `remainingLifetimeSeats` logic — this is a business rule, not a catalog concern.

### FR-10: Create `SubscriptionPlanModel.fallback()` Factory (Phase 3)
- Add a `factory SubscriptionPlanModel.fallback()` named constructor that returns a constant instance with minimum safe defaults:
  - `name: 'Free'`, `description: 'Basic plan'`, `isActive: true`, `price: 0`, `maxWallets: 1`, `maxEmployees: 1`, `smsEnabled: false`.
- This is the last-resort fallback when even the `'free'` key is missing from the catalog.

## Non-Functional Requirements

### NFR-1: Single Source of Truth
- After this track, absolutely **no** subscription limit value may be read from any source other than `SubscriptionProvider.currentPlanLimits` (which reads from `PlatformSettingsProvider.settings.plans`). Zero hardcoded limit values in the codebase.

### NFR-2: Optimistic UI Compliance
- All retroactive enforcement operations (wallet freezing, employee suspension) must follow the project's Optimistic UI pattern: RAM mutation → `safeNotify()` → Firestore write → rollback on failure.

### NFR-3: Backward Compatibility
- `PaywallScreen` must gracefully handle an empty plans catalog (show a fallback message or loading state, not a crash).
- The dual-key lookup (`proYearly` / `pro_yearly`) must be preserved in `currentPlanLimits` for Firestore compatibility.

### NFR-4: Localization
- Dynamic pricing text must support both Arabic and English via String Interpolation with `AppLocalizations` for currency labels/formatting.
- Feature lists can remain localized in `.arb` files, keyed by plan ID.

### NFR-5: Test Coverage
- All new and modified code must have unit tests with >80% coverage.
- Tests must cover: `currentPlanLimits` resolution (all paths including hybrid fallback), `canAddWallet`/`canAddEmployee` unified behavior, retroactive enforcement logic (freeze/suspend), `_syncToStorage()` refactored behavior, `PaywallScreen` dynamic rendering with various catalog states, dead code removal verification.

### NFR-6: Background Isolate Safety
- The SMS background isolate must NOT be modified. Only the data written to `SharedPreferences` (via `_syncToStorage()`) changes.

## Acceptance Criteria

1. `currentPlanLimits` getter exists in `SubscriptionProvider` and correctly resolves the active plan from the catalog with dual-key lookup.
2. When the plan is not found or subscription is expired, `currentPlanLimits` returns `plans['free']`, falling back to `SubscriptionPlanModel.fallback()` if `'free'` is also missing.
3. `maxWallets`, `maxEmployees`, `isSmsEnabled` delegate entirely to `currentPlanLimits` — no duplicated resolution logic.
4. `canAddWallet` and `canAddEmployee` use `currentPlanLimits` exclusively — no hardcoded numeric fallbacks.
5. The off-by-one inconsistency in `canAddWallet` (expired path) is fixed.
6. Wallet freezing logic automatically suspends excess wallets when plan limits decrease (downgrade/expiry).
7. Employee suspension logic automatically restricts excess employees when plan limits decrease.
8. Both enforcement operations follow Optimistic UI with proper rollback on Firestore failure.
9. `_syncToStorage()` reads `smsEnabled` from `currentPlanLimits` — not from removed store subscription fields.
10. `_deduceAmount` is removed from both `SubscriptionProvider` and `SubscriptionRepository`.
11. `PaywallScreen` dynamically renders plan cards from the catalog, filtered by `isActive`, sorted by explicit order array `['free', 'trial', 'proYearly', 'lifetime']`.
12. Plan prices on `PaywallScreen` come from `plan.price` — no hardcoded `.arb` price strings remain.
13. `AddEmployeeScreen` continues to work correctly with the refactored provider.
14. `flutter analyze` reports no new errors or warnings.
15. All tests pass with >80% coverage on new/modified code.

## Out of Scope

- Phase 1 (Model Unification & Cache Safety) — covered by `subscription_model_cleanup_20260708`.
- Phase 2 (Store Cleanup & Repository Fix) — covered by `subscription_model_cleanup_20260708`.
- Firestore security rules changes.
- Admin panel changes.
- Migration scripts for existing Firestore documents.
- SMS background isolate implementation changes (only the data written to SharedPreferences changes).
- `SystemConfigProvider` refactoring (lifetime seat counting remains as-is).
