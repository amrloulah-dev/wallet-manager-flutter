# Spec: Fix Logout Navigation & Debt Filters

## Overview

This track addresses two critical bugs in the Wallet Manager application:
1. **BUG-01 (Infinite Loading on Logout):** When the user logs out, the application gets stuck on an infinite loading spinner. This is caused by a sticky instance-level `_isNavigating` flag in `AuthCheckWrapper` which is never reset to `false`, combined with redundant, conflicting imperative navigation logic in `app_drawer.dart` and `logout_button.dart` racing against the `AuthCheckWrapper` state rebuild.
2. **BUG-02 (Debt Tabs & Filters Not Working):** Switching between Debt tabs (Transaction/Store Sale) and filters (All/Open/Paid) in the UI does not filter the list of debts shown. The `DebtProvider` stores the UI filter state, but never passes these filters down to `DebtRepository.getDebtsByDateRange()`, resulting in all debts always being loaded.

---

## Functional Requirements

### FR-1: Fix BUG-01 — Infinite Loading on Logout

1.  **Single Source of Truth in `AuthCheckWrapper` (`lib/app.dart`):**
    - Modify `AuthCheckWrapper`'s build state. Reset `_isNavigating` to `false` when `auth.status == AuthStatus.unauthenticated || auth.status == AuthStatus.error`.
    - If `unauthenticated` or in `error` status, return `LoginLandingScreen()` or its appropriate UI.
    - This ensures that if the user logs out (or logout fails with an error), the sticky `_isNavigating` flag is correctly reset to `false`, preventing the infinite loading spinner and allowing the next login flow or error screen to function correctly.
2.  **Remove Imperative Navigation from UI Logout Elements:**
    - In `lib/presentation/widgets/dashboard/app_drawer.dart` and `lib/presentation/screens/settings/widgets/logout_button.dart`:
      - Remove `Navigator.of(context).pushNamedAndRemoveUntil(...)` logic inside the logout confirmation callbacks.
      - Component callbacks must only trigger the auth status change by calling `await authProvider.logout()`.
      - Note: Do NOT add redundant try/catch blocks in the UI buttons since `authProvider.logout()` already handles exceptions internally and sets `_status = AuthStatus.error`.

### FR-2: Fix BUG-02 — Debt Tabs & Filters

1.  **Enhance `DebtRepository.getDebtsByDateRange` (`lib/data/repositories/debt_repository.dart`):**
    - Update the signature of `getDebtsByDateRange` to accept optional `debtType` (String?) and `debtStatus` (String?) parameters.
    - Within the method, conditionally append Firestore `.where()` filters if these parameters are passed and are not `'all'`.
      - `.where('debtType', isEqualTo: debtType)`
      - `.where('debtStatus', isEqualTo: debtStatus)`
    - *Note:* Append these filters before the `.orderBy('createdAt', descending: true)` clause.
2.  **Update `DebtProvider` calling logic (`lib/providers/debt_provider.dart`):**
    - In `fetchInitialDebts()` and `fetchMoreDebts()` (if applicable), update the call to `_debtRepository.getDebtsByDateRange` to pass:
      - `debtType`: `_currentDebtType.name`
      - `debtStatus`: `_currentFilter == 'all' ? null : _currentFilter`
    - Ensure correct handling of the loading, loaded, and error states.
    - **Clear Pagination State on Filter Changes:** Inside `setDebtType` and `setFilter`, explicitly clear `_debts` and set `_lastDocument = null` BEFORE calling `fetchInitialDebts()`.

---

## Non-Functional Requirements

- **NFR-1: Navigation Stability:** Ensure no race conditions between widget rebuilds and imperative routing.
- **NFR-2: Query Efficiency:** Filters must be applied on the server-side (Firestore) rather than locally in the Dart layer, preserving the "Zero-Unbounded-Read" guarantee and cursor-based pagination.
- **NFR-3: Error Resilience:** Ensure failed logouts are caught, sanitized, and reported to Crashlytics/User without leaving the app in an unusable state.

---

## Acceptance Criteria

- [ ] Logging out from the App Drawer or Settings Screen resets `_isNavigating` to `false` and smoothly routes the user to `LoginLandingScreen`.
- [ ] No imperative `Navigator` logic remains in the logout confirmation callbacks of `AppDrawer` and `LogoutButton`.
- [ ] A failed logout handles exceptions gracefully and does not result in an infinite spinner.
- [ ] Switching between "Transfers" (transaction) and "Sales" (storeSale) tabs in the Debts screen correctly filters the list of displayed debts.
- [ ] Switching between "Open" and "Paid" filters in the Debts screen correctly filters the list of displayed debts.
- [ ] "All" filter displays all debts of the selected tab.
- [ ] Server-side Firestore queries for debts include correct `.where()` clauses for `debtType` and `debtStatus` when filters are active.
- [ ] Unit tests for `AuthCheckWrapper` state transitions and `DebtProvider` / `DebtRepository` filtering logic pass successfully.

---

## Out of Scope

- Migrating or altering database document structures; only standard `where` queries are applied on existing field mappings.
