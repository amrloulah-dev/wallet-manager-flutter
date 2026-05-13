# 🕵️‍♂️ Phase 11: General Security & Data Protection Audit Report

## 🔴 CRITICAL (Blockers / Hardcoded Secrets / Insecure Storage)

| File Path | Line(s) | Exact Code Snippet | Why It's a Severe Problem |
| :--- | :--- | :--- | :--- |
| `lib/core/utils/password_hasher.dart` | 18 | `final digest = sha256.convert(bytes);` | **Weak Hashing:** Uses SHA-256 without a cryptographic salt. Hashed passwords/PINs are vulnerable to rainbow table attacks and rapid brute-forcing. |
| `lib/data/services/local_storage_service.dart` | 233 | `const pepper = 'wallet_manager_sub_integrity_2025';` | **Hardcoded Pepper:** A static string used as a key for HMAC integrity checks. If the binary is decompiled, an attacker can forge subscription integrity tokens. |
| `lib/data/services/local_storage_service.dart` | 97 | `await _prefs!.setString(_keyUserId, userId);` | **Insecure Storage:** Stores `userId` in plain-text `SharedPreferences`. Readable by any other app on a rooted device. |
| `lib/data/services/local_storage_service.dart` | 98 | `await _prefs!.setString(_keyStoreId, storeId);` | **Insecure Storage:** Stores `storeId` in plain-text `SharedPreferences`. Readable by any other app on a rooted device. |
| `lib/data/services/local_storage_service.dart` | 99 | `await _prefs!.setString(_keyUserRole, userRole.name);` | **Insecure Storage:** Stores `userRole` in plain-text `SharedPreferences`. Readable by any other app on a rooted device. |
| `lib/data/services/local_storage_service.dart` | 100 | `await _prefs!.setString(_keyUserName, userName);` | **Insecure Storage (PII):** Stores `userName` in plain-text `SharedPreferences`. Readable by any other app on a rooted device. |
| `lib/data/services/local_storage_service.dart` | 101 | `await _prefs!.setString(_keyStoreName, storeName);` | **Insecure Storage:** Stores `storeName` in plain-text `SharedPreferences`. Readable by any other app on a rooted device. |
| `lib/data/services/local_storage_service.dart` | 304 | `await _prefs!.setString(_kWalletLiteCache, jsonString);` | **Insecure Storage (Financial PII):** Stores wallet phone numbers (`phone` field) in plain-text `SharedPreferences`. |
| `lib/data/services/local_storage_service.dart` | 352 | `await _prefs!.setString(_kPendingOverlayData, json.encode(data));` | **Insecure Storage (SMS Vault):** Stores raw transaction data including `amount` and `sender` (phone number) in plain-text `SharedPreferences`. |
| `lib/data/services/local_storage_service.dart` | 371 | `await _prefs!.setString(_kPersistentDeviceId, deviceId);` | **Insecure Storage (Tracking PII):** Stores unique device identifier in plain-text `SharedPreferences`. |

---

## 🟠 MEDIUM (Tech Debt / Data Leakage)

| File Path | Line(s) | Exact Code Snippet | Recommended Pattern |
| :--- | :--- | :--- | :--- |
| `lib/presentation/overlays/overlay_provider.dart` | 108 | `debugPrint('🔥 [TX_FLOW] [overlay_provider] -> ingestNewEvent: raw data=$data ...');` | **PII Leakage:** Logs the entire `data` map which contains the `sender` (phone number) from SMS. |
| `lib/presentation/overlays/overlay_provider.dart` | 152 | `debugPrint('🔥 [TX_FLOW] [overlay_provider] -> ingestNewEvent: auto-selected walletId=$passedId, ...');` | **Sensitive Data Leakage:** Logs internal `walletId` and calculated commissions to the console. |
| `lib/presentation/overlays/overlay_provider.dart` | 261 | `debugPrint('🔥 [TX_FLOW] [overlay_provider] -> submitTransaction: shareData(local_deduct) → walletId=$_selectedWalletId, deduction=${result.totalDeduction}, ...');` | **Financial Data Leakage:** Logs financial transaction amounts and internal identifiers to the console. |
| `lib/data/repositories/transaction_repository.dart` | 73 | `debugPrint('🔥 [TX_FLOW] [transaction_repository] -> createTransaction: RECEIVED \| txId=${transaction.transactionId}, ...');` | **Sensitive Data Leakage:** Logs `transactionId`, `walletId`, and financial `amount` to the console. |
| `lib/providers/auth_provider.dart` | 428 | `debugPrint('💥 [AUTH ERROR] $errorCode \| Error: $error');` | **PII Leakage in Errors:** Logs raw error objects which may echo back email addresses or credentials on failure. |
| `lib/core/errors/app_error_handler.dart` | 185 | `debugPrint('❌ [FATAL ERROR] $operation: $error');` | **Sensitive Data Leakage:** Logs unsanitized error messages that might contain user-supplied PII or secrets. |
| `lib/core/errors/app_error_handler.dart` | 218 | `debugPrint('⚠️ [SILENT ERROR] $operation: $error');` | **Sensitive Data Leakage:** Logs unsanitized error messages to the console. |
| `lib/core/errors/app_error_handler.dart` | 234 | `debugPrint('🔍 [STACK TRACE]: $stack');` | **Internal Logic Exposure:** Logs full stack traces to the console, which can expose internal file structures. |
| `lib/core/services/identity_service.dart` | 36 | `return 'emp_${phone}_$storeId@store.com';` | **Predictable Accounts:** Generates employee emails using a predictable pattern. If `storeId` and `phone` are known, an attacker can target these accounts. |
| `lib/data/models/debt_model.dart` | 176 | `'DebtModel(id: $debtId, customer: $customerName, ...)'` | **PII Leakage via toString():** Includes `customerName` in the string representation, which is leaked if the model is logged. |
| `lib/core/services/sms_processing_pipeline.dart` | 229 | `debugPrint("🧠 SMART FALLBACK: OS hid SIM info, but unique wallet found -> $matchedWalletId");` | **Sensitive Data Leakage:** Logs internal `walletId` and logic flow details. |

---

## 🟢 QUICK WINS (Low Hanging Fruit)

| File Path | Line(s) | Exact Code Snippet |
| :--- | :--- | :--- |
| `lib/main.dart` | 25 | `debugPrint('🚀 [APP START] WidgetsFlutterBinding initialized.');` |
| `lib/main.dart` | 32 | `debugPrint('⏳ [INIT DATA] Initializing Firebase...');` |
| `lib/main.dart` | 34 | `debugPrint('✅ [INIT SUCCESS] Firebase initialized.');` |
| `lib/app.dart` | 95 | `debugPrint('🛠️ [APP_DEBUG] Building MyApp shell...');` |
| `lib/core/services/sms_service.dart` | 97 | `if (kDebugMode) debugPrint('Error requesting additional permissions: $e');` |
| `lib/data/models/store_model.dart` | 102 | `debugPrint('⚠️ [MIGRATION] Subscription data is missing or incomplete for store: $docId');` |
| `lib/services/time_service.dart` | 16 | `debugPrint('🔴 [TIME_SERVICE] CRITICAL: NTP sync failed - $e\n$stack');` |

---

## 📊 Final Summary

- 🔴 CRITICAL: **10 findings**
- 🟠 MEDIUM: **11 findings**
- 🟢 QUICK WINS: **7 findings**

Report 11 (General Security) Generation Complete. Awaiting the next audit directive.
