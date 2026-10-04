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
- [x] Task: Write Tests — Wallet freezing on limit change [b102e96]
    - [x] Test: when wallet count exceeds new limit, excess wallets are frozen (most recently created first).
    - [x] Test: when wallet count is within limit, no wallets are frozen.
    - [x] Test: unlimited plan (`maxWallets == -1`) never freezes wallets.
    - [x] Test: Optimistic UI — RAM is mutated before Firestore write.
    - [x] Test: rollback on Firestore failure (frozen wallets restored to active).
- [x] Task: Implement wallet freezing enforcement [b102e96]
    - [x] Add `enforceWalletLimits()` method to `SubscriptionProvider` (or `WalletProvider`).
    - [x] Compare `currentPlanLimits.maxWallets` against current active wallet count.
    - [x] Freeze excess wallets starting from most recently created.
    - [x] Follow Optimistic UI: mutate RAM → `safeNotify()` → Firestore write → rollback on failure.
    - [x] Trigger from subscription state change listener.

### 3.6 Retroactive Enforcement — Employee Suspension (FR-5)
- [x] Task: Write Tests — Employee suspension on limit change [68e0d72]
    - [x] Test: when employee count exceeds new limit, excess employees are suspended (most recently added first).
    - [x] Test: when employee count is within limit, no employees are suspended.
    - [x] Test: unlimited plan (`maxEmployees == -1`) never suspends employees.
    - [x] Test: Optimistic UI — RAM mutation before Firestore.
    - [x] Test: rollback on Firestore failure.
- [x] Task: Implement employee suspension enforcement [68e0d72]
    - [x] Add `enforceEmployeeLimits()` method to `SubscriptionProvider` (or `EmployeeProvider`).
    - [x] Compare `currentPlanLimits.maxEmployees` against current active employee count.
    - [x] Suspend excess employees starting from most recently added.
    - [x] Follow Optimistic UI pattern with rollback.
    - [x] Trigger from subscription state change listener.

### 3.7 Verify `AddEmployeeScreen` (FR-6)
- [x] Task: Write Tests — `AddEmployeeScreen` integration verification [0da48a8]
    - [x] Test: verify that it queries limits from `SubscriptionProvider`.
    - [x] Test: displays paywall or warning if `maxEmployees` is exceeded.
- [x] Task: Ensure integration is complete and correct [0da48a8]
    - [x] Locate `AddEmployeeScreen`.
    - [x] Verify that it displays the correct warnings/limits dynamically.
    - [x] Ensure that clicking 'Add Employee' is blocked/disabled when over limit.
    - [x] Confirm screen delegates entirely to `SubscriptionProvider`.
    - [x] Fix any regressions caused by the refactor.

- [x] Task: Conductor - User Manual Verification 'Phase 3: Centralized Logic Engine & Rule Enforcement' (Protocol in workflow.md)

## Phase 4: Dynamic UI & Background Service Maintenance

### 4.1 Refactor `_syncToStorage()` (FR-7)
- [x] Task: Write Tests — `_syncToStorage()` refactor
    - [x] Test that `smsEnabled` value written to storage comes from `currentPlanLimits.smsEnabled`.
    - [x] Test that HMAC encryption mechanism is preserved.
    - [x] Test sync behavior with expired subscription (uses free plan SMS flag).
- [x] Task: Implement `_syncToStorage()` refactor
    - [x] Modify `_syncToStorage()` to read SMS flag via `isSmsEnabled` (which delegates to `currentPlanLimits.smsEnabled`).
    - [x] Remove any reference to removed store subscription fields.
    - [x] Verify HMAC encryption is maintained.

### 4.2 Remove Dead Code — `_deduceAmount` (FR-8)
- [x] Task: Write Tests — Dead code removal verification
    - [x] Test that no compilation errors result from removing `_deduceAmount`.
    - [x] Test that `submitSubscriptionRequest` still works (takes `amount` as parameter).
- [x] Task: Remove `_deduceAmount` dead code
    - [x] Delete `_deduceAmount(SubscriptionPlan planId)` from `SubscriptionProvider`.
    - [x] Delete `_deduceAmount` from `SubscriptionRepository` if present.
    - [x] Verify no callers reference these methods (grep codebase).

### 4.3 Dynamic `PaywallScreen` (FR-9)
- [x] Task: Write Tests — Dynamic `PaywallScreen`
    - [x] Test plan cards are rendered from catalog data (not hardcoded).
    - [x] Test plans with `isActive == false` are excluded.
    - [x] Test plan ordering follows explicit array: `['free', 'trial', 'proYearly', 'lifetime']`.
    - [x] Test prices display from `plan.price` via String Interpolation.
    - [x] Test empty catalog shows fallback UI (no crash).
    - [x] Test lifetime plan availability still respects `SystemConfigProvider`.
- [x] Task: Implement dynamic `PaywallScreen`
    - [x] Replace hardcoded plan cards with dynamic iteration over `PlatformSettingsProvider.settings.plans`.
    - [x] Apply `isActive == true` filter before rendering.
    - [x] Sort using predefined order array: `['free', 'trial', 'proYearly', 'lifetime']`.
    - [x] Display `plan.price` via String Interpolation with localized currency formatting.
    - [x] Remove hardcoded `.arb` price strings (`proYearlyPrice`, `lifetimePrice`) or repurpose them as templates with interpolation.
    - [x] Preserve `SystemConfigProvider` integration for lifetime plan business rules.
    - [x] Handle empty catalog gracefully with fallback UI.

### 4.4 Localization Updates (FR-9 / NFR-4)
- [x] Task: Write Tests — Localization for dynamic pricing
    - [x] Test currency formatting in Arabic locale.
    - [x] Test currency formatting in English locale.
- [x] Task: Update `.arb` files for dynamic pricing
    - [x] Add/update localization keys for dynamic price templates (e.g., `planPrice` with `{price}` placeholder).
    - [x] Remove or deprecate hardcoded price strings (`proYearlyPrice`, `lifetimePrice`).
    - [x] Run `flutter gen-l10n` to regenerate localization files.

- [ ] Task: Conductor - User Manual Verification 'Phase 4: Dynamic UI & Background Service Maintenance' (Protocol in workflow.md)
