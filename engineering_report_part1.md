# WalletManager — Complete Engineering Audit Report (Part 1/2)

> **Audit Scope:** Every file in `lib/`, `test/`, config files, and Firestore rules.
> **Objective:** Handover-ready document for a new senior developer.

---

## 1. Project Identity

| Field | Value |
|---|---|
| **App Name** | Wallet Manager |
| **Platform** | Flutter (Android primary, iOS secondary) |
| **Firebase Project** | `ewallet-manager-421b8` |
| **Languages** | Arabic (primary UI), English |
| **Entry Points** | `main()` (app), `overlayMain()` (SMS overlay window) |

### 1.1 What This App Does

A **mobile financial operations platform** for Egyptian telecom store owners. They manage digital wallets (Vodafone Cash, InstaPay, Orange Cash, etc.), process customer send/receive transactions, track debts, manage employees with PIN-based access, and automate transaction recording via SMS parsing.

---

## 2. Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter/Dart |
| Backend | Firebase Auth, Firestore, Crashlytics, Analytics, Performance |
| State Mgmt | `provider` + `SafeChangeNotifier` (custom base) |
| DI | `get_it` (Service Locator pattern) |
| Local Storage | `shared_preferences` (session, cross-isolate vault) |
| Background | `flutter_background_service` + `another_telephony` |
| Overlay | `flutter_overlay_window` |
| Notifications | `flutter_local_notifications` |
| Auth | Firebase Auth (Email/Password + Google Sign-In) |
| Localization | `intl` + `.arb` files (Arabic/English) |

---

## 3. Architecture Overview

```
Clean Architecture (3-layer + providers)

┌─────────────────────────────────────────┐
│  presentation/                          │
│  ├── screens/ (10 feature modules)      │
│  ├── overlays/ (SMS transaction UI)     │
│  └── widgets/ (shared UI components)    │
├─────────────────────────────────────────┤
│  providers/ (7 ChangeNotifier classes)  │
│  SafeChangeNotifier base class          │
├─────────────────────────────────────────┤
│  domain/                                │
│  ├── entities/ (AuthUser)               │
│  └── usecases/ (3 use cases)            │
├─────────────────────────────────────────┤
│  data/                                  │
│  ├── models/ (15 data models)           │
│  ├── repositories/ (8 repositories)     │
│  └── services/ (6 services)             │
├─────────────────────────────────────────┤
│  core/                                  │
│  ├── constants/, enums/, errors/        │
│  ├── di/ (GetIt service locator)        │
│  ├── services/ (6 infra services)       │
│  ├── sms_automation/ (parser engine)    │
│  ├── state/ (SafeChangeNotifier)        │
│  ├── theme/, utils/, widgets/           │
│  └── routes/ (AppRouter + NavService)   │
└─────────────────────────────────────────┘
```

### 3.1 Initialization Flow (`main.dart`, 153 lines)

```
main() →
  1. WidgetsFlutterBinding.ensureInitialized()
  2. Firebase.initializeApp()
  3. AppErrorHandler.init() (global error hooks)
  4. Crashlytics (debug: disabled, release: enabled)
  5. setupServiceLocator() (GetIt DI registration)
  6. SmsService.initialize() (foreground SMS listener)
  7. initializeBackgroundService() (Guardian Isolate)
  8. runApp(WalletManagerApp)
```

**Overlay Entry** (`overlayMain()`): Separate `@pragma("vm:entry-point")` for the SMS overlay window. Runs in its own isolate, communicates via `IsolateNameServer` and `SharedPreferences` vault.

### 3.2 App Shell (`app.dart`, 203 lines)

`MultiProvider` tree wiring:
```
AuthProvider (root)
  └─► SubscriptionProvider (ProxyProvider, depends on Auth)
       └─► EmployeeProvider (ProxyProvider, depends on Auth)
       └─► WalletProvider (ProxyProvider, depends on Auth)
            └─► TransactionProvider
            └─► StatisticsProvider
            └─► DebtProvider
```

### 3.3 SafeChangeNotifier (`core/state/`, 34 lines)

Custom base class for **all** providers:
- Wraps `notifyListeners()` in a microtask to prevent "rebuild during build" errors
- Tracks `_isDisposed` flag to prevent use-after-dispose crashes
- Exposes `safeNotify()` as the only notification method

---

## 4. Data Layer

### 4.1 Models (15 files in `data/models/`)

| Model | Size | Purpose |
|---|---|---|
| `wallet_model.dart` | 453 lines | Core financial entity. Contains `WalletLimits`, `WalletStats`, limit reset logic, `canSendAmount()`/`canReceiveAmount()` guards. **Fail-fast** on missing timestamps. |
| `transaction_model.dart` | ~250 lines | Transaction record with type-safe enums (`TransactionType`, `PaymentStatus`). |
| `store_model.dart` | ~400 lines | Store entity with nested `StoreSubscription`, `StoreSettings`, `StoreStats`. |
| `debt_model.dart` | ~180 lines | Debt tracking with `DebtStatus` enum, normalized customer name for search. |
| `user_model.dart` | ~220 lines | User entity with `UserRole` enum, `UserPermissions`, `UserStats`. |
| `user_permissions.dart` | ~160 lines | Granular RBAC: `canCreateTransaction`, `canManageWallets`, etc. |
| `stats_summary_model.dart` | ~250 lines | Aggregate store statistics (wallets, transactions, debts). |
| `daily_stats_model.dart` | ~55 lines | Daily aggregation for dashboard charts. |
| `sim_wallet_config.dart` | ~90 lines | SIM-to-wallet mapping for SMS automation. |
| `subscription_request_model.dart` | ~95 lines | Subscription upgrade request tracking. |
| `device_registration_model.dart` | ~65 lines | Anti-fraud device fingerprinting. |
| `device_usage_model.dart` | ~60 lines | Device usage tracking for trial abuse prevention. |
| `license_key_model.dart` | ~45 lines | Legacy license key activation. |
| `system_configs_model.dart` | ~35 lines | Remote configuration model. |
| `paginated_result.dart` | ~10 lines | Generic pagination wrapper. |

#### Key Model Design Patterns

1. **`NumberParser` everywhere**: All numeric fields use `NumberParser.toDouble()` / `NumberParser.toInt()` for safe parsing (handles `null`, `String`, `int`, `double`; rejects negatives).
2. **`AmountValidator` guards**: `WalletModel.fromMap()` calls `AmountValidator.ensurePositiveOrZero(balance)` — throws `InvalidAmountException` on negative balance.
3. **Fail-fast deserialization**: `WalletModel` throws `NotFoundException` if `createdAt`, `lastDailyReset`, or `lastMonthlyReset` are null. Throws `DomainException` if `sendLimits` or `receiveLimits` are missing.
4. **Enum-based types**: All string-based type fields migrated to typed enums with `.fromString()` factory constructors.

### 4.2 Repositories (8 files in `data/repositories/`)

| Repository | Lines | Atomic Ops | Key Pattern |
|---|---|---|---|
| `transaction_repository.dart` | 283 | ✅ `runTransaction` | Delegates to `TransactionValidatorService` for atomic validation+write |
| `wallet_repository.dart` | 354 | ✅ `runTransaction` | Atomic credit/debit, bulk limit resets, stats co-updates |
| `debt_repository.dart` | 542 | ✅ `runTransaction` | Atomic debt CRUD with stats co-updates. Uses `CacheManager`. |
| `store_repository.dart` | 351 | ✅ `runTransaction` | Store lifecycle, trial provisioning, password hashing |
| `employee_repository.dart` | 383 | ✅ `runTransaction` | Employee CRUD, PIN uniqueness guard, max-employee limit check |
| `auth_repository.dart` | 218 | ❌ | Firebase Auth wrapper (Google + Email). Maps `User` → `AuthUser` |
| `subscription_repository.dart` | 133 | ✅ `runTransaction` | Device verification, trial consumption check, subscription requests |
| `stats_repository.dart` | 231 | ✅ `runTransaction` | Atomic store-level aggregate updates |

#### Critical Repository Patterns

**DebtRepository atomicity** (542 lines — largest repo):
- `createDebt()`: Atomic write of debt doc + stats increment
- `processPayment()`: Reads debt + stats → validates amount → writes payment + stats update (all in one `runTransaction`)
- `addPartialDebt()`: Handles reopening paid debts (status `paid` → `open`) with stats correction
- `deleteDebt()`: Atomic delete with stats decrement, handles both open and paid debt cleanup
- **Anti-corruption**: Corrupt documents are logged via `AppErrorHandler.logSilentError()` and skipped during list operations

**EmployeeRepository guards**:
- `addEmployee()`: Inside `runTransaction` — checks `maxEmployees` subscription limit, ensures PIN uniqueness, increments store stats
- `deactivateEmployee()`: Atomic user deactivation + stats decrement (both store doc and stats summary)
- Identity provisioning via `IdentityService` for Firebase Auth credential creation

**SubscriptionRepository anti-fraud**:
- `hasDeviceConsumedTrial()`: Queries root-level `device_registrations` collection by hardware device ID, checks `trialCount >= 1`
- `verifyDevice()`: Upserts device registration with `ownerUid`, `lastSeenAt` timestamps

### 4.3 Services (6 files in `data/services/`)

| Service | Lines | Purpose |
|---|---|---|
| `transaction_validator_service.dart` | 263 | **THE critical business logic file.** Atomic Firestore transaction: validates balance, resets daily/monthly limits if needed, calculates cumulative usage, enforces epsilon (`0.01 EGP`) comparison. |
| `local_storage_service.dart` | 302 | SharedPreferences wrapper. Session management, cross-isolate "vault" for overlay communication, cached wallet lite list. |
| `firebase_service.dart` | ~90 | Firebase initialization and instance access (Auth, Firestore). |
| `google_sign_in_service.dart` | ~100 | Google Sign-In flow wrapper. |
| `migration_service.dart` | ~130 | Schema migration for existing Firestore documents. |
| `wallet_cache_manager.dart` | ~30 | Specialized cache for wallet data. |

#### TransactionValidatorService Deep Dive

This is the **most critical 263 lines** in the entire codebase:

```
validateAndSave() →
  1. Read wallet doc (inside runTransaction)
  2. Check if daily/monthly limit reset is needed (date comparison)
  3. If reset needed → zero out usage counters
  4. Calculate new cumulative usage (existing + new amount)
  5. Validate: newUsage <= limit (with 0.01 EGP epsilon)
  6. Validate: balance >= totalDeduction (for debit only)
  7. Write transaction doc
  8. Update wallet: balance, usage, stats, timestamps
  9. Update store stats summary doc
  10. Update daily stats doc
```

**All 10 steps happen inside a single `runTransaction` block** — if any step fails, everything rolls back.

---

## 5. Domain Layer

### 5.1 Entities

- `auth_user.dart` (454 bytes): Pure domain object — `uid`, `email`, `displayName`, `photoURL`. No Firebase dependency.

### 5.2 Use Cases (3 files)

| UseCase | Lines | Purpose |
|---|---|---|
| `overlay_usecase.dart` | 110 | Orchestrates SMS-triggered transaction creation. Builds `TransactionModel`, calls `TransactionRepository.createTransaction()`, saves to overlay vault, returns `TransactionResult` with deduction amount. |
| `transaction_fee_calculator.dart` | 96 | Pure domain logic: given wallet, type, amount, commission → calculates service fee, total amount, limit projections. Validates inputs via `AmountValidator`. Returns `TransactionCalculationResult`. |
| `wallet_usecase.dart` | ~60 | Wallet-specific business operations. |

---

## 6. Firestore Security Rules (`firestore.rules`, 116 lines)

### Helper Functions
- `isAuthenticated()`: `request.auth != null`
- `isStoreOwner(storeId)`: `auth.uid == storeId` (storeId IS the owner's UID)
- `isStoreEmployee(storeId)`: Reads `/users/{auth.uid}` to check `storeId` match
- `canAccessStore(storeId)`: Owner OR Employee

### Collection Rules

| Collection | Read | Create | Update | Delete |
|---|---|---|---|---|
| `device_registrations/{id}` | Owner only | Auth + ownerUid match | ❌ | ❌ |
| `license_keys/{id}` | Auth | ❌ | Auth | ❌ |
| `users/{userId}` | Self OR store owner | Self OR store owner | Self OR store owner | Store owner |
| `stores/{storeId}` | Owner + Employee | Owner only | Owner only | ❌ |
| `stores/{id}/stats/summary` | Owner + Employee | Owner + Employee | Owner + Employee | — |
| `stores/{id}/daily_stats/{day}` | Owner + Employee | Owner + Employee | Owner + Employee | — |
| `wallets/{id}` | Store access | Store access | Store access + no storeId change | Store access |
| `transactions/{id}` | Store access | Store access | Store access + no storeId change | **❌ NEVER** |
| `debts/{id}` | Store access | Store access | Store access + no storeId change | Store access |

> [!IMPORTANT]
> **Transaction deletion is permanently blocked** (`allow delete: if false`) — this is an intentional financial audit trail protection.

> [!WARNING]
> **Wallet transfer prevention**: Update rules enforce `request.resource.data.storeId == resource.data.storeId` — wallets cannot be moved between stores.

---

## 7. Enums (6 files in `core/enums/`)

| File | Key Enums |
|---|---|
| `wallet_enums.dart` | `WalletType` (vodafone_cash, instapay, orange_cash, etisalat_cash, we_pay), `WalletStatus` (new, old, registered_store, active) |
| `transaction_enums.dart` | `TransactionType` (credit, debit), `PaymentStatus` (paid, pending, cancelled) |
| `debt_enums.dart` | `DebtStatus` (open, paid), `DebtType` (incoming, outgoing) |
| `user_enums.dart` | `UserRole` (owner, employee) |
| `subscription_enums.dart` | `SubscriptionPlan` (trial, pro_yearly, lifetime), `SubscriptionStatus` (active, expired, suspended) |
| `store_enums.dart` | Store-level configuration enums |

All enums provide `.fromString()` factory constructors for safe Firestore deserialization.
