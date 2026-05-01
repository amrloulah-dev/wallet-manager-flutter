# WalletManager — Complete Engineering Audit Report (Part 2/2)

> Continuation from Part 1. Covers: Providers, Core Infrastructure, Presentation, Testing, Findings.

---

## 8. Providers / State Management (7 providers)

All extend `SafeChangeNotifier`. All use `safeNotify()` instead of raw `notifyListeners()`.

### 8.1 Provider Summary

| Provider | Lines | Key Patterns |
|---|---|---|
| `auth_provider.dart` | 389 | Session lifecycle, auto-login via `DatabaseSyncService.tryAutoLogin()`, role-based routing |
| `wallet_provider.dart` | 662 | **Optimistic UI** — mutates RAM map first, then writes Firestore. **Fetch Shield** (5s block after background injection). `Map<String, WalletModel>` for O(1) lookups. |
| `transaction_provider.dart` | 367 | Pagination, fetch shield, delegates to `TransactionValidatorService` |
| `subscription_provider.dart` | 221 | Expiration checks via `StoreSubscription.isExpiredAt()`, ProxyProvider dependent on Auth |
| `employee_provider.dart` | 364 | PIN auth, subscription-gated suspension, max-employee limit enforcement |
| `debt_provider.dart` | 414 | CRUD with optimistic UI, atomic stats updates via repository |
| `statistics_provider.dart` | 273 | Stream-driven aggregation from Firestore, fetch shielding |

### 8.2 Critical State Patterns

#### Optimistic UI (WalletProvider)
```
User taps "Send" →
  1. Capture previous balance (for rollback)
  2. Deduct amount from RAM map immediately
  3. safeNotify() → UI updates instantly
  4. Fire-and-forget Firestore write
  5. On failure → revert RAM to captured state → safeNotify() → show error
```

#### Fetch Shield
```
Background isolate injects state via SharedPreferences →
  Provider reads it → sets _blockAutoFetch = true →
  Blocks all auto-fetch for ~5 seconds →
  Prevents stale Firestore reads from overwriting fresh local state
```

#### Composite ValueKey
Mutable list items (e.g., WalletCard) use `ValueKey('${wallet.walletId}_${wallet.balance}')` to force Flutter to rebuild when balance changes.

### 8.3 OverlayProvider (`presentation/overlays/`, 268 lines)

Runs in the **overlay isolate** (separate from main app):
- `ingestNewEvent()`: Receives SMS data → resets state → loads wallets from vault → auto-selects wallet → calculates commission
- `submitTransaction()`: Delegates to `OverlayUseCase` → sends `update_ui` ping via `IsolateNameServer` → shares deduction data back → closes overlay
- **Guarded notify**: Uses `_guardedNotify()` which respects `_blockAutoFetch` flag to prevent janky rebuilds during batch mutations

---

## 9. Core Infrastructure

### 9.1 SMS Automation Pipeline

```
SMS arrives on device
        │
        ▼
┌──────────────────────┐
│  Telephony Plugin    │  (another_telephony)
│  BroadcastReceiver   │
└──────────┬───────────┘
           │
     ┌─────┴─────┐
     │           │
  Foreground  Background/Cold
  (SmsService)  (_backgroundSmsCallback)
     │           │
     └─────┬─────┘
           │
           ▼
┌──────────────────────────────────┐
│  sms_processing_pipeline.dart   │  (SHARED — single source of truth)
│  handleIncomingSms()            │
│                                  │
│  1. Guard: feature flag          │
│  2. Guard: subscription active   │
│  3. Guard: SMS enabled           │
│  4. Guard: not expired           │
│  5. Parse SMS body               │
│  6. Match SIM → Wallet           │
│  7. Save to vault                │
│  8. Wake screen (notification)   │
│  9. Show overlay window          │
│  10. Share data with overlay     │
└──────────────────────────────────┘
```

#### SMS Parser Engine (`sms_automation/sms_parser_engine.dart`, 76 lines)

Strategy pattern with pluggable parsers:
- `VodafoneCashStrategy` — parses Vodafone Cash SMS format
- `GenericBankStrategy` — fallback for other providers

Flow: `canParse(sender)` → `parse(body)` → returns `ParsedSmsDto` with amount, type, counterparty, service provider.

**Fallback behavior**: If no strategy matches the sender, ALL strategies are tried against the body (handles forwarded/unknown sender SMS).

#### SIM-to-Wallet Matching (in pipeline)

Three-tier matching with smart fallback:
1. **subscriptionId** match (standard Android)
2. **SIM slot index** match (alternative)
3. **Service provider** match (inferred from SMS content)
4. **Smart fallback**: If only 1 unique wallet mapped → auto-select (handles Huawei/Xiaomi OEM restrictions)

### 9.2 Background Service (`core/services/background_service.dart`, 113 lines)

**Guardian Isolate** — completely self-sufficient:
- Configured via `initializeBackgroundService()` called from `main()`
- Android: foreground service, auto-start, auto-start on boot
- Bootstraps its own `LocalStorageService` instance
- Listens for SMS via `Telephony.listenIncomingSms`
- Delegates to shared `handleIncomingSms()` pipeline
- `_backgroundSmsCallback`: Top-level function for cold-start SMS handling (app killed)

### 9.3 DatabaseSyncService (`core/services/`, 442 lines)

**The authentication orchestrator.** Handles all login/registration flows:

| Method | Flow |
|---|---|
| `tryAutoLogin()` | Reads saved session → validates against Firestore → returns `AuthSessionResult` |
| `loginOwnerWithEmail()` | Firebase Auth → `_finalizeOwnerLogin()` → session save |
| `loginWithGoogleOrNull()` | Google Sign-In → user lookup → session save |
| `loginAsEmployee()` | PIN verification → identity provisioning → session save |
| `registerStoreWithGoogle()` | Anti-fraud device check → create store + user → register device |
| `registerStoreWithEmail()` | Same as Google but with email/password creation |

**Anti-fraud flow during registration:**
```
1. Get device hardware ID
2. Check device_registrations (local) for trial eligibility
3. Check SubscriptionRepository.hasDeviceConsumedTrial() (Firestore)
4. If either fails → isEligibleForTrial = false
5. Create store with appropriate subscription tier
6. Register device usage post-creation
```

### 9.4 Error Handling System

#### Exception Hierarchy (`core/errors/app_exceptions.dart`, 144 lines)

```
AppException (base)
├── AuthException
│   ├── InvalidCredentialsException
│   ├── StoreInactiveException
│   ├── UserNotFoundException
│   ├── EmailAlreadyInUseException
│   ├── WeakPasswordException
│   └── WrongPasswordException
├── LicenseException
│   ├── InvalidLicenseException
│   ├── LicenseAlreadyUsedException
│   └── LicenseExpiredException
├── NetworkException
├── ServerException
├── ValidationException
├── NotFoundException
├── PermissionDeniedException
│   └── PermissionException
├── DeviceLimitExceededException
├── DomainException
│   └── InvalidAmountException
```

#### AppErrorHandler (`core/errors/app_error_handler.dart`, 127 lines)

- `init()`: Hooks into `FlutterError.onError` and `PlatformDispatcher.instance.onError`
- `handle()`: Severity-based routing — `critical`/`medium` → Crashlytics, all → Analytics, optional toast
- `logSilentError()`: Debug → console, Release → Crashlytics non-fatal
- **Test mode**: `isTestMode = true` disables all side effects
- **Isolate-safe**: No UI dependencies in core logging path

### 9.5 Core Utilities (16 files in `core/utils/`)

| Utility | Purpose |
|---|---|
| `number_parser.dart` | Safe numeric parsing: handles null, String, int, double. **Rejects negatives** (returns `0`). |
| `amount_validator.dart` | `ensurePositive()`, `ensurePositiveOrZero()` — throws `InvalidAmountException` on violation |
| `fee_calculator.dart` | Static fee calculation per wallet type and transaction amount |
| `password_hasher.dart` | SHA-256 hashing for store passwords and employee PINs |
| `date_helper.dart` | Date range builders, period comparison, Firestore timestamp helpers |
| `currency_formatter.dart` | EGP currency formatting with Arabic locale support |
| `cache_manager.dart` | Generic in-memory cache with TTL and wildcard clear |
| `validators.dart` | Form validation (email, phone, PIN, amounts) |
| `debouncer.dart` | Timer-based input debouncing |
| `dialog_utils.dart` | Confirmation/input dialog builders |
| `snackbar_utils.dart` | Themed snackbar helpers |
| `toast_utils.dart` | BotToast-based notification helpers |
| `number_formatter.dart` | Compact number display (1K, 1M, etc.) |
| `error_mapper.dart` | Firebase error code → Arabic user-facing message mapping |
| `permission_helper.dart` | Android runtime permission requests |
| `license_key_generator.dart` | License key format generation |

---

## 10. Presentation Layer

### 10.1 Screen Modules (10 in `presentation/screens/`)

| Module | Purpose |
|---|---|
| `auth/` | Login, Registration, Store setup |
| `home/` | Main dashboard shell |
| `dashboard/` | Overview cards, quick stats |
| `wallets/` | Wallet list, detail, create/edit |
| `transactions/` | Transaction list, create, detail |
| `debts/` | Debt management, payments |
| `employees/` | Employee CRUD, PIN management |
| `statistics/` | Charts, reports, date range filters |
| `subscription/` | Plan management, upgrade requests |
| `settings/` | App settings, SMS automation config |

### 10.2 Overlay UI (`presentation/overlays/`)

- `transaction_overlay_screen.dart` (12,307 bytes): Full-screen overlay triggered by SMS
- `overlay_provider.dart` (268 lines): State management for overlay (covered in §8.3)

---

## 11. Testing

### 11.1 Test Structure

```
test/
├── core/          (core utility tests)
├── data/          (repository + service tests)
├── domain/        (use case tests)
├── presentation/  (widget tests)
├── providers/     (provider tests)
└── stats_repository_test.dart
```

- **Framework**: `flutter_test` + `mocktail`
- **Firestore mocking**: `fake_cloud_firestore` (no emulator needed)
- **Coverage focus**: Repositories and validators (financial logic)

---

## 12. Findings & Technical Debt

### 12.1 Strengths ✅

| Area | Detail |
|---|---|
| **Atomic consistency** | All financial writes use `runTransaction` — no partial state corruption possible |
| **Fail-fast models** | `WalletModel` throws on missing timestamps; `DebtModel` validates on deserialization |
| **Anti-fraud** | Device-level trial tracking, Firestore rules block transaction deletion |
| **Isolate safety** | `SafeChangeNotifier` prevents use-after-dispose; background pipeline is self-contained |
| **Error hierarchy** | Rich typed exceptions enable precise catch blocks throughout the codebase |
| **Fetch shielding** | Prevents stale Firestore reads from overwriting fresh optimistic state |

### 12.2 Risks & Debt ⚠️

| ID | Severity | Area | Finding |
|---|---|---|---|
| **D1** | Medium | `EmployeeRepository.addEmployee` L118-122 | PIN uniqueness query runs **outside** the transaction's read set — theoretically vulnerable to race condition. Should use `transaction.get()` on a PIN-indexed query or use a dedicated PIN document. |
| **D2** | Medium | `EmployeeRepository.resetEmployeePIN` L245-256 | PIN uniqueness check is a separate Firestore read (not inside `runTransaction`), then update is a separate write. Race window exists between check and write. |
| **D3** | Low | `OverlayUseCase.execute` L43-45 | Creates a new `FirebaseService()` instance and calls `initialize()` — should use the DI-registered singleton. |
| **D4** | Low | `DatabaseSyncService` L263 | Creates `SubscriptionRepository()` inline — should use `sl<SubscriptionRepository>()`. |
| **D5** | Low | `auth_repository.dart` L214 | String interpolation escape error: `\\${e.toString()}` — will print literal `\${e}` instead of the error. |
| **D6** | Low | `employee_repository.dart` L40 | String interpolation escape: `\\$e` — same issue as D5. |
| **D7** | Info | Models | `WalletStats.operator==` doesn't compare `totalServiceFee` or `lastTransactionDate` — equality check is incomplete. |
| **D8** | Info | Test coverage | Only `stats_repository_test.dart` exists at root test level. Provider and widget test directories exist but coverage should be expanded for `TransactionValidatorService`. |

### 12.3 Recommendations for Next Developer

1. **Fix D1/D2**: Move PIN uniqueness checks inside `runTransaction` to eliminate race conditions
2. **Fix D3/D4**: Use DI-registered singletons consistently — `sl<FirebaseService>()`, `sl<SubscriptionRepository>()`
3. **Expand tests**: Priority on `TransactionValidatorService` (the 263-line financial core) and `DebtRepository.processPayment()`
4. **Schema registry**: Replace magic string field names with a centralized typed registry to prevent runtime failures from typos
5. **Provider decomposition**: As features grow, split `WalletProvider` (662 lines) into smaller, focused providers
6. **Subscription rules**: Add Firestore security rules for `subscription_requests` collection (currently missing from `firestore.rules`)

---

## 13. File Inventory

### Total File Counts

| Directory | Files | Subdirs |
|---|---|---|
| `lib/core/` | ~40 | 10 |
| `lib/data/models/` | 15 | 0 |
| `lib/data/repositories/` | 8+ | 0 |
| `lib/data/services/` | 6 | 0 |
| `lib/domain/` | 4 | 2 |
| `lib/providers/` | 7 | 0 |
| `lib/presentation/` | 12+ dirs | 4 |
| `lib/routes/` | 2 | 0 |
| `test/` | varies | 5 |

### Config Files

| File | Purpose |
|---|---|
| `pubspec.yaml` | 144 lines — dependencies, Flutter config |
| `firestore.rules` | 116 lines — security rules |
| `firestore.indexes.json` | Composite index definitions |
| `firebase.json` | Firebase CLI configuration |
| `analysis_options.yaml` | Linter rules (suppresses `non_constant_identifier_names`, `deprecated_member_use`) |
| `l10n.yaml` | Localization configuration |

---

> **Handover Status: COMPLETE.** This document, combined with the inline code comments and the project's `AGENTS.md`/`GEMINI.md`, provides full architectural context for a new senior developer to immediately understand and maintain the system.
