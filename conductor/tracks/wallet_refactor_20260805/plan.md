# Implementation Plan: Backward Compatibility Migration & Fix Destructive Limit Reset Bug

## Phase 1: Safe Legacy Deserialization — `WalletModel.fromMap` [checkpoint: a9ff695]

- [x] Task: Write Failing Tests — Legacy Document Deserialization c96880c
    - [x] In `test/data/models/wallet_model_test.dart`, add a test group `'Legacy document deserialization'`
    - [x] Test: `fromMap` with completely missing `walletStatus` → asserts result has `WalletStatus.inactive` (not `active`/`new`)
    - [x] Test: `fromMap` with missing `sendLimits` map but present legacy root-level fields (`dailyLimit`, `monthlyLimit`) → asserts `WalletLimits` reconstructed from root fields with `0.0` usage
    - [x] Test: `fromMap` with missing `sendLimits` AND missing root-level fields → asserts fallback to `PlatformSettingsModel.networkOldLimits` defaults
    - [x] Test: `fromMap` with missing `receiveLimits` map → same fallback logic as sendLimits
    - [x] Test: `fromMap` with missing `lastDailyReset` and `lastMonthlyReset` → asserts timestamps are `null` (NOT `DateTime.now()`)
    - [x] Test: `fromMap` with complete new-format document (all fields present) → asserts zero-regression, all fields match input
    - [x] Run tests and confirm all new tests **FAIL** (Red Phase)

- [x] Task: Implement Legacy Fallbacks in `WalletModel.fromMap` e3a1164
    - [x] In `lib/data/models/wallet_model.dart`, update line ~244-245: change `walletStatus` default from `'active'` to `'inactive'` (or the string value corresponding to `WalletStatus.inactive`/`old`)
    - [x] Remove `DomainException` throw at lines ~226-229 for missing `sendLimits`; replace with fallback: read legacy root fields `data['dailyLimit']`/`data['monthlyLimit']`, else resolve from `PlatformSettingsModel.networkOldLimits`
    - [x] Remove `DomainException` throw at lines ~233-236 for missing `receiveLimits`; same fallback logic
    - [x] Verify `lastDailyReset` and `lastMonthlyReset` parse safely as `null` when missing (current code at lines ~215-218 already does this — confirm no regression)
    - [x] Ensure NO hardcoded limit values (60000/200000) in `fromMap`; all fallbacks route through `PlatformSettingsModel.networkOldLimits`
    - [x] Run tests and confirm all tests **PASS** (Green Phase)

- [x] Task: Refactor & Polish `fromMap` Implementation f16be0a
    - [x] Extract the legacy fallback logic into a private helper method (e.g., `_buildLegacyLimits`) for readability
    - [x] Add inline documentation explaining the lazy migration strategy
    - [x] Run full model test suite to confirm no regressions

- [x] Task: Conductor - User Manual Verification 'Phase 1: Safe Legacy Deserialization' (Protocol in workflow.md) a9ff695

## Phase 2: Audit & Secure Repository Write Methods [checkpoint: 1a669b2]

- [x] Task: Write Failing Tests — `resetLimitsForWallets` Payload Verification 2c80454
    - [x] In `test/data/repositories/wallet_repository_test.dart` (or a new file `wallet_repository_reset_test.dart`), add test group `'resetLimitsForWallets payload safety'`
    - [x] Test: daily reset payload contains ONLY `sendLimits.dailyUsed`, `receiveLimits.dailyUsed`, `lastDailyReset` — asserts NO `dailyLimit`, `monthlyLimit`, `walletStatus`, or root-level limit fields
    - [x] Test: monthly reset payload contains ONLY `sendLimits.monthlyUsed`, `receiveLimits.monthlyUsed`, `lastMonthlyReset` — same safety assertions
    - [x] Test: combined daily+monthly reset payload — assert union of both is still pinpoint-only
    - [x] Run tests and confirm they **FAIL** or **PASS** (they may already pass since the method appears compliant — this is acceptable for audit-type tasks)

- [x] Task: Audit All `WalletRepository` Write Methods 24ddf11
    - [x] Review `createWallet` (line ~44 uses `toFirestore()` via `batch.set`) — this is correct for document creation, document finding
    - [x] Review `updateWallet` (line ~207 takes `Map<String, dynamic>`) — confirm callers pass pinpoint maps, not full `toMap()`/`toFirestore()` output
    - [x] Search for any other `.set()`, `.update()` calls in the file and verify their payloads
    - [x] Document audit findings as inline comments or in the spec
    - [x] Fix any confirmed full-document overwrite problems (if found)
    - [x] Run repository test suite to confirm no regressions

- [x] Task: Conductor - User Manual Verification 'Phase 2: Audit & Secure Repository Write Methods' (Protocol in workflow.md) 1a669b2

## Phase 3: Integration Flow Verification [checkpoint: 900d42f]

- [x] Task: Write Integration-Level Test — Legacy Wallet Auto-Heal Cycle 3345194
    - [x] Create `test/data/repositories/wallet_legacy_migration_test.dart` (or add to existing)
    - [x] Test: Simulate end-to-end flow: create a legacy Firestore document (no `walletStatus`, no `sendLimits`/`receiveLimits`, no timestamps) → load via `WalletModel.fromFirestore` → verify `WalletProvider.needsDailyReset` evaluates `true` → call `resetLimitsForWallets` → read document back → assert timestamps now exist AND limit caps are untouched
    - [x] Test: Same flow with a new-format document → verify zero mutations occur beyond normal reset
    - [x] Run all tests and confirm full suite passes

- [x] Task: Run Static Analysis & Coverage 3345194
    - [x] Run `flutter analyze` and fix any warnings/errors
    - [x] Run `CI=true flutter test` and verify >80% coverage on modified files
    - [x] Run `dart format .` to ensure consistent formatting

- [x] Task: Conductor - User Manual Verification 'Phase 3: Integration Flow Verification' (Protocol in workflow.md) 900d42f
