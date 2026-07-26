# Plan: Identity Synchronization, Session Protection & Employee Experience Stabilization

## Phase 1 — Identity Synchronization & Session Protection [checkpoint: 470773e]

- [x] Task: Write failing tests for `UserRepository.getUserById()` permission-denied fallback query [d2a035d]
    - [x] Test that when `getUserById()` throws `FirebaseException` with `permission-denied`, a fallback query on `_usersCollection.where('firebaseUid', isEqualTo: userId).limit(1)` is executed
    - [x] Test that the fallback query returns a parsed `UserModel` when a matching document exists
    - [x] Test that the fallback query returns `null` when no matching document exists
    - [x] Test that non-`permission-denied` `FirebaseException` codes are rethrown normally

- [x] Task: Implement `UserRepository.getUserById()` fallback query [d2a035d]
    - [x] In `lib/data/repositories/user_repository.dart`, add a catch block for `FirebaseException` inside `getUserById()`
    - [x] When `e.code == 'permission-denied'`, execute fallback query: `_usersCollection.where('firebaseUid', isEqualTo: userId).limit(1).get()`
    - [x] Parse and return the `UserModel` if a document is found; return `null` otherwise
    - [x] Rethrow all other `FirebaseException` codes
    - [x] Run tests and confirm they pass

- [x] Task: Write failing tests for `WalletUseCase.validatePermission()` session protection [c4e2e8c]
    - [x] Test that when `ensureUserLoaded()` throws `PermissionDeniedException`, `validatePermission()` throws `PermissionException` (not `AuthException`)
    - [x] Test that `AuthException('auth_error_session_expired')` is never thrown on permission-denied
    - [x] Test that non-permission exceptions from `ensureUserLoaded()` propagate unchanged

- [x] Task: Implement `WalletUseCase.validatePermission()` session protection [c4e2e8c]
    - [x] In `lib/domain/usecases/wallet_usecase.dart`, wrap `_authProvider.ensureUserLoaded()` in a try-catch
    - [x] Catch `PermissionDeniedException` and throw `PermissionException()` instead
    - [x] Ensure the flow never reaches the `user == null` check that throws `AuthException('auth_error_session_expired')`
    - [x] Run tests and confirm they pass

- [x] Task: Conductor - User Manual Verification 'Phase 1 — Identity Synchronization & Session Protection' (Protocol in workflow.md) [470773e]

## Phase 2 — Eager Initialization Guards [checkpoint: bdecd71]

- [x] Task: Write failing tests for `StatisticsProvider` employee guard [92aa3f4]
    - [x] Test that `fetchDashboardStats()` returns early without Firestore call when user is employee without `viewDashboardStats` permission
    - [x] Test that `fetchDashboardStats()` proceeds normally for owners
    - [x] Test that `fetchDashboardStats()` proceeds normally for employees with `viewDashboardStats` permission

- [x] Task: Implement `StatisticsProvider.fetchDashboardStats()` employee guard [92aa3f4]
    - [x] In `lib/providers/statistics_provider.dart`, add guard clause checking `_authProvider.currentUser`
    - [x] If user is employee and `!user.hasPermission((p) => p.viewDashboardStats)`, silently return
    - [x] Run tests and confirm they pass

- [x] Task: Write failing tests for `WalletProvider` employee guard on `resetLimitsForWallets()` [95b406f]
    - [x] Test that `resetLimitsForWallets()` is not called when user is an employee
    - [x] Test that `resetLimitsForWallets()` proceeds normally for owners

- [x] Task: Implement `WalletProvider` employee guard on `resetLimitsForWallets()` [95b406f]
    - [x] In `lib/providers/wallet_provider.dart`, wrap the `resetLimitsForWallets()` call in `if (_authProvider.isOwner)`
    - [x] Run tests and confirm they pass

- [x] Task: Write failing tests for `SubscriptionProvider` silent permission-denied handling [7ef8b8c]
    - [x] Test that `_fetchLatestRequest()` catches `FirebaseException` with `permission-denied` silently
    - [x] Test that the exception is NOT passed to `AppErrorHandler.handle()`
    - [x] Test that non-`permission-denied` exceptions are handled normally

- [x] Task: Implement `SubscriptionProvider._fetchLatestRequest()` silent exception handling [7ef8b8c]
    - [x] In `lib/providers/subscription_provider.dart`, add catch for `FirebaseException` with `code == 'permission-denied'`
    - [x] Silently return without calling `AppErrorHandler.handle()`
    - [x] Run tests and confirm they pass

- [x] Task: Conductor - User Manual Verification 'Phase 2 — Eager Initialization Guards' (Protocol in workflow.md) [bdecd71]

## Phase 3 — Data Resilience & Legacy Data Support

- [ ] Task: Write failing tests for `WalletModel.fromMap()` nullable timestamp handling
    - [ ] Test that a map with missing `createdAt` field deserializes to a `WalletModel` with `createdAt == null`
    - [ ] Test that a map with missing `lastDailyReset` field deserializes to a `WalletModel` with `lastDailyReset == null`
    - [ ] Test that a map with missing `lastMonthlyReset` field deserializes to a `WalletModel` with `lastMonthlyReset == null`
    - [ ] Test that a map with all timestamps present deserializes correctly
    - [ ] Test that a map missing fundamental fields (e.g., `name`, `storeId`) still throws appropriately

- [ ] Task: Implement `WalletModel.fromMap()` nullable timestamp support
    - [ ] In `lib/data/models/wallet_model.dart`, change `createdAt`, `lastDailyReset`, `lastMonthlyReset` fields from `DateTime` to `DateTime?`
    - [ ] Remove `NotFoundException` throws for missing timestamp fields
    - [ ] Parse via `(data[key] as Timestamp?)?.toDate()` allowing null
    - [ ] Update all callers that reference these fields to handle nullable types
    - [ ] Run tests and confirm they pass

- [ ] Task: Conductor - User Manual Verification 'Phase 3 — Data Resilience & Legacy Data Support' (Protocol in workflow.md)

## Phase 4 — UI/UX Polish

- [ ] Task: Write failing tests for WalletCard layout overflow fix
    - [ ] Test that the wallet card widget renders without overflow for long Arabic text labels
    - [ ] Test that the `currentBalance` text widget uses `TextOverflow.ellipsis`

- [ ] Task: Implement WalletCard layout overflow fix
    - [ ] In `lib/presentation/widgets/wallet/wallet_card.dart`, wrap the inner `Row` (icon + balance label) with `Expanded`
    - [ ] Wrap the `Text(l10n.currentBalance)` widget with `Flexible` and set `overflow: TextOverflow.ellipsis`
    - [ ] Run tests and confirm no overflow

- [ ] Task: Write failing tests for `_updateTotal()` early return guard
    - [ ] Test that `_updateTotal()` returns early when amount is `0`
    - [ ] Test that `_updateTotal()` returns early when amount is negative
    - [ ] Test that `_updateTotal()` proceeds normally when amount is positive

- [ ] Task: Implement `CreateTransactionScreen._updateTotal()` early return guard
    - [ ] In `lib/presentation/screens/transactions/create_transaction_screen.dart`, add `if (amount <= 0) return;` after parsing amount
    - [ ] Run tests and confirm they pass

- [ ] Task: Conductor - User Manual Verification 'Phase 4 — UI/UX Polish' (Protocol in workflow.md)
