# 🚀 Wallet Manager - RBAC & Authorization Master Blueprint (Phase 6)

## 📌 1. General Context & Strict System Prompt
**To the AI Agent (Antigravity / Gemini CLI):**
You are performing a high-stakes security and authorization refactoring for "Wallet Manager". The goal is to eliminate "Security by Obscurity" (hiding UI elements), enforce strict role-based access control (RBAC), and prevent cross-tenant data leakage.
**Core Constraints:**
1. **Route-Level Security:** No sensitive screen should be accessible without an explicit authority check.
2. **Provider-Level Validation:** Every sensitive mutation (Create/Update/Delete) MUST verify the user's role/permission internally.
3. **GLOBAL AUDIT DIRECTIVE:** For every issue fixed, you MUST scan the entire `lib/` directory for the same anti-pattern (like hardcoded string checks) and apply the fix globally.

---

## 📌 2. CRITICAL: Route Guards & Navigation Security (Axis 1)

### Context
Static analysis identified a critical vulnerability where `AppRouter` uses a standard `switch` statement without middleware. Any user can access sensitive screens (e.g., `/manageEmployees`, `/settings`) via deep links or state glitches by bypassing the UI.

### The Fix (Surgical + Global Audit)
1. **Route Guard Middleware:** In `lib/routes/app_router.dart`, refactor `generateRoute` to include an authorization guard before yielding owner-only or permission-gated screens.
2. **Unauthorized Fallback:** If an employee attempts to access an unauthorized route, redirect them back to the `Dashboard` and display a non-blocking UI message (e.g., `ToastUtils.showInfo("Unauthorized access")`).
3. **Global Audit:** Scan all routes defined in `RouteConstants`. Ensure EVERY route is evaluated and properly protected by the `RouteGuard` if it handles sensitive data or settings.

---

## 📌 3. CRITICAL: Provider-Level Permission Enforcement (Axis 2)

### Context
`TransactionProvider` and `EmployeeProvider` execute sensitive mutations (e.g., `createTransaction`, `addEmployee`, `deactivateEmployee`) with zero role validation. They blindly trust that the UI hid the trigger buttons from unauthorized employees.

### The Fix (Surgical + Global Audit)
1. **Transaction Hardening:** In `lib/providers/transaction_provider.dart`, add `await _validateUserAndPermission((p) => p.createTransaction)` at the very beginning of the `createTransaction()` method.
2. **Employee Mutation Protection:** In `lib/providers/employee_provider.dart`, add an explicit guard `if (!_authProvider.isOwner) throw PermissionDeniedException();` to `addEmployee`, `deactivateEmployee`, `resetEmployeePIN`, and `updatePermissions`.
3. **Global Audit:** Scan ALL providers for methods that perform Firestore mutations (create, update, delete). Ensure every single one has an explicit internal authorization check (`isOwner` or `_validateUserAndPermission`).

---

## 📌 4. HIGH: Repository Tenant Isolation (Axis 3)

### Context
Repositories fetch documents by ID (`getWalletById`, `getTransactionById`, `getDebtById`) without verifying if the requested document belongs to the caller's `storeId`. This creates a severe risk of cross-tenant data leakage if an ID is guessed or shared.

### The Fix (Surgical + Global Audit)
1. **Surgical Verification:** Update `getWalletById` in `wallet_repository.dart`, `getTransactionById` in `transaction_repository.dart`, and `getDebtById` in `debt_repository.dart` to accept an `expectedStoreId` parameter.
2. **Post-Fetch Guard:** After fetching the document from Firestore, explicitly assert `fetchedModel.storeId == expectedStoreId`. If it fails, throw a `PermissionDeniedException`.
3. **Global Audit:** Scan the entire `lib/data/repositories/` directory for ANY `getById` or direct document fetch queries. Ensure they all include `storeId` validation either in the query or as a post-fetch guard.

---

## 📌 5. MEDIUM: RBAC Refactoring & Data Integrity (Axis 4)

### Context
The application relies on plain strings for user roles (e.g., `user.role == 'owner'`) and over-trusts locally cached data in `SharedPreferences`, which is vulnerable to tampering on rooted devices.

### The Fix (Surgical + Global Audit)
1. **Enum-ification:** In `lib/core/enums/user_enums.dart`, ensure `UserRole` is a strictly typed Enum (`owner`, `employee`). Update `UserModel` to utilize this Enum instead of a plain String, handling serialization safely.
2. **Truth Source Enforcement:** Ensure critical authorization decisions (like `isOwner` checks in `AuthProvider`) prioritize the Firestore-backed `_currentUser` state rather than trusting `LocalStorageService.userRole`.
3. **Global Audit:** Grep the entire `lib/` directory (especially `presentation/` widgets) for hardcoded string comparisons like `role == 'owner'` or `role == 'employee'`. Replace them with typed Enum checks (e.g., `user.role == UserRole.owner`) or `PermissionHelper` methods.

---

## 📌 Acceptance Criteria
- [ ] `AppRouter` blocks unauthorized access and displays a friendly unauthorized toast/message.
- [ ] `TransactionProvider.createTransaction` internally validates permissions before executing.
- [ ] `EmployeeProvider` mutation methods throw a `PermissionDeniedException` if the caller is not the owner.
- [ ] All `Repository.getById` methods actively verify that the document's `storeId` matches the expected tenant.
- [ ] `UserModel.role` is successfully refactored to a strongly typed `UserRole` Enum.
- [ ] Zero hardcoded role strings (`'owner'`, `'employee'`) exist for authorization logic in the presentation layer.