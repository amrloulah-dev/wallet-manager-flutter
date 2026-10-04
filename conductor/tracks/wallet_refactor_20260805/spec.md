# Specification: Backward Compatibility Migration & Fix Destructive Limit Reset Bug

## Overview

A critical **Destructive Read Mutation** bug exists in production affecting legacy Firestore wallet documents. Legacy documents lack the `walletStatus` field and the nested `sendLimits` / `receiveLimits` maps introduced in the schema modernization. When `WalletModel.fromMap` parses these old documents it:

1. **Throws `DomainException`** because `sendLimits` and `receiveLimits` maps are null/missing.
2. **Defaults `walletStatus` to `'active'`** instead of recognizing the wallet as a legacy (`'old'`/`'inactive'`) wallet, which misassigns limit caps.
3. **Leaves `lastDailyReset` and `lastMonthlyReset` as `null`**, which under the old (potentially destructive) reset path could have written corrupted data. With the secured pinpoint reset (FR-2.1), these null timestamps now **intentionally trigger a safe auto-migration** via `FieldValue.serverTimestamp()`.

This track fixes the deserialization layer to safely handle legacy documents via on-read (lazy) migration and audits all `WalletRepository` write methods to confirm no full-document overwrites exist.

## Functional Requirements

### FR-1: Safe Legacy Deserialization — `WalletModel.fromMap`
**File:** `lib/data/models/wallet_model.dart`

| # | Requirement | Details |
|---|---|---|
| FR-1.1 | **`walletStatus` fallback** | If `data['walletStatus']` is null or missing, default to `WalletStatus.inactive` (or `'old'`) — **never** `'active'` or `'new'`. |
| FR-1.2 | **`sendLimits` fallback** | Remove the `DomainException` throw for missing `sendLimits`. Instead, reconstruct a `WalletLimits` object by reading legacy root-level fields (`data['dailyLimit']`, `data['monthlyLimit']`). If those are also missing, fall back to the dynamically resolved limits from `PlatformSettingsModel.networkOldLimits` (Daily: 60,000 / Monthly: 200,000 defaults) with `0.0` usage. |
| FR-1.3 | **`receiveLimits` fallback** | Same fallback logic as FR-1.2 for `receiveLimits`. |
| FR-1.4 | **Timestamp handling — Null preservation (Auto-Heal)** | Missing `lastDailyReset` and `lastMonthlyReset` MUST parse safely as `null`. Do **NOT** fallback to `DateTime.now()`. This intentionally allows `WalletProvider.needsDailyReset` to evaluate to `true`, which leverages the secured dot-notation payload in `resetLimitsForWallets` (FR-2.1) to perform a **silent auto-migration**, permanently fixing the missing timestamps in Firestore via `FieldValue.serverTimestamp()`. |
| FR-1.5 | **Dynamic limit resolution** | Legacy/old wallet limits MUST be resolved via `PlatformSettingsModel.networkOldLimits` — NOT hardcoded values. This keeps limits remotely configurable through the Admin Panel. |

### FR-2: Audit & Secure Repository Write Methods
**File:** `lib/data/repositories/wallet_repository.dart`

| # | Requirement | Details |
|---|---|---|
| FR-2.1 | **Verify `resetLimitsForWallets`** | Confirm it uses dot-notation pinpoint updates ONLY (e.g., `sendLimits.dailyUsed`) and does NOT touch `dailyLimit`, `monthlyLimit`, or `walletStatus` fields. *(Current code appears compliant — verify and document.)* |
| FR-2.2 | **Audit all other write methods** | Review `updateWallet`, `createWallet`, and any other Firestore write methods. Confirm none use `wallet.toMap()` or `wallet.toFirestore()` for partial updates. Document findings and fix confirmed problems only. |

## Non-Functional Requirements

| # | Requirement |
|---|---|
| NFR-1 | **Zero UI changes** — All changes are Data Layer and Persistence Layer only. |
| NFR-2 | **Zero breaking changes for new wallets** — New-format documents must deserialize identically before and after this fix. |
| NFR-3 | **Strict null-safety** — No exceptions thrown for missing legacy fields. |
| NFR-4 | **On-read (lazy) migration only** — No batch migration scripts; documents self-heal when loaded. |

## Acceptance Criteria

1. ✅ `WalletModel.fromMap` successfully parses a legacy document (no `walletStatus`, no `sendLimits`/`receiveLimits`, no timestamps) without throwing exceptions. Timestamps remain `null` to trigger the auto-heal flow.
2. ✅ Legacy wallets receive `WalletStatus.inactive` (or `old`), with limits resolved from `PlatformSettingsModel.networkOldLimits`.
3. ✅ New-format documents deserialize identically — zero regressions.
4. ✅ `resetLimitsForWallets` does NOT overwrite limit caps or wallet status (dot-notation only).
5. ✅ All repository write methods audited; any full-document overwrites fixed.
6. ✅ Unit tests: legacy `fromMap` (with null timestamps), new-format `fromMap`, `resetLimitsForWallets` payload verification.
7. ✅ Integration-level test: legacy wallet load → provider → reset cycle does not corrupt data and auto-heals timestamps.
8. ✅ >80% code coverage on modified files.

## Out of Scope

- UI changes or migration banners.
- Batch/offline Firestore migration scripts.
- Changes to `WalletProvider` logic (beyond verifying it correctly triggers auto-heal resets).
- Adding new fields to Firestore schema.
