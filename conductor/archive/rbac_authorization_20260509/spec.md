# Track Specification: RBAC & Authorization Master Blueprint

## Overview
This track focuses on a high-stakes security and authorization refactoring for "Wallet Manager". The goal is to eliminate "Security by Obscurity", enforce strict role-based access control (RBAC), and prevent cross-tenant data leakage.

## Functional Requirements
1. **Route-Level Security**: Implement a `RouteGuard` middleware in `AppRouter` (`lib/routes/app_router.dart`).
   - Unauthorized access to sensitive routes must redirect back to the `Dashboard`.
   - Display a non-blocking UI message (e.g., `ToastUtils.showInfo("Unauthorized access")`) upon redirect.
   - **PermissionHelper Coverage**: In `PermissionHelper.canAccessScreen`, expand the `switch` statement to cover ALL sensitive screen routes, ensuring it doesn't fall through to `return false` for valid owner/employee routes.
2. **Provider-Level Security & Permission Mappings**:
   - `TransactionProvider`: Add `await _validateUserAndPermission(...)` in sensitive mutations like `createTransaction`.
   - `EmployeeProvider`: Add explicit guard `if (!_authProvider.isOwner) throw PermissionDeniedException();` to mutations (add, deactivate, reset PIN, update permissions).
   - **Provider Permission Mappings**: Fix mismatched permissions. In `WalletProvider.deleteWallet`, use a delete permission or restrict to `isOwner`. In `DebtProvider`, use `(p) => p.collectDebt` for payment operations, not `createDebt`.
   - All providers must have an explicit internal authorization check for Firestore mutations.
3. **Repository Tenant Isolation & Edge Cases**:
   - Update `getById` methods in `wallet_repository.dart`, `transaction_repository.dart`, and `debt_repository.dart` to accept an `expectedStoreId`.
   - Implement post-fetch guards asserting `fetchedModel.storeId == expectedStoreId`. Throw `PermissionDeniedException` on failure.
   - **Repository Edge Cases**: In `WalletRepository`, add an assertion to `updateWallet` to prevent `storeId` mutation (`assert(!data.containsKey('storeId'))`). Also, add a `storeId` scope to `watchWallet`.
   - **User Repository Hardening**: Add an explicit `isOwner` check and a `callerUserId` verification to `UserRepository.hardDeleteUser` to prevent unauthorized permanent deletions.
4. **RBAC Refactoring (Enum-ification) & Security**:
   - Convert plain string roles to a strict `UserRole` Enum (`owner`, `employee`, `unknown`) in `lib/core/enums/user_enums.dart`.
   - Update `UserModel` to use the Enum.
   - For legacy data in `SharedPreferences`, implement lazy migration (convert string to Enum on read, save as Enum on next write).
   - **Enum Fail-Safe**: Modify `UserRole.fromString` to fail-closed. If an unknown string is parsed, throw an `ArgumentError` or default to `UserRole.unknown` (with zero permissions) instead of silently defaulting to `employee`.
5. **Server-Side Security**:
   - Update `firestore.rules` to add role-based write restrictions for `wallets`, `transactions`, and `debts` (e.g., restrict `delete` to `isStoreOwner`).
   - Secure `license_keys` to prevent any authenticated user from reading them.
6. **Authentication & Cache Integrity**:
   - **Identity Service Security**: Fix the lazy provisioning risk in `IdentityService.authenticateEmployee` to ensure local employee sessions are NEVER created without a valid Firebase Token.
   - **Subscription Cache Integrity**: Secure subscription limits stored in `SharedPreferences`. Enforce strict Firestore re-validation within the TTL window, or add a basic HMAC checksum to prevent manual tampering on rooted devices.

## Non-Functional Requirements
- **Global Audit Directive**: Ensure ALL providers, repositories, routes, and the **Presentation Layer** (`lib/presentation/`) are audited for compliance with these security patterns. Replace hardcoded strings (`'owner'`, `'employee'`) with Enum checks.
- Truth Source Enforcement: Critical authorization decisions must prioritize the Firestore-backed `_currentUser` state.

## Acceptance Criteria
- [ ] `AppRouter` blocks unauthorized access and displays a friendly unauthorized toast/message.
- [ ] `PermissionHelper.canAccessScreen` accurately covers all sensitive screen routes.
- [ ] `TransactionProvider.createTransaction` internally validates permissions before executing.
- [ ] `EmployeeProvider` mutation methods throw a `PermissionDeniedException` if the caller is not the owner.
- [ ] `WalletProvider.deleteWallet` and `DebtProvider` payment operations use correctly mapped permissions.
- [ ] All `Repository.getById` methods actively verify that the document's `storeId` matches the expected tenant.
- [ ] `WalletRepository.updateWallet` prevents `storeId` mutation, and `watchWallet` correctly scopes by `storeId`.
- [ ] `UserRepository.hardDeleteUser` correctly enforces `isOwner` and `callerUserId` checks.
- [ ] `UserModel.role` is successfully refactored to a strongly typed `UserRole` Enum, with lazy migration for local storage.
- [ ] `UserRole.fromString` acts as a fail-closed mechanism, throwing `ArgumentError` or returning `unknown` for invalid values.
- [ ] `firestore.rules` enforces role-based write restrictions and properly secures `license_keys`.
- [ ] `IdentityService.authenticateEmployee` mandates a valid Firebase Token before creating local sessions.
- [ ] Subscription limits in `SharedPreferences` are secured via strict TTL re-validation or HMAC checksums.
- [ ] Zero hardcoded role strings (`'owner'`, `'employee'`) exist for authorization logic in the presentation layer or business logic.

## Out of Scope
- Major UI redesigns not related to access control.
- New provider integrations (e.g., adding a new mobile wallet provider).