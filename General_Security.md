# 🚀 Wallet Manager - General Security & Data Protection Blueprint (Phase 11)

## 📌 1. General Context & Strict System Prompt
**To the AI Agent (Antigravity / Gemini CLI / Cursor):**
You are performing a targeted Security Remediation for "Wallet Manager". 
**CRITICAL CONTEXT:** This app is a digital ledger/tracker, NOT a banking application. We operate on Firebase free-tier services. Therefore, migrating authentication handling to Cloud Functions or over-engineering the identity generation is strictly OUT OF SCOPE. We accept "predictable identities" and "client-side auth sync" as an acceptable risk.

Your ONLY mandate is to execute the following pragmatic, high-impact security fixes to prevent local privilege escalation on rooted devices and defeat rainbow table attacks.

---

## 📌 2. Axis 1: Privilege Escalation Prevention (Secure Storage)

### Context
Storing core session identifiers in plain-text XML `SharedPreferences` allows trivial privilege escalation on rooted devices (e.g., an employee altering their role to 'owner'). However, `SharedPreferences` is heavily utilized to bridge data from background isolates (SMS parsing).

### The Fix
1. **Migrate Core Session Data:** Refactor `local_storage_service.dart`. You MUST migrate `userRole`, `storeId`, and `userId` from `SharedPreferences` to `flutter_secure_storage`.
2. **Implement Ephemeral Storage for SMS:** Keep the SMS queue (`_kPendingOverlayData`) and general non-security settings in `SharedPreferences` to maintain Isolate compatibility. However, implement a rigorous "Ephemeral Pattern": actively call `remove()` on the SMS data keys immediately after the Main UI thread consumes and parses them, minimizing their lifespan on disk.

---

## 📌 3. Axis 2: Cryptographic Upgrade (Password Hasher)

### Context
Employee 4-digit PINs are currently hashed using unsalted SHA-256. This keyspace (0000-9999) can be cracked instantly by anyone with database access using rainbow tables. There is also a hardcoded pepper in the storage service.

### The Fix
1. **Refactor `password_hasher.dart`:** Completely gut the unsalted SHA-256 logic.
2. **Implement Strong Key Stretching:** Use a modern cryptographic package (e.g., `cryptography` or `pointycastle`) to implement **PBKDF2** or **Argon2** for hashing the PINs.
3. **Generate and Store Salt:** The hashing mechanism MUST include a unique, randomly generated cryptographic `salt` for each user/PIN. The salt must be stored alongside the hash in the database to verify the PIN later.
4. **Remove Hardcoded Secrets:** Delete the hardcoded pepper string (`wallet_manager_sub_integrity_2025`) from `local_storage_service.dart`.

---

## 📌 4. Axis 3: PII & Exception Sanitization

### Context
Global error handlers and verbose debug logs are leaking financial amounts, phone numbers, and PINs to the console, Crashlytics, and user-facing Toasts.

### The Fix
1. **Sanitize `AppErrorHandler`:** Refactor the global error handler. Ensure that raw exception objects (`error.toString()`) which may contain sensitive database payloads are NOT blindly passed to `Crashlytics` or `BotToast`. Map them to generic, safe error codes or messages for external logging/UI.
2. **Clean `debugPrint` Statements:** Review `transaction_repository.dart` and `overlay_provider.dart`. Strip out sensitive fields (phone numbers, exact wallet balances, raw transaction amounts) from `debugPrint` calls. Replace them with structural logs (e.g., "Transaction completed successfully for Wallet ID: X").

---

## 📌 Acceptance Criteria
- [ ] `flutter_secure_storage` is integrated and actively used for `userRole`, `storeId`, and `userId`.
- [ ] `SharedPreferences` actively deletes SMS data immediately after UI ingestion.
- [ ] Employee PINs are hashed using PBKDF2/Argon2 WITH a unique Salt. Plain SHA-256 is entirely removed.
- [ ] The hardcoded pepper string is deleted from the source code.
- [ ] `AppErrorHandler` strips sensitive payload data before logging to Crashlytics or showing Toasts.
- [ ] `debugPrint` statements in overlay and transaction layers do not echo raw PII or financial amounts.
- [ ] NO modifications are made regarding Cloud Functions or Identity Generation logic.