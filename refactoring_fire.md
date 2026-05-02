# 🛠️ Wallet Manager - Firebase & Firestore Refactoring Blueprint (Phase 4.2: Surgical Strikes)

## 📌 1. General Context & Strict System Prompt
**To the AI Agent (Antigravity / Gemini CLI):**
You are working on "Wallet Manager", a Flutter-based financial operations app. 
**Core Constraints:**
1. **$0 Budget (Spark Plan):** No Cloud Functions.
2. **NO GLOBAL SEARCHES:** Do not attempt a "global audit". You failed to apply fixes globally in the previous run. In this phase, you MUST strictly execute the exact fixes listed below in the explicitly specified files and methods. 
3. **DO NOT SKIP** any item on this list.

Your task is to fix specific atomicity leaks (forcing `FieldValue.increment`), close a security loophole in device tracking, and clean up specified technical debt.

---

## 📌 2. CRITICAL: Force Atomicity & FieldValue.increment
The following files still use Dart-side math (read-modify-write) inside or outside transactions. You must replace them with `FieldValue.increment()`.

### 2.1. `lib/data/services/transaction_validator_service.dart`
* **Target:** Line ~169 (or where balance is updated).
* **Current Anti-pattern:** `walletUpdateData['balance'] = validationWallet.balance + balanceChange;`
* **The Fix:** Keep the read for validation, but change the write operation to let Firestore handle the math: 
  `walletUpdateData['balance'] = FieldValue.increment(balanceChange);`

### 2.2. `lib/data/repositories/debt_repository.dart`
* **Target 1:** Inside `deleteDebt()` and `processPayment()` (Lines ~428, ~195).
* **Current Anti-pattern:** `updates['openDebtsCount'] = currentOpenDebts > 0 ? currentOpenDebts - 1 : 0;` (Dart-side subtraction).
* **The Fix:** Replace with `FieldValue.increment(-1)`. (Note: Our UI validation prevents deleting non-existent debts, so negative numbers are practically impossible. Prioritize atomicity).

### 2.3. `lib/data/repositories/employee_repository.dart`
* **Target:** Inside employee deactivation/stats updates (Lines ~209, ~226).
* **Current Anti-pattern:** Dart-side subtraction for `stats.totalEmployees` and `SummaryEmployees`.
* **The Fix:** Replace with `FieldValue.increment(-1)`.

### 2.4. `lib/data/repositories/user_repository.dart`
* **Target:** Lines ~329-354 (Stats update).
* **Current Anti-pattern:** `final user = await getUserById(userId);` followed by an un-transactional `update(statsData)`.
* **The Fix:** Remove the unnecessary `.get()`. Use a direct atomic update using `FieldValue.increment()` for the specific stat fields that changed.

---

## 📌 3. HIGH: Security Loophole (Device UUID Fallback)

### 3.1. `lib/data/repositories/device_repository.dart`
* **Target:** `getDeviceId()` method.
* **Current Anti-pattern:** If platform is unsupported or `deviceInfoPlugin` fails, it returns `const Uuid().v4()`. This generates a new ID every launch, allowing users to bypass the 2-trial limit infinitely.
* **The Fix:** 1. Attempt to read a previously saved UUID from local storage (using `SharedPreferences` via `LocalStorageService` or similar existing local vault).
  2. If found, return it.
  3. If NOT found (and device info fails), generate a new `Uuid().v4()`, **save it immediately** to local storage, and then return it.

---

## 📌 4. MEDIUM: Tech Debt & Architectural Optimization

### 4.1. `lib/data/repositories/license_key_repository.dart`
* **Target:** `activateLicenseKey()` method.
* **Current Anti-pattern:** Expiry calculation uses `now.add(Duration(days: expiryMonths * 30))`. This shortchanges users on a yearly sub by 5 days.
* **The Fix:** Use precise Dart DateTime math: `DateTime(now.year, now.month + expiryMonths, now.day, now.hour, now.minute)`.

### 4.2. `lib/data/repositories/debt_repository.dart`
* **Target:** `createDebt()` method.
* **Current Anti-pattern:** Uses `_firestore.runTransaction` but only performs `set()` writes (no reads). This adds unnecessary locking overhead.
* **The Fix:** Refactor this specific method to use `_firestore.batch()` (a WriteBatch) instead of `runTransaction`.

### 4.3. `lib/data/repositories/wallet_repository.dart`
* **Target:** `updateWalletBalance()` method.
* **Current Anti-pattern:** Method is marked `@Deprecated` but still exists.
* **The Fix:** Delete the method entirely. Verify no UI/Provider layers are calling it (if they are, migrate them to `creditWallet`/`debitWallet`).

---

## 📌 5. Non-Functional Requirements & Testing
1. **Testing:** Follow Strict TDD. Use the existing `fake_cloud_firestore` package to write failing tests for these specific files before refactoring. Do NOT set up a local emulator.
2. **Rollback:** Ensure these changes are in a separate commit/branch for an easy Git Revert if necessary.