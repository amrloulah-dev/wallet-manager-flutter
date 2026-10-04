# Implementation Plan: Master Architecture Refactor (002)

**Feature:** 002-master-arch-refactor
**Spec:** [spec.md](file:///c:/src/walletmanager/.specify/features/002-master-arch-refactor/spec.md)
**Research:** [research.md](file:///c:/src/walletmanager/.specify/features/002-master-arch-refactor/research.md)
**Data Model:** [data-model.md](file:///c:/src/walletmanager/.specify/features/002-master-arch-refactor/data-model.md)
**Date:** 2026-04-14
**Status:** Draft

---

## Technical Context

| Dimension             | Value                                                                                 |
| --------------------- | ------------------------------------------------------------------------------------- |
| Language / Framework   | Dart 3.x / Flutter                                                                   |
| State Management      | `provider` 6.x with `ChangeNotifier`                                                |
| Backend               | Firebase Auth + Cloud Firestore (client-side only — no rules changes)                |
| DI Container          | `get_it` 8.x (NEW — to be added)                                                    |
| Error UI              | `bot_toast` 4.x (existing) + `showDialog` via `NavigationService.navigatorKey`       |
| SMS Pipeline          | `another_telephony` → `SmsParserEngine` → `sms_processing_pipeline.dart`             |
| Background Service    | `flutter_background_service` (Guardian Isolate)                                      |
| Testing               | `flutter_test` + `mocktail` + `fake_cloud_firestore`                                 |
| Repositories          | 12 existing classes under `lib/data/repositories/`                                   |
| Constitution          | 7 principles — all enforced. See [constitution.md](file:///c:/src/walletmanager/.specify/memory/constitution.md) |

---

## Constitution Compliance Check

| # | Principle          | Impact Assessment                                                                                                      | Phase |
|---|--------------------|------------------------------------------------------------------------------------------------------------------------|-------|
| 1 | Optimistic UI      | **Preserved.** Phase 1 identity provisioning is async-after-local-save. Phase 2 error handling adds rollback surface. | 1, 2  |
| 2 | Surgical Reactivity| **Advanced.** Phase 4 replaces remaining `Consumer` with `Selector` on dashboard components post-decomposition.       | 3, 4  |
| 3 | Zero-Waste Reads   | **Preserved.** No new `StreamBuilder` or `.snapshots()` introduced. Identity lookup uses `.get()` on login only.       | 1     |
| 4 | Safe Rollbacks     | **Advanced.** Phase 2 centralizes error handling so every rollback now produces user-visible feedback.                  | 2     |
| 5 | O(1) Lookups       | **Preserved.** No changes to existing Map-based lookups. Dashboard decomposition preserves indexed access.             | 3     |
| 6 | Fetch Shield       | **Preserved.** No changes to isolate communication or fetch shield mechanics.                                          | —     |
| 7 | ValueKey           | **Preserved.** Dashboard decomposition carries existing ValueKey patterns into extracted components.                    | 3     |

**Gate Result: ✅ PASS** — No principle violations. Phases 2 and 4 actively advance Principles 2 and 4.

---

## Phase 1: Security & Identity

> **Goal:** Provision virtual Firebase Auth identities for employees without interrupting the owner's session.
> **Spec Requirements:** FR-01, FR-02, FR-03 | US-01, US-02

### 1.1 Secondary Firebase App Initialization

#### [NEW] `lib/core/services/identity_service.dart`

Create a dedicated service class that manages the secondary `FirebaseApp` lifecycle:

```
class IdentityService {
  static FirebaseApp? _secondaryApp;
  static FirebaseAuth? _secondaryAuth;

  /// Initialize the secondary FirebaseApp (idempotent).
  static Future<void> _ensureInitialized()
  
  /// Provision a virtual identity. Returns the UID or null on failure.
  static Future<String?> provisionIdentity({
    required String phone,
    required String storeId,
    required String pin,
  })
  
  /// Update a virtual identity's password (PIN sync).
  static Future<bool> updateCredential({
    required String phone,
    required String storeId,
    required String newPin,
  })

  /// Delete a virtual identity (best-effort).
  static Future<bool> deleteIdentity({
    required String phone,
    required String storeId,
  })

  /// Authenticate an employee against their virtual identity.
  /// Returns the UID on success, null on failure.
  static Future<String?> authenticateEmployee({
    required String phone,
    required String storeId,
    required String pin,
  })
}
```

**Key Design Decisions:**
- Uses `Firebase.initializeApp(name: 'employeeAuth', options: Firebase.app().options)` — same project, isolated auth instance.
- Email format: `emp_<phone>_<storeId>@store.com` (store-scoped uniqueness).
- Password = employee PIN (hashed by Firebase Auth automatically).
- The secondary app is lazily initialized and reused across calls.
- All methods are static — no instance state needed.

**Constitution Compliance:**
- Principle 1 (Optimistic UI): Identity provisioning happens AFTER the employee record is saved locally.
- Principle 3 (Zero-Waste): Uses `.createUserWithEmailAndPassword()` / `.signInWithEmailAndPassword()` — no streams.

### 1.2 Employee Model Extension

#### [MODIFY] `lib/data/models/employee_model.dart`

Add `firebaseUid` field:

```dart
// New field
final String? firebaseUid;

// Constructor: add named parameter with default null
// toFirestore(): add 'firebaseUid': firebaseUid
// fromFirestore(): read firebaseUid from data, default null
// copyWith(): include firebaseUid
```

### 1.3 Employee Repository — Identity Lifecycle Hooks

#### [MODIFY] `lib/data/repositories/employee_repository.dart`

Add three methods that wrap `IdentityService` calls and update the employee Firestore document:

| Method                           | Trigger                          | Behavior                                                       |
| -------------------------------- | -------------------------------- | -------------------------------------------------------------- |
| `provisionIdentity(employee)`    | After `addEmployee()` succeeds   | Call `IdentityService.provisionIdentity()`, update doc with UID |
| `syncCredential(employee, pin)`  | After `updateEmployeePin()`      | Call `IdentityService.updateCredential()`                      |
| `cleanupIdentity(employee)`      | After `deleteEmployee()` succeeds| Call `IdentityService.deleteIdentity()`, best-effort            |

All three are **fire-and-forget** async operations — failures are logged but never block the primary operation.

### 1.4 Employee Provider — Orchestration

#### [MODIFY] `lib/providers/employee_provider.dart`

Update the following methods:

| Method              | Change                                                                               |
| ------------------- | ------------------------------------------------------------------------------------ |
| `addEmployee()`     | After successful local save + Firestore write, call `_repo.provisionIdentity()`.     |
| `updatePin()`       | After successful PIN update, call `_repo.syncCredential()`.                          |
| `deleteEmployee()`  | After successful deletion, call `_repo.cleanupIdentity()`.                           |

### 1.5 Employee Authentication Flow

#### [MODIFY] `lib/providers/auth_provider.dart`

Update the employee login path in `loginAsEmployee()`:

```
Current flow:
  1. Find employee by phone + storeId
  2. Verify PIN locally (hash comparison)
  3. Set session

New flow:
  1. Find employee by phone + storeId
  2. If employee.firebaseUid != null:
       → Authenticate via IdentityService.authenticateEmployee()
       → On success: set session with the employee's own UID
       → On failure: fall back to local PIN verification (graceful degradation)
  3. If employee.firebaseUid == null:
       → Use existing local PIN verification
       → Attempt lazy provisioning in background
  4. Set session
```

**Fallback Strategy:** Employees created before this refactor will have `firebaseUid == null`. The system gracefully degrades to local PIN check and attempts lazy provisioning. This ensures zero disruption to existing users.

### 1.6 Unit Tests

#### [NEW] `test/core/services/identity_service_test.dart`

| Test Case                                          | Validates                                    |
| -------------------------------------------------- | -------------------------------------------- |
| `provisionIdentity creates user on secondary auth` | FR-01: identity creation                     |
| `provisionIdentity does not sign out primary auth`  | FR-01: owner session isolation               |
| `duplicate email returns existing UID`              | Idempotency on retry                         |
| `updateCredential changes password`                 | FR-01: PIN sync                              |
| `deleteIdentity removes user`                       | FR-01: cleanup                               |
| `authenticateEmployee returns UID on success`       | FR-02: login via own identity                |
| `authenticateEmployee returns null on wrong PIN`    | FR-02: failed login                          |

#### [NEW] `test/providers/employee_provider_identity_test.dart`

| Test Case                                         | Validates                                     |
| ------------------------------------------------- | --------------------------------------------- |
| `addEmployee provisions identity on success`      | FR-01: auto-provisioning                      |
| `addEmployee succeeds even if provisioning fails` | FR-01: graceful degradation                   |
| `deleteEmployee cleans up identity`               | FR-01: deletion cleanup                       |
| `updatePin syncs credential`                      | FR-01: PIN sync                               |

---

## Phase 2: Global Error Handling

> **Goal:** Replace every silent catch with centralized, severity-routed error feedback + structured diagnostic logging.
> **Spec Requirements:** FR-04, FR-05, FR-06 | US-03, US-04

### 2.1 Error Infrastructure

#### [NEW] `lib/core/errors/error_severity.dart`

```dart
enum ErrorSeverity { low, medium, critical }
```

#### [NEW] `lib/core/errors/app_error_handler.dart`

Central error handler with three public entry points:

```
class AppErrorHandler {
  /// Route an error to the appropriate UI feedback + diagnostic log.
  static void handle(
    Object error, {
    required ErrorSeverity severity,
    required String operation,
    StackTrace? stackTrace,
    String? userMessage,
  })

  // Internal routing:
  // Low    → BotToast.showText(text: userMessage ?? defaultArabicMsg)
  // Medium → BotToast.showNotification(title: ..., subtitle: userMessage)
  // Critical → showDialog via NavigationService.navigatorKey.currentState
  
  /// Structured diagnostic log (always called regardless of severity).
  static void _logDiagnostic(
    ErrorSeverity severity,
    String operation,
    Object error,
    StackTrace? stackTrace,
  )
  // Format: [ERROR] [severity] [operation] message\n  Stack: ...\n  Timestamp: ...
}
```

**Key Design Decisions:**
- Uses `NavigationService.navigatorKey` (already exists) for context-free dialog display — no `BuildContext` needed.
- All user-facing messages default to Arabic. Callers can override with `userMessage`.
- `_logDiagnostic` always fires — even for Low severity. This prepares for Crashlytics.
- The handler is stateless — all static methods. No DI registration needed.

### 2.2 Silent Catch Remediation — Providers

Systematic sweep of every provider file. Each silent catch is replaced with `AppErrorHandler.handle()`:

#### [MODIFY] `lib/providers/wallet_provider.dart`

| Line | Current Code                | Severity | Operation Context         |
| ---- | --------------------------- | -------- | ------------------------- |
| 156  | `catch (_) {}`              | N/A      | **SKIP** — legitimate stream error guard |
| 370  | `catch (e) {}`              | Low      | `wallet_cache_write`      |

Also: audit all `_setError()` calls to ensure they route through `AppErrorHandler.handle()` at Medium severity, in addition to setting local error state.

#### [MODIFY] `lib/providers/auth_provider.dart`

| Target                       | Severity | Operation Context            |
| ---------------------------- | -------- | ---------------------------- |
| Silent catches in login flow | Critical | `auth_login`                 |
| Silent catches in auto-login | Medium   | `auth_auto_login`            |
| Cache write failures         | Low      | `auth_cache_write`           |

#### [MODIFY] `lib/providers/transaction_provider.dart`

| Line    | Current Code    | Severity | Operation Context              |
| ------- | --------------- | -------- | ------------------------------ |
| 415-416 | `catch (e) {}`  | Low      | `transaction_local_insert`     |

#### [MODIFY] `lib/providers/employee_provider.dart`
#### [MODIFY] `lib/providers/debt_provider.dart`
#### [MODIFY] `lib/providers/statistics_provider.dart`
#### [MODIFY] `lib/providers/subscription_provider.dart`

Same pattern: identify silent catches, assign severity, wrap with `AppErrorHandler.handle()`.

### 2.3 SMS Pipeline Error Isolation

#### [MODIFY] `lib/core/services/sms_processing_pipeline.dart`

| Line | Current                     | Change                                                              |
| ---- | --------------------------- | ------------------------------------------------------------------- |
| 210  | `catch (_) { // Swallow }`  | Add `AppErrorHandler._logDiagnostic(Low, 'sms_pipeline', e, st)` inside the catch. Continue swallowing — isolate must not crash. |

#### [MODIFY] `lib/core/services/background_service.dart`

| Line | Current                      | Change                                                              |
| ---- | ---------------------------- | ------------------------------------------------------------------- |
| 108  | `catch (_) { // Swallow }`   | Add diagnostic logging. Continue swallowing.                        |

**Note:** SMS pipeline catches are a special case. They MUST continue swallowing to prevent isolate crashes (Constitution Principle 6). But they must now LOG the error for diagnostics per FR-06.

### 2.4 Loading State Consistency (FR-05)

Audit all providers for `finally` blocks that clear loading state. Pattern to enforce:

```dart
try {
  _status = SomeStatus.loading;
  // ... async work ...
  _status = SomeStatus.loaded;
} catch (e, st) {
  _status = SomeStatus.error;
  AppErrorHandler.handle(e, severity: ..., operation: '...', stackTrace: st);
} finally {
  // Guarantee: no stuck spinner
  if (_status == SomeStatus.loading) {
    _status = SomeStatus.idle;
  }
  notifyListeners(); // Single notification at end
}
```

### 2.5 Unit Tests

#### [NEW] `test/core/errors/app_error_handler_test.dart`

| Test Case                                    | Validates                          |
| -------------------------------------------- | ---------------------------------- |
| `handle with Low severity shows toast`       | FR-04: toast routing               |
| `handle with Medium severity shows banner`   | FR-04: banner routing              |
| `handle with Critical severity shows dialog` | FR-04: dialog routing              |
| `handle always logs diagnostics`             | FR-04: structured logging          |
| `diagnostic log contains severity + context` | FR-04: log format                  |

---

## Phase 3: Architecture & Dependency Injection

> **Goal:** Register all repositories in a DI container, eliminate residual direct Firestore calls in providers, and decompose the dashboard.
> **Spec Requirements:** FR-07, FR-08 | US-05

### 3.1 Add `get_it` Dependency

#### [MODIFY] `pubspec.yaml`

```yaml
dependencies:
  get_it: ^8.0.3
```

Run `flutter pub get` after adding.

### 3.2 Service Locator Setup

#### [NEW] `lib/core/di/service_locator.dart`

```dart
import 'package:get_it/get_it.dart';
// ... repository imports ...

final GetIt sl = GetIt.instance;

Future<void> setupServiceLocator() async {
  // Repositories — Lazy Singletons
  sl.registerLazySingleton<AuthRepository>(() => AuthRepository());
  sl.registerLazySingleton<WalletRepository>(() => WalletRepository());
  sl.registerLazySingleton<TransactionRepository>(() => TransactionRepository());
  sl.registerLazySingleton<DebtRepository>(() => DebtRepository());
  sl.registerLazySingleton<EmployeeRepository>(() => EmployeeRepository());
  sl.registerLazySingleton<StoreRepository>(() => StoreRepository());
  sl.registerLazySingleton<StatsRepository>(() => StatsRepository());
  sl.registerLazySingleton<SubscriptionRepository>(() => SubscriptionRepository());
  sl.registerLazySingleton<SystemConfigRepository>(() => SystemConfigRepository());
  sl.registerLazySingleton<DeviceRepository>(() => DeviceRepository());
  sl.registerLazySingleton<LicenseKeyRepository>(() => LicenseKeyRepository());
  sl.registerLazySingleton<UserRepository>(() => UserRepository());
}
```

#### [MODIFY] `lib/main.dart`

Call `await setupServiceLocator()` before `runApp()`.

### 3.3 Provider Constructor Migration

#### [MODIFY] `lib/app.dart`

Replace direct repository instantiation with `sl<T>()` lookups in all `MultiProvider` entries:

| Current                                              | New                                       |
| ---------------------------------------------------- | ----------------------------------------- |
| `EmployeeRepository()`                               | `sl<EmployeeRepository>()`                |
| `WalletRepository()`                                 | `sl<WalletRepository>()`                  |
| `DebtRepository()`                                   | `sl<DebtRepository>()`                    |
| `TransactionRepository()` (in StatisticsProvider)    | `sl<TransactionRepository>()`             |
| `StatsRepository()`                                  | `sl<StatsRepository>()`                   |
| `SystemConfigRepository()`                           | `sl<SystemConfigRepository>()`            |

Also update the `update:` callbacks that re-instantiate repositories (e.g., `WalletRepository()` in the `update` closure of `WalletProvider`'s ProxyProvider) — these should NOT create new instances. The `update` callback should reuse the existing provider, not construct a new one with a fresh repository.

### 3.4 Residual Direct Firestore Call Elimination

#### [MODIFY] `lib/providers/wallet_provider.dart` (line 474)

| Current                                                    | New                                          |
| ---------------------------------------------------------- | -------------------------------------------- |
| `FirebaseFirestore.instance.collection('wallets').doc().id` | `_walletRepository.generateId()`             |

#### [MODIFY] `lib/data/repositories/wallet_repository.dart`

Add:
```dart
String generateId() => walletsCollection.doc().id;
```

#### [MODIFY] `lib/providers/debt_provider.dart` (line 303)

| Current                                                  | New                                        |
| -------------------------------------------------------- | ------------------------------------------ |
| `FirebaseFirestore.instance.collection('debts').doc().id` | `_debtRepository.generateId()`            |

#### [MODIFY] `lib/data/repositories/debt_repository.dart`

Add:
```dart
String generateId() => debtsCollection.doc().id;
```

### 3.5 Dashboard Decomposition

#### [NEW] `lib/presentation/screens/home/widgets/dashboard_welcome_header.dart`

Extract `_buildWelcomeHeader()` from `MainDashboardScreen`. Subscribes to `AuthProvider` via `Selector` for `fullName` only.

#### [NEW] `lib/presentation/screens/home/widgets/dashboard_quick_stats.dart`

Extract the statistics card section. Subscribes to `StatisticsProvider` via `Selector` for summary data.

#### [NEW] `lib/presentation/screens/home/widgets/dashboard_quick_actions.dart`

Extract the quick-action buttons section. Subscribes to `StatisticsProvider` via `Selector` for debts count (badge).

#### [NEW] `lib/presentation/screens/home/widgets/dashboard_alerts.dart`

Extract the alerts/notification section. Subscribes to `WalletProvider` + `DebtProvider` via `Selector` for alert counts.

#### [NEW] `lib/presentation/screens/home/widgets/dashboard_recent_txns.dart`

Extract the recent transactions list. Subscribes to `TransactionProvider` via `Selector` for `todayTransactions`.

#### [MODIFY] `lib/presentation/screens/home/main_dashboard_screen.dart`

Refactor from 746-line monolith to ~100-line composition root:

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    body: CustomScrollView(
      slivers: [
        const DashboardWelcomeHeader(),
        const DashboardQuickStats(),
        const DashboardQuickActions(),
        const DashboardAlerts(),
        const DashboardRecentTxns(),
      ],
    ),
  );
}
```

### 3.6 Unit Tests

#### [NEW] `test/core/di/service_locator_test.dart`

| Test Case                                    | Validates                              |
| -------------------------------------------- | -------------------------------------- |
| `setupServiceLocator registers all repos`    | FR-07: all 12 repos registered         |
| `sl<T>() returns same instance`              | Singleton behavior                     |
| `providers receive injected repositories`    | FR-07: no direct instantiation         |

---

## Phase 4: Performance Tuning

> **Goal:** Batch `notifyListeners()` calls and migrate remaining root-level subscriptions to `Selector` widgets.
> **Spec Requirements:** FR-09, FR-10 | US-06

### 4.1 Notification Batching

Refactor the `_setStatus()` / `_setError()` helper pattern used across all providers.

**Current anti-pattern (in every provider):**
```dart
void _setStatus(SomeStatus status) {
  _status = status;
  notifyListeners();  // ← fires notification DURING the operation
}
```

**New pattern:**
```dart
// Private setter — does NOT notify
void _updateStatus(SomeStatus status) {
  if (_isDisposed) return;
  _status = status;
}

// Public operations call notifyListeners() ONCE at the end
Future<void> someOperation() async {
  _updateStatus(SomeStatus.loading);
  try {
    // ... mutate state ...
    _updateStatus(SomeStatus.loaded);
  } catch (e, st) {
    _errorMessage = e.toString();
    _updateStatus(SomeStatus.error);
    AppErrorHandler.handle(e, severity: ..., operation: '...', stackTrace: st);
  } finally {
    _safeNotify();  // Single notification
  }
}

void _safeNotify() {
  if (!_isDisposed) notifyListeners();
}
```

#### Files to refactor:

| Provider                       | Current `notifyListeners()` | Target | Reduction |
| ------------------------------ | --------------------------- | ------ | --------- |
| `wallet_provider.dart`         | 19                          | ~9     | ~53%      |
| `statistics_provider.dart`     | 9                           | ~5     | ~44%      |
| `subscription_provider.dart`   | 7                           | ~4     | ~43%      |
| `employee_provider.dart`       | 5                           | ~3     | ~40%      |
| `transaction_provider.dart`    | 4                           | ~3     | ~25%      |
| `debt_provider.dart`           | (audit)                     | —      | —         |
| `auth_provider.dart`           | (audit)                     | —      | —         |

### 4.2 Targeted UI Rebuild Migration

Replace remaining root-level `Consumer<T>` and `context.watch<T>()` calls with `Selector<T, R>` on key screens.

#### [MODIFY] Dashboard components (already decomposed in Phase 3)

Each extracted component should already use `Selector` from Phase 3. Phase 4 verifies and optimizes:

| Component                       | Selector Target                              |
| ------------------------------- | -------------------------------------------- |
| `DashboardWelcomeHeader`        | `Selector<AuthProvider, String>(selector: (_, a) => a.currentUser?.fullName ?? '')` |
| `DashboardQuickStats`           | `Selector<StatisticsProvider, Map<String, dynamic>>(selector: (_, s) => s.dashboardSummary)` |
| `DashboardQuickActions`         | `Selector<StatisticsProvider, int>(selector: (_, s) => s.pendingDebtsCount)` |
| `DashboardAlerts`               | `Selector2<WalletProvider, DebtProvider, ...>` |
| `DashboardRecentTxns`           | `Selector<TransactionProvider, List<TransactionModel>>(selector: (_, t) => t.todayTransactions)` |

#### [MODIFY] Wallet list screen

Audit for root-level `Consumer<WalletProvider>`. Replace with `Selector` that subscribes only to `wallets` list and `status`.

#### Verification: Inspector Rebuild Count

Use Flutter DevTools' "Widget rebuild stats" overlay to verify:
- Dashboard: each component rebuilds independently
- Wallet list: individual `WalletCard` rebuilds on balance change, siblings don't

### 4.3 Unit Tests

#### [NEW] `test/providers/notification_batching_test.dart`

| Test Case                                                   | Validates                                |
| ----------------------------------------------------------- | ---------------------------------------- |
| `createWallet fires exactly 1 notifyListeners`              | FR-09: single notification               |
| `fetchWallets fires exactly 1 notifyListeners`              | FR-09: single notification               |
| `createTransaction fires exactly 1 notifyListeners`         | FR-09: single notification               |
| `error during operation fires exactly 1 notifyListeners`    | FR-09: error path batching               |

---

## Execution Order & Dependencies

```
Phase 1: Security & Identity
  ├── 1.1 IdentityService (NEW)
  ├── 1.2 EmployeeModel.firebaseUid (MODIFY)
  ├── 1.3 EmployeeRepository hooks (MODIFY)
  ├── 1.4 EmployeeProvider orchestration (MODIFY)
  ├── 1.5 AuthProvider login flow (MODIFY)
  └── 1.6 Unit tests

Phase 2: Global Error Handling  [depends on Phase 1 complete]
  ├── 2.1 AppErrorHandler + ErrorSeverity (NEW)
  ├── 2.2 Provider silent catch sweep (MODIFY × 7)
  ├── 2.3 SMS pipeline logging (MODIFY × 2)
  ├── 2.4 Loading state consistency audit
  └── 2.5 Unit tests

Phase 3: Architecture & DI  [depends on Phase 2 complete]
  ├── 3.1 Add get_it dependency
  ├── 3.2 Service locator setup (NEW)
  ├── 3.3 app.dart provider migration (MODIFY)
  ├── 3.4 Residual Firestore call elimination (MODIFY × 4)
  ├── 3.5 Dashboard decomposition (NEW × 5, MODIFY × 1)
  └── 3.6 Unit tests

Phase 4: Performance Tuning  [depends on Phase 3 complete]
  ├── 4.1 Notification batching (MODIFY × 7)
  ├── 4.2 Selector migration on dashboard + wallet list
  └── 4.3 Unit tests + DevTools verification
```

---

## File Change Summary

### New Files (10)

| File                                                            | Phase | Purpose                        |
| --------------------------------------------------------------- | ----- | ------------------------------ |
| `lib/core/services/identity_service.dart`                       | 1     | Secondary Firebase Auth        |
| `lib/core/errors/error_severity.dart`                           | 2     | Severity enum                  |
| `lib/core/errors/app_error_handler.dart`                        | 2     | Centralized error routing      |
| `lib/core/di/service_locator.dart`                              | 3     | get_it DI registry             |
| `lib/presentation/screens/home/widgets/dashboard_welcome_header.dart` | 3 | Dashboard component          |
| `lib/presentation/screens/home/widgets/dashboard_quick_stats.dart`    | 3 | Dashboard component          |
| `lib/presentation/screens/home/widgets/dashboard_quick_actions.dart`  | 3 | Dashboard component          |
| `lib/presentation/screens/home/widgets/dashboard_alerts.dart`         | 3 | Dashboard component          |
| `lib/presentation/screens/home/widgets/dashboard_recent_txns.dart`    | 3 | Dashboard component          |
| `test/` (multiple test files)                                   | 1–4   | Unit tests per phase           |

### Modified Files (18)

| File                                            | Phase | Change Scope                           |
| ----------------------------------------------- | ----- | -------------------------------------- |
| `pubspec.yaml`                                  | 3     | Add `get_it` dependency                |
| `lib/main.dart`                                 | 3     | Call `setupServiceLocator()`           |
| `lib/app.dart`                                  | 3     | Replace `Repository()` with `sl<T>()`  |
| `lib/data/models/employee_model.dart`           | 1     | Add `firebaseUid` field                |
| `lib/data/repositories/employee_repository.dart`| 1     | Add identity lifecycle methods         |
| `lib/data/repositories/wallet_repository.dart`  | 3     | Add `generateId()` method              |
| `lib/data/repositories/debt_repository.dart`    | 3     | Add `generateId()` method              |
| `lib/providers/auth_provider.dart`              | 1, 2  | Virtual identity login + error handler |
| `lib/providers/employee_provider.dart`          | 1, 2  | Provisioning orchestration + errors    |
| `lib/providers/wallet_provider.dart`            | 2, 3, 4 | Errors + DI + batching              |
| `lib/providers/transaction_provider.dart`       | 2, 4  | Errors + batching                      |
| `lib/providers/debt_provider.dart`              | 2, 3, 4 | Errors + DI + batching              |
| `lib/providers/statistics_provider.dart`        | 2, 4  | Errors + batching                      |
| `lib/providers/subscription_provider.dart`      | 2, 4  | Errors + batching                      |
| `lib/core/services/sms_processing_pipeline.dart`| 2     | Add diagnostic logging in catch        |
| `lib/core/services/background_service.dart`     | 2     | Add diagnostic logging in catch        |
| `lib/presentation/screens/home/main_dashboard_screen.dart` | 3 | Decompose into components    |
| Wallet list screen                              | 4     | Selector migration                     |

### Deleted Files (0)

No files deleted.

---

## Verification Plan

### Automated Tests

```bash
# Run all tests after each phase
flutter test

# Phase 1 specific
flutter test test/core/services/identity_service_test.dart
flutter test test/providers/employee_provider_identity_test.dart

# Phase 2 specific
flutter test test/core/errors/app_error_handler_test.dart

# Phase 3 specific
flutter test test/core/di/service_locator_test.dart

# Phase 4 specific
flutter test test/providers/notification_batching_test.dart
```

### Static Analysis

```bash
# Must pass with zero errors after each phase
flutter analyze
```

### Manual Verification

| Phase | Verification                                                                            |
| ----- | --------------------------------------------------------------------------------------- |
| 1     | Create employee → verify `firebaseUid` populated in Firestore document                  |
| 1     | Employee login → verify auth resolves to employee's own UID                             |
| 1     | Change employee PIN → verify credential sync (re-login with new PIN)                    |
| 1     | Delete employee → verify virtual identity removed from Firebase Auth console             |
| 2     | Force a wallet save error → verify Arabic error banner appears                          |
| 2     | Force auth failure → verify blocking Arabic error dialog appears                        |
| 2     | Send malformed SMS → verify pipeline continues, diagnostic log emitted                  |
| 3     | Verify app starts without errors after DI migration                                      |
| 3     | Verify dashboard renders correctly after decomposition                                   |
| 4     | Use Flutter DevTools to verify rebuild counts on dashboard                               |
| 4     | Scroll wallet list with 30+ items — verify 60fps on mid-range device                   |

### Success Criteria Cross-Reference

| # | Criterion                                    | Verified By                                   |
|---|----------------------------------------------|-----------------------------------------------|
| 1 | New employees have independent identity       | Phase 1 tests + manual Firestore check        |
| 2 | Employee login uses own identity              | Phase 1 tests + manual login verification     |
| 3 | Owner session never interrupted               | Phase 1 `provisionIdentity` isolation test    |
| 4 | Zero silent catches                           | `grep -r "catch.*{}" lib/` returns 0          |
| 5 | Arabic error feedback on all paths            | Phase 2 tests + manual UI check               |
| 6 | Single bad SMS doesn't halt pipeline          | Phase 2 SMS isolation test                    |
| 7 | No direct data calls in providers             | `grep "FirebaseFirestore.instance" lib/providers/` returns 0 |
| 8 | Dashboard decomposed into ≥4 components       | File count in `screens/home/widgets/`         |
| 9 | Max 1 notification per operation              | Phase 4 batching tests                        |
| 10| 60fps on mid-range device                     | DevTools performance overlay                  |

---

## Risk Mitigation

| Risk                                                | Likelihood | Impact | Mitigation                                                                        |
| --------------------------------------------------- | ---------- | ------ | --------------------------------------------------------------------------------- |
| Secondary Firebase Auth instance has unexpected limits | Low      | High   | Test on device early in Phase 1. Falls back to local PIN auth if needed.          |
| `get_it` registration order causes circular dependency | Medium   | Medium | All repos are independent (no cross-repo deps). Register in any order.            |
| Dashboard decomposition breaks existing UI          | Medium     | Medium | Visual regression check after extraction. Keep `const` constructors.              |
| Notification batching changes observable behavior   | Low        | Low    | Existing tests validate end-state, not intermediate notifications.                |
| Isolate diagnostic logging imports fail             | Low        | Medium | `AppErrorHandler._logDiagnostic` uses only `debugPrint` — safe for all isolates. |
