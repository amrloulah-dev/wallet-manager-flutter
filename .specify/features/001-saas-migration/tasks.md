# Implementation Tasks: SaaS Migration

## Implementation Strategy
- **MVP First:** Our initial execution will focus solely on the data layer migrations to ensure backward compatibility and prevent app crashes (Phase 1).
- **Incremental Delivery:** We follow the "Bottom-Up" strategy. Data layer models > Domain layer provider gating > Presentation layer Stitch MCP UI integration.

## Dependencies & Execution Order
1. Phase 1 & 2 (Foundational Data changes) must complete first.
2. Phases 3-15 (User Stories) can mostly be parallelized at the Provider level, but depend on Phase 1/2.
3. Phase 16 (Polish / UI) completes the migration.

---

## Phase 1: Setup
Goal: Prepare the project structure for new configurations.
- [x] T001 Add `device_info_plus` and `ntp` to `pubspec.yaml`
- [x] T002 Execute `flutter pub get` related to new dependencies

## Phase 2: Foundational Data Layer
Goal: Replace legacy license structure with the new subscription-embedded architecture.
**Prerequisite to all User Stories.**

- [x] T003 Remove legacy fields (`StoreLicense`, `licenseKeyId`, `activeLicenseKey`) and `StoreSettings.maxEmployees` from `lib/data/models/store_model.dart`
- [x] T004 Implement `StoreSubscription` object within `lib/data/models/store_model.dart`
- [x] T005 Implement `SubscriptionRequestModel` mapped to `lib/data/models/subscription_request_model.dart`
- [x] T006 Implement `DeviceRegistryModel` mapped to `lib/data/models/device_registry_model.dart`
- [x] T007 Implement `SystemConfigsModel` mapped to `lib/data/models/system_configs_model.dart`
- [x] T008 Update `StoreModel.toFirestore` and parsing logic in `lib/data/models/store_model.dart`
- [x] T009 Update `StoreRepository` to support new structures in `lib/data/repositories/store_repository.dart`

---

## Phase 3: [US10] Device Registry Anti-Fraud & [US1] 14-Day Trial
**Goal:** Track devices to prevent trial abuse and accurately compute the 14-day trial window.
**Independent Test Criteria:** Removing the app and reinstalling retains the trial state based on UUID.

- [x] T010 [US10] Implement `DeviceTrackingService` using `device_info_plus` in `lib/services/device_tracking_service.dart`
- [x] T011 [US1] Implement NTP-based time offset checker in `lib/services/time_service.dart`
- [x] T012 [P] [US10] Implement `SubscriptionRepository.verifyDevice()` in `lib/data/repositories/subscription_repository.dart`
- [x] T013 [US1] Calculate `StoreSubscription.isExpired` based on `time_service` offsets in `lib/data/models/store_model.dart`

---

## Phase 4: [US12] Legacy Store Migration Default (FR-17)
**Goal:** Grandfather existing users seamlessly into Lifetime.
**Independent Test Criteria:** Loading a legacy store JSON automatically converts to Lifetime.

- [x] T014 [US12] Add fallback logic to `StoreModel.fromFirestore` to inject Lifetime subscription if `subscription` field is null in `lib/data/models/store_model.dart`

---

## Phase 5: [US2] Feature Limits & [US3] Limit Enforcement & [US6] FIFO Retentions
**Goal:** Define and enforce feature limits based on specific plans.
**Independent Test Criteria:** Pro users can add up to 999 wallets; Free users are blocked at 3. Downgraded users freeze excess wallets.

- [x] T015 [US2] Create or update `SubscriptionProvider` to expose current limits in `lib/providers/subscription_provider.dart`
- [x] T016 [US2] Implement limit checkers: `canAddWallet()`, `canAddEmployee()` in `lib/providers/subscription_provider.dart`
- [x] T017 [US3] Enforce limits natively inside `WalletProvider.createWallet` and `WalletProvider.updateWallet` in `lib/providers/wallet_provider.dart`
- [x] T018 [US3] Enforce limits natively inside `EmployeeProvider.addEmployee` in `lib/providers/employee_provider.dart`
- [x] T019 [US6] Add "FIFO downgrade freeze" validation inside providers to selectively lock older wallets/employees.

---

## Phase 6: [US8] SMS Gating & [US9] Process Blocking
**Goal:** SMS routing should abort locally if the user is not on an SMS-enabled tier.
**Independent Test Criteria:** Incoming SMS on a Free tier bypasses the pipeline completely.

- [x] T020 [US8] Implement `isSmsEnabled` in `SubscriptionProvider` within `lib/providers/subscription_provider.dart`
- [x] T021 [US8] Sync `sub_end_date_ms` and `is_sub_lifetime` to `SharedPreferences` on provider update for background isolated SMS access in `lib/providers/subscription_provider.dart`
- [x] T022 [US9] Check `SharedPreferences` limits inside background SMS handler and abort entirely if SMS is disabled or suspended in `lib/presentation/overlays/overlay_provider.dart`

---

## Phase 7: [US13] Admin Suspension Block
**Goal:** Full application blackout for manually suspended stores.
**Independent Test Criteria:** Setting status to "suspended" triggers immediate block screen.

- [x] T023 [US13] Centralize `isSuspended` exposure via `SubscriptionProvider` in `lib/providers/subscription_provider.dart`
- [x] T024 [P] [US13] Wire SMS pipeline to abort when suspended (also tracked via SharedPreferences) in `lib/presentation/overlays/overlay_provider.dart`

---

## Phase 8: [US4] Trial Expiry 48-Hour Grace Period & [US5] Payment Submission
**Goal:** Handle the local payment flow submission.
**Independent Test Criteria:** Manual payment submissions extend the usable expiration clock locally by 48 hours for review.

- [x] T025 [P] [US5] Implement `submitSubscriptionRequest` in `SubscriptionRepository` within `lib/data/repositories/subscription_repository.dart`. THIS MUST INCLUDE `try-catch` + revert + error toast logic to adhere to Constitution Principle 4 (Safe Rollbacks on Failure) for the optimistic update of `pendingRequestDate`.
- [x] T026 [US4] Allow 48-hour active usage extension in `StoreSubscription.isExpired` logically if a `SubscriptionRequest` is active and pending.

---

## Phase 9: UI Generation via Stitch MCP & [US11] Real-time Lockout
**Goal:** Produce exact RTL structures for presentation.
**Independent Test Criteria:** Seamless navigation interruption via MCP-designed paywalls.

- [x] T027 [P] [US5] Fetch and integrate Payment Submission Modal UI via Stitch MCP into `lib/presentation/screens/subscription/payment_modal_screen.dart` (Must use Google Stitch Project ID 3771784857992882396 and ensure strict Arabic RTL directionality)
- [x] T028 [P] [US11] Fetch and integrate Hard Paywall Screen UI via Stitch MCP into `lib/presentation/screens/subscription/paywall_screen.dart` (Must use Google Stitch Project ID 3771784857992882396 and ensure strict Arabic RTL directionality)
- [x] T029 [P] [US13] Fetch and integrate Admin Block Screen component via Stitch MCP into `lib/presentation/screens/subscription/admin_block_screen.dart` (Must use Google Stitch Project ID 3771784857992882396 and ensure strict Arabic RTL directionality)
- [x] T030 [P] [US5] Fetch and integrate "My Subscription Details" screen via Stitch MCP into `lib/presentation/screens/subscription/subscription_details_screen.dart` (Must use Google Stitch Project ID 3771784857992882396 and ensure strict Arabic RTL directionality)
- [x] T031 [P] [US5] Fetch and integrate "Dashboard Banners" (Pending/Error) via Stitch MCP into `lib/presentation/screens/dashboard/widgets/subscription_banner.dart` (Must use Google Stitch Project ID 3771784857992882396 and ensure strict Arabic RTL directionality)
- [x] T032 [P] [US5] Fetch and integrate "Payment Success Modal" via Stitch MCP into `lib/presentation/screens/subscription/payment_success_modal.dart` (Must use Google Stitch Project ID 3771784857992882396 and ensure strict Arabic RTL directionality)
- [x] T033 [US11] Wire root-level router interruption (using Selectors) to display paywall/block screens proactively in `lib/presentation/screens/dashboard/main_dashboard_screen.dart`

---

## Phase 10: Polish & Cross-Cutting
- [x] T034 Ensure all new Providers are registered correctly in `lib/main.dart` or `MultiProvider` configuration.
- [x] T035 Perform manual testing of the `MainDashboardScreen` block states with simulated Firestore updates.

---

## Phase 11: Audit Remediation
**Goal:** Address architecture gaps discovered during spec analysis.

- [x] T036 [C1] Implement domain logic in `SubscriptionProvider` or a dedicated listener to fetch the latest `SubscriptionRequest` for the active store and resolve UI banner visibility for Approved/Rejected outcomes.
- [x] T037 [C2] Update `WalletCard` UI in `lib/presentation/widgets/wallet/wallet_card.dart` to visually indicate a 'Frozen' or read-only state when downgraded beyond the plan limit.
- [x] T038 [C2] Update `EmployeeCard` UI in `lib/presentation/widgets/employee/employee_card.dart` (or similar) to visually indicate a 'Suspended' state when downgraded beyond the plan limit.
- [x] T039 [A1] Implement a mechanism to load and expose `SystemConfigs` (via `SubscriptionProvider` or `SystemConfigsProvider`) to dynamically feed the Lifetime card scarcity data to the paywall.

---

## Phase 12: Performance & State Remediation
**Goal:** Address Constitution constraints, specifically O(1) reads, and properly manage UI modal display states.

- [x] T040 [C1] Update `WalletProvider` & `EmployeeProvider` to rigidly pre-calculate and cache a `Set<String>` of `frozenWalletIds` and `suspendedEmployeeIds` during Provider state mutations, eliminating any O(n) sorting or filtering inside widget `build()` methods to remain strictly compliant with Constitution Principle 5.
- [x] T041 [U1] Implement persistent tracking of `hasSeenSuccessModal` using `SharedPreferences` inside the `SubscriptionProvider`. Use this to ensure the Success Modal (US-04) displays exactly once upon tier upgrade.
- [x] T042 [U2] Add a local dismissal action in `SubscriptionProvider` for the Rejection Banner (US-05). Once dismissed by the user, flag the request as locally acknowledged via `SharedPreferences` to prevent the banner from displaying repeatedly.

---

## Phase 13: Final Polish & Constitution Alignment
**Goal:** Address Constitution constraints on `ValueKey` usage, strictly anchor the grace period calculation, and enforce data integrity on the `SubscriptionRequest` amount object.

- [x] T043 [C1] Ensure `WalletCard` and `EmployeeCard` lists utilize composite `ValueKey`s that explicitly incorporate `isFrozen` / `isSuspended` booleans (e.g., `ValueKey('${id}_${isFrozen}')`) to guarantee Flutter natively rebuilds corresponding items without full-list state invalidation per Constitution Principle 7.
- [x] T044 [A1] Update `StoreSubscription.isExpired` to strictly calculate the 48-hour usability extension initialized from `SubscriptionRequest.createdAt` rather than extrapolating blindly from `endDate`, ensuring precision on the grace window.
- [x] T045 [U1] Update `SubscriptionRequestModel` generation inside the payment modal (`payment_modal_screen.dart` / `SubscriptionRepository`) to implicitly deduce the accurate `amount` using the `tierName` locally. Strictly enforce that the user cannot input, intercept, or manually specify the `amount` variable dynamically in the UI.

---

## Phase 14: Data Preservation & Final Polish
**Goal:** Address audit gaps (C1, A1, G1, I1) to preserve legacy data, clarify anti-fraud strategy, ensure strict constitution adherence with background syncing, and polish unbounded UI visual states.

- [x] T046 [C1] Update `StoreModel.fromFirestore` and `toFirestore` in `lib/data/models/store_model.dart` to strictly preserve legacy fields `licenseKey` and `licenseKeyId` directly or inside a new `legacyData` map. This prevents FR-04 violation and ensures data is not permanently deleted during serialization.
- [x] T047 [A1] Clarify `DeviceTrackingService.verifyDevice()` (T012) logic to explicitly perform a client-side Firestore query against the `device_registry` collection. This MVP phase will use direct client-side reads rather than server-side Cloud Functions.
- [x] T048 [G1] Update background SMS handling logic in `lib/presentation/overlays/overlay_provider.dart` to explicitly utilize the Constitution Principle 6 `_blockAutoFetch` (Fetch Shield) immediately when parsing and mutating local transaction/wallet data limits to prevent unnecessary janky UI rebuilds.
- [x] T049 [I1] Update `SubscriptionDetailsScreen` (T030) in `lib/presentation/screens/subscription/subscription_details_screen.dart` to check if `maxWallets` or `maxEmployees` is 999. If true (Lifetime/Trial plan), bypass the fractional progress bar entirely and render an "Infinity" (∞) or "Unlimited" visual state.

---

## Phase 15: Architecture Hardening & Edge Cases
**Goal:** Address audit gaps from analysis to ensure complete closed-loop anti-fraud, correct atomic transactions, reliable success feedback, and precise limit fallback overrides.

- [x] T050 [C1] Implement explicit writing of device data: After a successful new user registration or store creation on a trial plan, write the device hardware identifier directly to the `device_registry` Firestore collection to finalize the anti-fraud step.
- [x] T051 [C2] Implement upgrade detection in `SubscriptionProvider`: Cache the previous `StoreSubscription` state and actively evaluate transitions from `pendingRequestDate != null` (pending state) to an upgraded paid `planId` where `pendingRequestDate == null` (cleared by server approval). Upon detection, dependably trigger `hasSeenSuccessModal` state.
- [x] T052 [A1] Guarantee atomic payment submission: Update `submitSubscriptionRequest` (T025/T045) in `SubscriptionRepository` to enforce the use of a Firestore `WriteBatch`. The creation of the `SubscriptionRequest` document AND the update to the store's `pendingRequestDate` (as a timestamp) MUST execute simultaneously.
- [x] T053 [I1] Enhance local gatekeeper fallback: Update the limit calculations inside `SubscriptionProvider` (`canAddWallet`, `canAddEmployee`) to explicitly evaluate if `isExpired == true && pendingRequestDate == null`. If so, fallback the allowed limits instantly to the "Free" tier caps (3 wallets, 1 employee) before evaluating the user check.

## Phase 16: Navigation & Documentation Polish
Goal: Ensure discoverability of subscription features and finalize terminology alignment.

- [x] T054 [C1] Wire navigation entry: Add a menu item to the main app Drawer or Settings screen that routes the user to the "My Subscription Details" screen (T030) for plan transparency.
- [x] T055 [T1] Documentation Polish: Verify that all internal code comments and repository documentation strictly reference `pendingRequestDate` as the anchor for 48-hour grace period calculations.

---

## Phase 17: Pure Architecture & Final Refinements
**Goal:** Close the final three analysis gaps — background suspension propagation (U1), single-source-of-truth for pending payment state (I2), and pure data model with no service dependencies (C1).

- [x] T056 [U1] Update `SubscriptionProvider._syncToLocalStorage()` in `lib/providers/subscription_provider.dart` to additionally persist `is_suspended` as a boolean key to `SharedPreferences` whenever the store subscription changes. Update `LocalStorageService` to expose a corresponding `subIsSuspended` getter. Update the background SMS guard in `lib/presentation/overlays/overlay_provider.dart` (T022) to read this flag and halt immediately when `subIsSuspended == true`, ensuring suspension is enforced inside the isolate with no live Firestore connection required.

- [x] T057 [I2] Deprecate all remaining boolean `hasPendingRequest` field usage across the codebase. Mandate `pendingRequestDate != null` as the single source of truth for detecting an in-flight payment request. Specifically: (a) Update all `StoreSubscription`, `SubscriptionProvider`, and UI banner logic to evaluate `subscription.pendingRequestDate != null` in place of any standalone boolean. (b) Update `submitSubscriptionRequest` in `lib/data/repositories/subscription_repository.dart` to write only `pendingRequestDate` (as a Firestore server timestamp) to the store document — no separate `hasPendingRequest` boolean field should be written or read. (c) Update `StoreSubscription.fromMap` in `lib/data/models/store_model.dart` to parse `pendingRequestDate` from the Firestore map and derive pending state purely from its nullability.

- [x] T058 [C1] Refactor `StoreSubscription` in `lib/data/models/store_model.dart` into a **pure POJO** by removing all direct calls to `TimeService` / `NtpService` from within the model class. Replace the `isExpired` getter with an explicit `isExpiredAt(DateTime serverNow)` method that accepts a pre-resolved server timestamp as a plain parameter. Update `SubscriptionProvider` to: (a) resolve the server-adjusted `DateTime` via `TimeService` and the cached NTP offset, and (b) call `subscription.isExpiredAt(resolvedNow)` for all expiration-gating decisions. This ensures `StoreSubscription` has zero external dependencies and all time-resolution logic is centralized exclusively in the domain layer.
