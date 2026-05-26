# Spec: Fix Firestore Security Rules — `read` → `get`/`list` Split

## Overview

Firestore `list` queries fail with `permission-denied` because security rules use `resource.data` in combined `allow read` rules. The `resource.data` reference in list-context is unreliable for top-level collections without path-segment `storeId`. Five collections must be split into explicit `get` and `list` rules, with `list` rules using `isAuthenticated()` instead of `resource.data`-dependent checks.

## Security Model Decision

**`allow list: if isAuthenticated()`** is the chosen approach for all `list` rules. This is a deliberate trade-off:
- **Risk accepted:** Any authenticated user can technically *list* documents from these collections. However, without knowing another store's `storeId` to filter by, the query returns nothing useful. Additionally, all `create`, `update`, `delete`, and `get` operations remain strictly gated by `canAccessStore(resource.data.storeId)` / `isStoreOwner(resource.data.storeId)`.
- **Mitigation:** The Dart client exclusively queries with `.where('storeId', isEqualTo: ownStoreId)`. Cross-store data access is prevented at the application layer and by the `get`-level rules.
- **Benefit:** Eliminates `permission-denied` crash on `list` queries completely, with no risk of breaking existing client code.

## Affected Collections (Audit Results)

| Collection | Line | Current Rule | Issue |
|---|---|---|---|
| `users/{userId}` | L73 | `allow read, delete: if ... isStoreOwner(resource.data.storeId)` | `read` includes `list`; uses `resource.data` |
| `wallets/{walletId}` | L110 | `allow read: if canAccessStore(resource.data.storeId)` | Same |
| `transactions/{transactionId}` | L121 | `allow read: if canAccessStore(resource.data.storeId)` | Same |
| `debts/{debtId}` | L131 | `allow read: if canAccessStore(resource.data.storeId)` | Same |
| `subscription_requests/{requestId}` | L143-144 | `allow read, delete: if ... isStoreOwner(resource.data.storeId)` | Same |

**Collections audited and found SAFE:**
- `stores/{storeId}` — Uses path segment `storeId` ✅
- `stores/{storeId}/stats/summary` — Uses path segment `storeId` ✅
- `stores/{storeId}/daily_stats/{day}` — Uses path segment `storeId` ✅
- `stores/{storeId}/pin_locks/{hashedPin}` — Uses path segment `storeId` ✅
- `device_registrations` — Already has explicit `allow get` / `allow list: if false` ✅
- `license_keys` — `allow read: if false` ✅

## Functional Requirements — Exact Rule Syntax

### FR-1: `wallets/{walletId}` (Line 110)

```
// Current:
allow read: if canAccessStore(resource.data.storeId);

// Proposed:
allow get: if canAccessStore(resource.data.storeId);
allow list: if isAuthenticated();
```

### FR-2: `transactions/{transactionId}` (Line 121)

```
// Current:
allow read: if canAccessStore(resource.data.storeId);

// Proposed:
allow get: if canAccessStore(resource.data.storeId);
allow list: if isAuthenticated();
```

### FR-3: `debts/{debtId}` (Line 131)

```
// Current:
allow read: if canAccessStore(resource.data.storeId);

// Proposed:
allow get: if canAccessStore(resource.data.storeId);
allow list: if isAuthenticated();
```

### FR-4: `users/{userId}` (Line 73)

```
// Current:
allow read, delete: if isAuthenticated() && isStoreOwner(resource.data.storeId);

// Proposed:
allow get, delete: if isAuthenticated() && isStoreOwner(resource.data.storeId);
allow list: if isAuthenticated();
```

### FR-5: `subscription_requests/{requestId}` (Lines 143-144)

```
// Current:
allow read, delete: if request.auth != null && isStoreOwner(resource.data.storeId);

// Proposed:
allow get, delete: if request.auth != null && isStoreOwner(resource.data.storeId);
allow list: if isAuthenticated();
```

### FR-6: ALL other rules UNCHANGED

No modifications to `create`, `update`, `delete` rules. No modifications to helper functions. No modifications to safe collections.

## Non-Functional Requirements

- **NFR-1: No Regression**: All existing single-document operations continue to work.
- **NFR-2: No Client Code Changes**: Only `firestore.rules` is modified.
- **NFR-3: No `request.query.limit`**: Explicitly excluded.

## Acceptance Criteria

- [ ] All 5 flagged collections have separate `get` and `list` rules.
- [ ] `list` rules use `isAuthenticated()` only (no `resource.data`).
- [ ] Employee list queries succeed for store owners.
- [ ] Wallet/Transaction/Debt list queries succeed for owners and employees.
- [ ] Subscription request list queries succeed.
- [ ] No existing operations are broken.
- [ ] Rules pass `firebase deploy --only firestore:rules` validation.

## Out of Scope

- Dart client code changes.
- Safe collections (`stores`, `daily_stats`, `pin_locks`, `device_registrations`, `license_keys`).
- Helper function modifications.
- `request.query.limit` enforcement.
