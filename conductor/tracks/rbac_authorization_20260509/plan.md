# Implementation Plan: RBAC & Authorization Master Blueprint

## Phase 1: Server-Side Security & Data Types
- [ ] Task: Update `firestore.rules`
    - [ ] Write tests for Firestore security rules.
    - [ ] Implement role-based write restrictions for `wallets`, `transactions`, and `debts`.
    - [ ] Secure `license_keys` to prevent reading by authenticated users.
- [ ] Task: Refactor `UserRole` Enum
    - [ ] Write unit tests for `UserRole` Enum parsing and fail-closed logic.
    - [ ] Convert string roles to `UserRole` Enum (`owner`, `employee`, `unknown`) in `lib/core/enums/user_enums.dart`.
    - [ ] Update `UserModel` to use `UserRole` and implement lazy migration for `SharedPreferences`.
    - [ ] Modify `UserRole.fromString` to throw `ArgumentError` or return `UserRole.unknown` for invalid values.
- [ ] Task: Conductor - User Manual Verification 'Server-Side Security & Data Types' (Protocol in workflow.md)

## Phase 2: Repository Hardening & Tenant Isolation
- [ ] Task: Apply Tenant Isolation to Repositories
    - [ ] Write failing unit/integration tests for repository data access violations.
    - [ ] Update `getById` methods in `wallet_repository.dart`, `transaction_repository.dart`, and `debt_repository.dart` to accept `expectedStoreId`.
    - [ ] Implement post-fetch guards asserting `fetchedModel.storeId == expectedStoreId`.
- [ ] Task: Handle Repository Edge Cases
    - [ ] Write failing tests for unauthorized deletion and storeId mutation.
    - [ ] Add `isOwner` check and `callerUserId` verification to `UserRepository.hardDeleteUser`.
    - [ ] Add assertion to `WalletRepository.updateWallet` to prevent `storeId` mutation.
    - [ ] Add `storeId` scope to `WalletRepository.watchWallet`.
- [ ] Task: Conductor - User Manual Verification 'Repository Hardening & Tenant Isolation' (Protocol in workflow.md)

## Phase 3: Provider-Level Security & Cache Integrity
- [ ] Task: Enforce Provider-Level Permissions
    - [ ] Write unit tests for Provider permission guards.
    - [ ] Add `_validateUserAndPermission` to `TransactionProvider` sensitive mutations.
    - [ ] Add `isOwner` guard to `EmployeeProvider` mutations (add, deactivate, reset PIN, update permissions).
    - [ ] Fix permission mappings in `WalletProvider.deleteWallet` (use delete permission/isOwner) and `DebtProvider` (use `collectDebt`).
- [ ] Task: Secure Authentication & Cache
    - [ ] Write unit tests for local session creation logic.
    - [ ] Fix lazy provisioning in `IdentityService.authenticateEmployee` to require valid Firebase Token.
    - [ ] Secure subscription limits in `SharedPreferences` (enforce strict Firestore re-validation within TTL or use HMAC).
- [ ] Task: Conductor - User Manual Verification 'Provider-Level Security & Cache Integrity' (Protocol in workflow.md)

## Phase 4: Route-Level Security & Global Audit
- [ ] Task: Implement Route Guard
    - [ ] Write tests for `RouteGuard` middleware.
    - [ ] Implement `RouteGuard` in `AppRouter` (`lib/routes/app_router.dart`).
    - [ ] Implement redirect to Dashboard with non-blocking UI message for unauthorized access.
- [ ] Task: Expand PermissionHelper Coverage
    - [ ] Write tests for `PermissionHelper.canAccessScreen`.
    - [ ] Expand the `switch` statement in `PermissionHelper.canAccessScreen` to cover ALL sensitive screen routes.
- [ ] Task: Global Audit and Cleanup
    - [ ] Run global audit to replace hardcoded strings (`'owner'`, `'employee'`) with Enum checks in `lib/presentation/` and other layers.
    - [ ] Verify zero hardcoded role strings exist for authorization logic.
- [ ] Task: Conductor - User Manual Verification 'Route-Level Security & Global Audit' (Protocol in workflow.md)