# Implementation Plan: SaaS Migration

## Technical Context
The goal is to replace the legacy local `activeLicenseKey` logic with a centralized `StoreSubscription` object embedded in `StoreModel`, governed by the `SubscriptionProvider` gatekeeper. The strategy relies heavily on the constraints imposed by the **Project Constitution**: zero-waste reads, surgical reactivity (no global re-renders), and strictly optimistic updates. 

This phase focuses exclusively on the transition of the subscription tier modeling, payment requests, trial logic, and suspension checks. Admin operations are external to this client-side scope.

## Constitution Check
1. **Zero-Waste Reads**: The `subscription` map is embedded in `StoreModel`. No additional document fetch is required for gating (O(1) dictionary lookup via provider). `SystemConfigs` will be read once on startup or explicitly cached.
2. **Surgical Reactivity**: We will use scoped `Selector` widgets for limiting UI elements (e.g. `WalletLimitBar`) rather than root-level `Consumer` rebuilds. Paywalls and block screens should be injected surgically in the top-level routing or wrap `MaterialApp` securely.
3. **Optimistic Updates**: Changes to the active store state (like tracking free limits) happen in-memory instantly in the Provider before syncing to Firestore.

## Execution Phases

### Phase 1: Data Layer (Models & Repositories)
1. **Remove Legacy Structures**:
   - Delete `StoreLicense` from `store_model.dart`.
   - Remove `licenseKeyId` and `activeLicenseKey` from `StoreModel`.
   - Remove `maxEmployees` from `StoreSettings`.
2. **Implement New Models**:
   - `StoreSubscription` class inside `store_model.dart`.
   - `SubscriptionRequestModel` for tracking Vodafone Cash / InstaPay manual submissions.
   - `DeviceRegistryModel` and `SystemConfigsModel`.
3. **Data Migration Handlers (FR-17)**:
   - Within `StoreModel.fromFirestore`, detect legacy stores (with no `subscription` property) and populate them automatically as `Lifetime` (grandfathered status).
4. **Repository Updates**:
   - `StoreRepository` update writes.
   - Implement `SubscriptionRepository` for reading system configs, tracking device registry, and submitting `SubscriptionRequest`.

### Phase 2: Domain Layer (Gatekeepers & Services)
1. **Device Registry & Time Sync**:
   - Create `DeviceTrackingService` using `device_info_plus`.
   - Implement cached NTP offset to prevent client-clock manipulation for trial tracking.
2. **`SubscriptionProvider` Central Gatekeeper**:
   - Listen to `StoreModel` streams (or cache updates) to maintain the current `StoreSubscription`.
   - Implement limit checkers: `canAddWallet()`, `canAddEmployee()`, `isSmsEnabled()`.
   - Expose properties for UI consumption (`isSuspended`, `showPaywall`).
3. **Limit Enforcements**:
   - Update `WalletProvider` and `EmployeeProvider` to consult `SubscriptionProvider` prior to mutations.
   - Apply FIFO downgrade freeze logic. If `storeWallets.length > maxWallets`, prevent operations on excess items without deletion of older ones.
4. **Overlay SMS Processing**:
   - Update `OverlayProvider` and SMS pipeline to stop processing incoming SMS if `(!smsEnabled)` or if suspended.

### Phase 3: Presentation Layer (MCP Driven UI)
1. **Fetch & Implement Stitch MCP UI**:
   - Query Stitch MCP server (Project `3771784857992882396`) to generate Arabic RTL Screens.
   - Screen 1: **Upgrade / Paywall Screen**, providing tier comparisons (Free, Trial, Pro, Lifetime) and locking out users exceeding limits.
   - Screen 2: **Payment Capture Modal** (Vodafone Cash / InstaPay details).
   - Screen 3: **Admin Block Screen** (Full screen suspension lock).
2. **Integrate Logic via Selectors**:
   - Wire the UI to read limits and current usage.
   - Inject the Paywall / Suspended routing override at the root of the MainDashboard navigation tree.
3. **Testing**:
   - Validate trial downgrade behavior.
   - Test legacy grandfathering behavior on app launch.
   - Verify SMS halting when suspended or on Free tier.
