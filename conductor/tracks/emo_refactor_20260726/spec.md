# Spec: Identity Synchronization, Session Protection & Employee Experience Stabilization

## Overview

The application suffers from an **Identity Disconnect** for employee accounts. Firebase Authentication successfully retrieves the user's UID, but the system fails to resolve the corresponding employee document in Firestore due to direct document lookups combined with RBAC restrictions. This triggers cascading failures: forced logouts via `auth_error_session_expired`, permission-denied exceptions from eager owner-only resource loading, legacy wallet deserialization failures, and UI layout issues.

This track rebuilds the bridge between Firebase Authentication identity and Firestore authorization, ensuring employees receive a stable, permission-aware experience.

## Track Type

Refactor / Bug Fix (multi-phase stabilization)

## Strict Engineering Constraints

- **C-1:** DO NOT modify `firestore.rules`.
- **C-2:** ALL missing timestamps in models MUST remain `null` — absolutely NO use of `DateTime.now()` as a fallback for deserialization. This violates the project's Timestamp Handling Strategy. Fields must be `DateTime?` (nullable).
- **C-3:** Catch explicitly `permission-denied` exceptions only — other system errors must surface normally through existing error handling.

## Functional Requirements

### FR-1: Identity Synchronization (Phase 1)

- **FR-1.1:** In `lib/data/repositories/user_repository.dart`, modify `getUserById(String userId)`. Inside the catch block for `FirebaseException`, if `e.code == 'permission-denied'`, implement a fallback query: `_usersCollection.where('firebaseUid', isEqualTo: userId).limit(1).get()`. Return the parsed `UserModel` if found, otherwise return `null`.
- **FR-1.2:** In `lib/domain/usecases/wallet_usecase.dart`, modify `validatePermission()`. Wrap `_authProvider.ensureUserLoaded()` in a try-catch block. If a `PermissionDeniedException` is caught, immediately throw a `PermissionException()`. DO NOT allow the flow to reach the `user == null` check that throws `AuthException('auth_error_session_expired')`.

### FR-2: Eager Initialization Guards (Phase 2)

- **FR-2.1:** In `lib/providers/statistics_provider.dart`, modify `fetchDashboardStats()`. Add a guard: check `_authProvider.currentUser`. If the user is an employee and `!user.hasPermission((p) => p.viewDashboardStats)`, silently return without executing the Firestore fetch.
- **FR-2.2:** In `lib/providers/wallet_provider.dart`, locate the initialization block calling `_walletRepository.resetLimitsForWallets()`. Wrap this call in an `if (_authProvider.isOwner)` check.
- **FR-2.3:** In `lib/providers/subscription_provider.dart`, modify `_fetchLatestRequest()`. Catch `FirebaseException` with `code == 'permission-denied'` and silently return without calling `AppErrorHandler.handle()`.
- **FR-2.4:** All restricted sections (stats dashboard, subscription UI, owner-only maintenance) must be **completely hidden** from the employee UI.

### FR-3: Data Resilience (Phase 3)

- **FR-3.1:** In `lib/data/models/wallet_model.dart`, modify the `fromMap` factory. Remove the statements that throw `NotFoundException` when `createdAt`, `lastDailyReset`, or `lastMonthlyReset` are `null`.
- **FR-3.2:** Parse timestamps directly via `(data[key] as Timestamp?)?.toDate()` — allowing the fields to store `null`.
- **FR-3.3:** The `WalletModel` fields `createdAt`, `lastDailyReset`, `lastMonthlyReset` must be typed as `DateTime?` (nullable).

### FR-4: UI/UX Polish (Phase 4)

- **FR-4.1:** In `lib/presentation/widgets/wallet/wallet_card.dart`, locate the inner `Row` containing the wallet icon and the `l10n.currentBalance` text. Wrap this inner `Row` in an `Expanded` widget. Wrap the `Text(l10n.currentBalance)` inside a `Flexible` widget and set `overflow: TextOverflow.ellipsis`.
- **FR-4.2:** In `lib/presentation/screens/transactions/create_transaction_screen.dart`, modify `_updateTotal()`. After parsing `amount`, add `if (amount <= 0) return;` to prevent `TransactionFeeCalculator` from spamming `DomainException` to the error handler.

## Non-Functional Requirements

- **NFR-1:** No existing owner-flow behavior may change. All modifications must be additive guards or conditional logic.
- **NFR-2:** No new Crashlytics noise — all expected authorization failures for employees must be silently handled.
- **NFR-3:** All changes must follow the project's Clean Architecture boundaries.
- **NFR-4:** All changes must maintain >80% code coverage with unit tests.

## Acceptance Criteria

- [ ] An employee can log in via `tryAutoLogin()` and reach the dashboard without being force-logged-out.
- [ ] Permission-denied errors from Firestore do not trigger `auth_error_session_expired`.
- [ ] Employee dashboard does not show statistics, subscription UI, or owner-only maintenance controls.
- [ ] No `permission-denied` exceptions appear in Crashlytics for employee sessions.
- [ ] Legacy wallet documents (missing `createdAt`/`lastDailyReset`/`lastMonthlyReset`) deserialize with `null` timestamps — no exceptions thrown.
- [ ] Long Arabic wallet labels in `WalletCard` are truncated with ellipsis, no RenderFlex overflow.
- [ ] Empty/zero transaction amount fields do not produce `DomainException` logs.
- [ ] All existing owner-flow unit tests continue to pass without modification.
- [ ] `flutter analyze` passes cleanly after all changes.

## Out of Scope

- Redesigning the employee permissions model or RBAC system.
- Adding new employee-specific features or screens.
- Migrating legacy wallet documents to add missing fields in Firestore.
- Firestore security rules changes (`firestore.rules` must not be modified).
- Using `DateTime.now()` or any synthetic fallback for missing timestamp fields.
