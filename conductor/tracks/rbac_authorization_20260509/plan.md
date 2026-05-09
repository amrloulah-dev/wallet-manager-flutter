# Implementation Plan: RBAC & Authorization Master Blueprint

## Phase 1: Server-Side Security & Data Types
- [x] Task: Update `firestore.rules`
    - [x] Write tests for Firestore security rules.
    - [x] Implement role-based write restrictions for `wallets`, `transactions`, and `debts`.
    - [x] Secure `license_keys` to prevent reading by authenticated users.
- [x] Task: Refactor `UserRole` Enum
    - [x] Write unit tests for `UserRole` Enum parsing and fail-closed logic.
    - [x] Convert string roles to `UserRole` Enum (`owner`, `employee`, `unknown`) in `lib/core/enums/user_enums.dart`.
    - [x] Update `UserModel` to use `UserRole` and implement lazy migration for `SharedPreferences`.
    - [x] Modify `UserRole.fromString` to throw `ArgumentError` or return `UserRole.unknown` for invalid values.
- [x] Task: Conductor - User Manual Verification 'Server-Side Security & Data Types' (Protocol in workflow.md)
    - Checkpoint SHA: a6dfd08

## Phase 2: Repository Hardening & Tenant Isolation
- [x] Task: Apply Tenant Isolation to Repositories
    - [x] Write failing unit/integration tests for repository data access violations.
    - [x] Update `getById` methods in `wallet_repository.dart`, `transaction_repository.dart`, and `debt_repository.dart` to accept `expectedStoreId`.
    - [x] Implement post-fetch guards asserting `fetchedModel.storeId == expectedStoreId`.
- [x] Task: Handle Repository Edge Cases
    - [x] Write failing tests for unauthorized deletion and storeId mutation.
    - [x] Add `isOwner` check and `callerUserId` verification to `UserRepository.hardDeleteUser`.
    - [x] Add assertion to `WalletRepository.updateWallet` to prevent `storeId` mutation.
    - [x] Add `storeId` scope to `WalletRepository.watchWallet`.
- [x] Task: Conductor - User Manual Verification 'Repository Hardening & Tenant Isolation' (Protocol in workflow.md)
    - Checkpoint SHA: e21d18e

## Phase 3: Provider-Level Security & Cache Integrity
- [x] Task: Enforce Provider-Level Permissions
    - [x] Write unit tests for Provider permission guards.
    - [x] Add `_validateUserAndPermission` to `TransactionProvider` sensitive mutations.
    - [x] Add `isOwner` guard to `EmployeeProvider` mutations (add, deactivate, reset PIN, update permissions).
    - [x] Fix permission mappings in `WalletProvider.deleteWallet` (use delete permission/isOwner) and `DebtProvider` (use `collectDebt`).
- [x] Task: Secure Authentication & Cache
    - [x] Write unit tests for local session creation logic.
    - [x] Fix lazy provisioning in `IdentityService.authenticateEmployee` to require valid Firebase Token.
    - [x] Secure subscription limits in `SharedPreferences` (enforce strict Firestore re-validation within TTL or use HMAC).
- [x] Task: Conductor - User Manual Verification 'Provider-Level Security & Cache Integrity' (Protocol in workflow.md)
    - Checkpoint SHA: d3ac997

## Phase 4: Route-Level Security & Global Audit
- [x] Task: Implement Route Guard
    - [x] Write tests for `RouteGuard` middleware.
    - [x] Implement `RouteGuard` in `AppRouter` (`lib/routes/app_router.dart`).
    - [x] Implement redirect to Dashboard with non-blocking UI message for unauthorized access.
- [x] Task: Expand PermissionHelper Coverage
    - [x] Write tests for `PermissionHelper.canAccessScreen`.
    - [x] Expand the `switch` statement in `PermissionHelper.canAccessScreen` to cover ALL sensitive screen routes.
- [x] Task: Global Audit and Cleanup
    - [x] Run global audit to replace hardcoded strings (`'owner'`, `'employee'`) with Enum checks in `lib/presentation/` and other layers.
    - [x] Verify zero hardcoded role strings exist for authorization logic.
- [x] Task: Conductor - User Manual Verification 'Route-Level Security & Global Audit' (Protocol in workflow.md)
    - Checkpoint SHA: 3be8e1d

## Phase: Review Fixes
- [x] Task: Apply review suggestions 4eb007c