# Identity Synchronization, Session Protection, and Employee Experience Stabilization

## 🌐 Global Context

### Architectural Problem

The system currently suffers from an **Identity Disconnect** for employee accounts.

During authentication, the application successfully retrieves the user's **Firebase Authentication UID**, but fails to correctly resolve the corresponding employee document inside **Cloud Firestore** because of direct document lookups combined with **RBAC (Role-Based Access Control)** restrictions.

This identity mismatch triggers a cascade of failures throughout the application:

- The system incorrectly assumes that the authentication session has expired and forcibly logs the employee out by throwing `auth_error_session_expired`.
- Eager initialization attempts to load statistics, subscription requests, and other owner-only resources, causing widespread `permission-denied` exceptions.
- Legacy wallet documents are rejected because of overly strict data model validation.
- The employee experience becomes unstable despite having a valid authenticated session.

---

## 🎯 Strategic Goal

Rebuild the bridge between **Firebase Authentication Identity** and **Firestore Authorization** while preserving session integrity.

The implementation should:

- Correctly synchronize authenticated users with their Firestore employee records.
- Clearly separate **authentication** ("Who is the user?") from **authorization** ("What is the user allowed to do?").
- Replace forced logout behavior with **Graceful Denial** whenever permissions are insufficient.
- Improve resilience against legacy data.
- Polish UI and UX issues so employees receive a stable experience equivalent to owners, while remaining fully constrained by RBAC permissions.

---

# 🗺️ Phase 1 — Identity Synchronization & Session Protection

## Phase Context

The root architectural issue exists inside the authentication flow, particularly around:

- `tryAutoLogin()`
- `validatePermission()`

The application currently treats **Firestore permission errors** as **authentication failures**.

This is fundamentally incorrect.

The implementation must strictly distinguish between:

- **Authentication** → "Who is the user?"
- **Authorization** → "What can the user access?"

A permission failure must **never** invalidate a valid authentication session.

---

## Required Tasks

### 1. Update `UserRepository` and `DatabaseSyncService`

#### Objective

Replace direct employee document lookups with a Firestore query based on the employee's `firebaseUid`.

Instead of relying on document IDs (which may be inaccessible because of security rules), the repository should safely locate the employee using:

- Query by `firebaseUid`
- Compatible with Firestore `list` security rules
- Return the matching employee document without violating RBAC constraints

---

### 2. Fix `WalletUseCase.validatePermission()`

#### Objective

Handle authorization failures without destroying the authentication session.

Implementation requirements:

- Explicitly catch `PermissionDeniedException` (or the equivalent `FirebaseException` with `permission-denied`).
- Convert the exception into a local `PermissionException`.
- Stop the current operation gracefully.
- **Never** propagate the error as:

```text
AuthException('auth_error_session_expired')
```

The user must remain logged in.

Only the restricted operation should fail.

---

# 🗺️ Phase 2 — Eager Initialization Guards

## Phase Context

When `MainDashboardScreen` opens, `_fetchInitialData()` eagerly requests nearly every application resource:

- Dashboard statistics
- Wallets
- Transactions
- Subscription requests
- Other owner resources

Employees do not have permission to access many of these endpoints.

Instead of requesting everything and relying on Firestore to reject unauthorized operations, the application should adopt a **Check-Before-Request** pattern.

---

## Required Tasks

### 1. Protect `StatisticsProvider`

#### Objective

Prevent dashboard statistics from loading unless the user actually has permission.

Implementation requirements:

- Add a guard clause before `fetchDashboardStats()`.
- If the current user is an employee without the `viewDashboardStats` permission:
  - Skip the request entirely.
  - Do not trigger Firestore.
  - Do not produce permission errors.

---

### 2. Disable Wallet Maintenance for Employees

#### Objective

Prevent owner-only maintenance operations from executing for employees.

Implementation requirements:

Prevent `resetLimitsForWallets()` from executing whenever the current authenticated user is an employee.

This batch write operation is owner-only and should never be attempted by employee accounts.

---

### 3. Restrict `SubscriptionProvider`

#### Objective

Avoid unnecessary permission errors when loading subscription requests.

Implementation requirements:

Either:

- Prevent `_fetchLatestRequest()` from executing for employees,

or

- Silently intercept `permission-denied` exceptions.

The implementation must ensure these expected authorization failures are **not reported** to Crashlytics as application errors.

---

# 🗺️ Phase 3 — Data Resilience & Legacy Data Support

## Phase Context

Some existing wallet documents were created before mandatory timestamp fields were introduced.

Currently:

`WalletModel.fromMap()` throws `NotFoundException` whenever fields such as:

- `createdAt`
- `lastDailyReset`
- or similar timestamps

are missing.

As a result, legacy wallets disappear from the UI despite being valid business data.

The deserialization process must become resilient to legacy documents.

---

## Required Tasks

### Update `WalletModel.fromMap()`

#### Objective

Support legacy wallet documents through safe deserialization.

Implementation requirements:

- Remove hard failures caused by missing timestamp fields.
- Extract timestamp values safely.
- Use conditional parsing.
- When values are missing, substitute safe fallback values such as:

```dart
DateTime.now()
```

(or another appropriate default timestamp)

The deserialization process should always succeed for legacy wallet documents unless the document itself is fundamentally invalid.

---

# 🗺️ Phase 4 — UI/UX Polish

## Phase Context

Several UI issues negatively impact the employee experience.

These include:

- RenderFlex overflow caused by long Arabic text inside wallet cards.
- Repeated validation exceptions generated while entering transaction amounts.

Both issues should be corrected without changing business behavior.

---

## Required Tasks

### 1. Fix WalletCard Layout Overflow

#### Objective

Prevent layout overflow inside the wallet balance section.

Implementation requirements:

Inside `wallet_card.dart`:

- Wrap the inner `Row` containing the wallet icon and the "Current Balance" label with `Expanded`.
- Wrap the text widget with `Flexible`.
- Configure:

```dart
overflow: TextOverflow.ellipsis
```

This ensures long Arabic labels remain within screen bounds without generating `RenderFlex Overflow` exceptions.

---

### 2. Guard Transaction Fee Calculation

#### Objective

Prevent unnecessary validation errors while the amount field is empty.

Implementation requirements:

Inside `CreateTransactionScreen` → `_updateTotal()`:

Add an early return before invoking `TransactionFeeCalculator`.

If the entered amount is:

```text
<= 0
```

the method should exit immediately without calling the validator.

This prevents repeated `DomainException` logs when users are still typing or when the field is empty.

---

# ✅ Expected Outcome

After completing all phases, the application should:

- Correctly synchronize Firebase Authentication with Firestore employee records.
- Preserve authenticated sessions despite authorization failures.
- Apply graceful permission denial instead of forced logout.
- Prevent unauthorized eager initialization requests.
- Support legacy wallet documents without deserialization failures.
- Eliminate unnecessary permission noise and Crashlytics pollution.
- Resolve wallet card layout overflow.
- Prevent validation spam during transaction creation.
- Deliver a stable, permission-aware employee experience that matches the owner's UX while fully respecting RBAC constraints.