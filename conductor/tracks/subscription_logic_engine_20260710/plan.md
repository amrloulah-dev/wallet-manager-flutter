# Implementation Plan: Subscription Logic Engine & Dynamic UI

## Phase 3: Centralized Logic Engine & Rule Enforcement

### 3.1 Create `SubscriptionPlanModel.fallback()` Factory (FR-10)
- [x] Task: Write Tests — `SubscriptionPlanModel.fallback()` [56976e8]
    - [x] Test that `SubscriptionPlanModel.fallback()` returns an instance with expected defaults: `name: 'Free'`, `price: 0`, `maxWallets: 1`, `maxEmployees: 1`, `smsEnabled: false`, `isActive: true`.
    - [x] Test immutability and equality of the fallback instance.
- [x] Task: Implement `SubscriptionPlanModel.fallback()` [56976e8]
    - [x] Add `factory SubscriptionPlanModel.fallback()` named constructor to `lib/data/models/subscription_plan_model.dart`.
    - [x] Return a constant instance with minimum safe defaults.

### 3.2 Implement `currentPlanLimits` Getter (FR-1)
- [x] Task: Write Tests — `currentPlanLimits` getter [8c5b312]
    - [x] Test resolution of active plan from catalog via `planId` (camelCase key).
    - [x] Test resolution via snake_case fallback key (`pro_yearly`).
    - [x] Test expired subscription (no pending request) returns `plans['free']`.
    - [x] Test expired subscription with pending request returns the actual plan.
    - [x] Test plan not found in catalog returns `plans['free']`.
    - [x] Test both plan and `'free'` missing returns `SubscriptionPlanModel.fallback()`.
    - [x] Test null subscription returns `SubscriptionPlanModel.fallback()`.
- [x] Task: Implement `currentPlanLimits` getter [8c5b312]
    - [x] Add `SubscriptionPlanModel get currentPlanLimits` to `SubscriptionProvider`.
    - [x] Consolidate dual-key lookup logic (camelCase + snake_case).
    - [x] Implement hybrid fallback: catalog `'free'` → `SubscriptionPlanModel.fallback()`.

### 3.3 Refactor Existing Limit Getters (FR-2)
- [x] Task: Write Tests — Refactored `maxWallets`, `maxEmployees`, `isSmsEnabled` [92e9815]
    - [x] Test `maxWallets` delegates to `currentPlanLimits.maxWallets`.
    - [x] Test `maxEmployees` delegates to `currentPlanLimits.maxEmployees`.
    - [x] Test `isSmsEnabled` delegates to `currentPlanLimits.smsEnabled`.
    - [x] Test all hardcoded fallback switches are removed (no residual hardcoded values).
- [x] Task: Implement refactored limit getters [92e9815]
    - [x] Refactor `maxWallets` to return `currentPlanLimits.maxWallets`.
    - [x] Refactor `maxEmployees` to return `currentPlanLimits.maxEmployees`.
    - [x] Refactor `isSmsEnabled` to return `currentPlanLimits.smsEnabled`.
    - [x] Remove all duplicated plan-resolution logic and hardcoded switch statements.

### 3.4 Unify `canAddWallet` & `canAddEmployee` (FR-3)
- [x] Task: Write Tests — Unified `canAddWallet` and `canAddEmployee` [8fde82b]
    - [x] Test `canAddWallet` uses `currentPlanLimits.maxWallets` for all states (active, expired, null).
    - [x] Test `canAddEmployee` uses `currentPlanLimits.maxEmployees` for all states.
    - [x] Test unlimited behavior (`maxWallets == -1` returns true).
    - [x] Test off-by-one fix: expired with free plan (`maxWallets: 1`) blocks at 1 wallet (not 2).
    - [x] Test with pending request: uses actual plan limits, not free fallback.
- [x] Task: Implement unified `canAddWallet` and `canAddEmployee` [8fde82b]
    - [x] Remove hardcoded `< 3` expired fallback from `canAddWallet`.
    - [x] Remove hardcoded `< 1` expired fallback from `canAddEmployee`.
    - [x] Both methods delegate to `currentPlanLimits` for limit resolution.
    - [x] Preserve `-1` as "unlimited" behavior.

### 3.5 Retroactive Enforcement — Wallet Freezing (FR-4)
- [ ] Task: Write Tests — Wallet freezing on limit change
    - [ ] Test: when wallet count exceeds new limit, excess wallets are frozen (most recently created first).
    - [ ] Test: when wallet count is within limit, no wallets are frozen.
    - [ ] Test: unlimited plan (`maxWallets == -1`) never freezes wallets.
    - [ ] Test: Optimistic UI — RAM is mutated before Firestore write.
    - [ ] Test: rollback on Firestore failure (frozen wallets restored to active).
- [ ] Task: Implement wallet freezing enforcement
    - [ ] Add `enforceWalletLimits()` method to `SubscriptionProvider` (or `WalletProvider`).
    - [ ] Compare `currentPlanLimits.maxWallets` against current active wallet count.
    - [ ] Freeze excess wallets starting from most recently created.
    - [ ] Follow Optimistic UI: mutate RAM → `safeNotify()` → Firestore write → rollback on failure.
    - [ ] Trigger from subscription state change listener.

### 3.6 Retroactive Enforcement — Employee Suspension (FR-5)
- [ ] Task: Write Tests — Employee suspension on limit change
    - [ ] Test: when employee count exceeds new limit, excess employees are suspended (most recently added first).
    - [ ] Test: when employee count is within limit, no employees are suspended.
    - [ ] Test: unlimited plan (`maxEmployees == -1`) never suspends employees.
    - [ ] Test: Optimistic UI — RAM mutation before Firestore.
    - [ ] Test: rollback on Firestore failure.
- [ ] Task: Implement employee suspension enforcement
    - [ ] Add `enforceEmployeeLimits()` method to `SubscriptionProvider` (or `EmployeeProvider`).
    - [ ] Compare `currentPlanLimits.maxEmployees` against current active employee count.
    - [ ] Suspend excess employees starting from most recently added.
    - [ ] Follow Optimistic UI pattern with rollback.
    - [ ] Trigger from subscription state change listener.

### 3.7 Verify `AddEmployeeScreen` (FR-6)
- [ ] Task: Write Tests — `AddEmployeeScreen` integration verification
    - [ ] Test that `AddEmployeeScreen` reads limits from `SubscriptionProvider.maxEmployees` (no independent calculation).
    - [ ] Test limit badge display with refactored provider.
    - [ ] Test submit button disabling at limit.
- [ ] Task: Verify and fix `AddEmployeeScreen` if needed
    - [ ] Confirm screen delegates entirely to `SubscriptionProvider`.
    - [ ] Fix any regressions caused by the refactor.

- [ ] Task: Conductor - User Manual Verification 'Phase 3: Centralized Logic Engine & Rule Enforcement' (Protocol in workflow.md)

## Phase 4: Dynamic UI & Background Service Maintenance

### 4.1 Refactor `_syncToStorage()` (FR-7)
- [ ] Task: Write Tests — `_syncToStorage()` refactor
    - [ ] Test that `smsEnabled` value written to storage comes from `currentPlanLimits.smsEnabled`.
    - [ ] Test that HMAC encryption mechanism is preserved.
    - [ ] Test sync behavior with expired subscription (uses free plan SMS flag).
- [ ] Task: Implement `_syncToStorage()` refactor
    - [ ] Modify `_syncToStorage()` to read SMS flag via `isSmsEnabled` (which delegates to `currentPlanLimits.smsEnabled`).
    - [ ] Remove any reference to removed store subscription fields.
    - [ ] Verify HMAC encryption is maintained.

### 4.2 Remove Dead Code — `_deduceAmount` (FR-8)
- [ ] Task: Write Tests — Dead code removal verification
    - [ ] Test that no compilation errors result from removing `_deduceAmount`.
    - [ ] Test that `submitSubscriptionRequest` still works (takes `amount` as parameter).
- [ ] Task: Remove `_deduceAmount` dead code
    - [ ] Delete `_deduceAmount(SubscriptionPlan planId)` from `SubscriptionProvider`.
    - [ ] Delete `_deduceAmount` from `SubscriptionRepository` if present.
    - [ ] Verify no callers reference these methods (grep codebase).

### 4.3 Dynamic `PaywallScreen` (FR-9)
- [ ] Task: Write Tests — Dynamic `PaywallScreen`
    - [ ] Test plan cards are rendered from catalog data (not hardcoded).
    - [ ] Test plans with `isActive == false` are excluded.
    - [ ] Test plan ordering follows explicit array: `['free', 'trial', 'proYearly', 'lifetime']`.
    - [ ] Test prices display from `plan.price` via String Interpolation.
    - [ ] Test empty catalog shows fallback UI (no crash).
    - [ ] Test lifetime plan availability still respects `SystemConfigProvider`.
- [ ] Task: Implement dynamic `PaywallScreen`
    - [ ] Replace hardcoded plan cards with dynamic iteration over `PlatformSettingsProvider.settings.plans`.
    - [ ] Apply `isActive == true` filter before rendering.
    - [ ] Sort using predefined order array: `['free', 'trial', 'proYearly', 'lifetime']`.
    - [ ] Display `plan.price` via String Interpolation with localized currency formatting.
    - [ ] Remove hardcoded `.arb` price strings (`proYearlyPrice`, `lifetimePrice`) or repurpose them as templates with interpolation.
    - [ ] Preserve `SystemConfigProvider` integration for lifetime plan business rules.
    - [ ] Handle empty catalog gracefully with fallback UI.

### 4.4 Localization Updates (FR-9 / NFR-4)
- [ ] Task: Write Tests — Localization for dynamic pricing
    - [ ] Test currency formatting in Arabic locale.
    - [ ] Test currency formatting in English locale.
- [ ] Task: Update `.arb` files for dynamic pricing
    - [ ] Add/update localization keys for dynamic price templates (e.g., `planPrice` with `{price}` placeholder).
    - [ ] Remove or deprecate hardcoded price strings (`proYearlyPrice`, `lifetimePrice`).
    - [ ] Run `flutter gen-l10n` to regenerate localization files.

- [ ] Task: Conductor - User Manual Verification 'Phase 4: Dynamic UI & Background Service Maintenance' (Protocol in workflow.md)
