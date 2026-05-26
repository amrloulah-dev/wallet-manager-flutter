# Plan: Fix Firestore Security Rules — `read` → `get`/`list` Split

## Phase 1: Implement Rule Splits

- [ ] Task: Split `allow read` into `get`/`list` for `wallets/{walletId}` (Line 110)
    - [ ] Change `allow read: if canAccessStore(resource.data.storeId);` to `allow get: if canAccessStore(resource.data.storeId);` + `allow list: if isAuthenticated();`
    - [ ] Verify no syntax errors in the modified rule block

- [ ] Task: Split `allow read` into `get`/`list` for `transactions/{transactionId}` (Line 121)
    - [ ] Change `allow read: if canAccessStore(resource.data.storeId);` to `allow get: if canAccessStore(resource.data.storeId);` + `allow list: if isAuthenticated();`
    - [ ] Verify no syntax errors in the modified rule block

- [ ] Task: Split `allow read` into `get`/`list` for `debts/{debtId}` (Line 131)
    - [ ] Change `allow read: if canAccessStore(resource.data.storeId);` to `allow get: if canAccessStore(resource.data.storeId);` + `allow list: if isAuthenticated();`
    - [ ] Verify no syntax errors in the modified rule block

- [ ] Task: Split `allow read, delete` into `get, delete`/`list` for `users/{userId}` (Line 73)
    - [ ] Change `allow read, delete:` to `allow get, delete:` (same condition)
    - [ ] Add new `allow list: if isAuthenticated();`

- [ ] Task: Split `allow read, delete` into `get, delete`/`list` for `subscription_requests/{requestId}` (Lines 143-144)
    - [ ] Change `allow read, delete:` to `allow get, delete:` (same condition)
    - [ ] Add new `allow list: if isAuthenticated();`

## Phase 2: Validate and Deploy

- [ ] Task: Validate rules syntax
    - [ ] Run Firebase MCP `firebase_validate_security_rules` tool against the modified `firestore.rules`
    - [ ] Fix any validation errors

- [ ] Task: Cross-reference unchanged rules
    - [ ] Verify `create`, `update`, `delete` rules for all 5 collections remain unmodified
    - [ ] Verify helper functions (`isStoreOwner`, `isStoreEmployee`, `canAccessStore`, `hasPermission`) are untouched
    - [ ] Verify safe collections (`stores`, `daily_stats`, `pin_locks`, `device_registrations`, `license_keys`) are untouched

- [ ] Task: Conductor - User Manual Verification 'Phase 2: Validate and Deploy' (Protocol in workflow.md)
