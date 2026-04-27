# 🕵️‍♂️ Phase 3: Exhaustive Business Logic & Domain Integrity Audit

## 🔴 CRITICAL (Blockers / Financial Risks / Data Corruption)
*Definition: Missing math validation (negative money), unsafe null-bangs (!) in parsers that will crash the app, or swallowed critical exceptions.*

| File Path | Line(s) | The Exact Issue / Code Snippet | Why it's a severe problem |
| :--- | :--- | :--- | :--- |
| `lib/providers/transaction_provider.dart` | 275-294 | `final newTransaction = TransactionModel(...)` created without pre-validation of parameters. | If the UI passes a negative `amount` or `commission`, it is instantiated and sent to the repository without immediate validation, relying on downstream checks. |
| `lib/data/repositories/transaction_repository.dart` | 61 | `AmountValidator.ensurePositive(transaction.amount);` | Only validates `amount`. `commission` and `serviceFee` are NOT validated here, potentially allowing negative values to reach `TransactionValidatorService`. |
| `lib/data/services/transaction_validator_service.dart` | 33-35 | `balanceChange = transaction.isSend ? -(amount + serviceFee) : (amount + commission);` | **Logic Error:** For `isReceive`, it adds `commission` to the balance. Usually, commission is a fee taken *from* the customer (cash), not added to the electronic wallet balance. This could lead to inflated wallet balances. |
| **Widespread** | ~94 hits | Usage of `DateTime.now()` instead of `TimeService.now()`. | Financial apps must use NTP-synced time. Relying on device time allows users to bypass subscription expiration or corrupt transaction history by changing their phone clock. |
| `lib/core/services/sms_processing_pipeline.dart` | 111 | `if (DateTime.now().isAfter(endDate)) return;` | Security Bypass: A user can extend their subscription manually by setting their device clock back, as it doesn't use the synced `TimeService`. |
| `lib/data/models/user_model.dart` | 76 | `throw Exception('User document does not exist!');` | Generic `Exception` used for a critical domain failure. Should use a specific `AppException` or `AuthException` to be caught correctly by providers. |

## 🟠 MEDIUM (Tech Debt / Fragile Logic)
*Definition: Mutable models, generic error handling, missing safe defaults in data mapping.*

| File Path | Line(s) | The Exact Issue / Code Snippet | Recommended Pattern |
| :--- | :--- | :--- | :--- |
| `lib/core/services/background_service.dart` | 110 | `// Swallow — background isolate must never crash` | Background isolate errors should be logged to a local "Emergency Log" or sent to Crashlytics on the next app boot. |
| `lib/core/services/sms_processing_pipeline.dart` | 134 | `slotStr = (message as dynamic).slot?.toString();` | Fragile dynamic access. If the `another_telephony` plugin changes its internal structure, this will fail. |
| `lib/data/models/store_model.dart` | 232 | `endDate: map['endDate'] != null ? (map['endDate'] as Timestamp).toDate() : null` | Unsafe casting. If `map['endDate']` is corrupted (e.g., int/String), the app will crash during deserialization. |
| `lib/providers/auth_provider.dart` | 227-229 | `setError(...); await logout(); return false;` | Generic boolean return on failure hides specific error details from the UI caller. Should return a `Result<T>` or rethrow. |
| `lib/services/time_service.dart` | 12-16 | `catch (e) { _offset = 0; _isSynced = false; }` | Silent failure of NTP sync. The app will proceed with incorrect time without notifying the system/user. |

## 🟢 QUICK WINS (Low Hanging Fruit)
*Definition: Unused parameters in logical functions, missing return type annotations, redundant logical checks.*

| File Path | Line(s) | The Exact Issue / Code Snippet | 
| :--- | :--- | :--- | 
| `lib/core/utils/fee_calculator.dart` | 20 | `identifyProvider` checks `phone.substring(0, 3)` without sanitization. | 
| `lib/data/models/user_permissions.dart` | 115-127 | Redundant `?? false` checks when keys are already checked for existence in `hasNewKeys` block. |
| `lib/core/utils/number_parser.dart` | 24 | `RegExp(r'[^0-9]')` in `toInt` strips negative signs. |
| `lib/domain/usecases/wallet_usecase.dart` | 44 | Redundant `DateTime.now()` fallback in `sort` when `createdAt` is expected to be present. |

Report 3 (Business Logic & Domain Integrity) Generation Complete. Awaiting the next audit directive.
