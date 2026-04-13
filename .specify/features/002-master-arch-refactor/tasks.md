# Tasks: Master Architecture Refactor (002)

**Feature:** 002-master-arch-refactor
**Plan:** [plan.md](file:///c:/src/walletmanager/.specify/features/002-master-arch-refactor/plan.md)
**Spec:** [spec.md](file:///c:/src/walletmanager/.specify/features/002-master-arch-refactor/spec.md)
**Generated:** 2026-04-14

---

## Phase 1: Setup

> Project-wide prerequisites that unblock all subsequent phases.

- [x] T001 Read and internalize all 7 constitution principles in `.specify/memory/constitution.md` before writing any code
- [x] T002 Create feature branch `feature/002-master-arch-refactor` from current main

---

## Phase 2: Foundational — Error Infrastructure

> Blocking prerequisite: the centralized error handler must exist before any Phase 3+ task can route errors through it. Built first so Phases 3-5 can consume it immediately.

**Goal:** Establish the centralized error handling service that all subsequent phases will use.

**Independent Test Criteria:**
- `AppErrorHandler.handle()` routes Low → toast, Medium → banner, Critical → dialog
- `_logDiagnostic()` emits structured log with severity, context, timestamp, stack trace
- `ErrorSeverity` enum has exactly 3 values: `low`, `medium`, `critical`

### Tasks

- [x] T003 [P] Create `ErrorSeverity` enum in `lib/core/errors/error_severity.dart` with values: `low`, `medium`, `critical`
- [x] T004 Create `AppErrorHandler` class in `lib/core/errors/app_error_handler.dart` with static `handle()` method routing to `BotToast.showText()` for Low, `BotToast.showNotification()` for Medium, and `showDialog()` via `NavigationService.navigatorKey` for Critical severity. Include private `_logDiagnostic()` method that writes structured logs via `debugPrint` in format: `[ERROR] [severity] [operation] message\n  Stack: <trace>\n  Timestamp: <ISO8601>`
- [x] T005 Create unit tests in `test/core/errors/app_error_handler_test.dart` verifying: Low→toast, Medium→banner, Critical→dialog routing, and that `_logDiagnostic` always fires regardless of severity

---

## Phase 3: Security & Identity (US-01, US-02)

> **Spec Stories:** US-01 (Independent Employee Identity), US-02 (Employee Login with Own Identity)
> **Plan Section:** Phase 1
> **Depends on:** Phase 2 (error handler must exist for failure logging)

**Goal:** Provision virtual Firebase Auth identities for employees using a secondary auth context, and authenticate employees against their own identity on login.

**Independent Test Criteria:**
- Creating an employee populates `firebaseUid` on the employee record
- Owner's `FirebaseAuth.instance.currentUser` is unchanged after provisioning
- Employee login with correct PIN resolves to employee's own UID
- Employee login with wrong PIN shows user-visible error (not silent failure)
- PIN change triggers background credential sync
- Employee deletion triggers best-effort identity cleanup

### Tasks

#### Identity Service

- [x] T006 Create `IdentityService` class in `lib/core/services/identity_service.dart` with static methods: `_ensureInitialized()` (lazy-init secondary `FirebaseApp` via `Firebase.initializeApp(name: 'employeeAuth', options: Firebase.app().options)`), `provisionIdentity({phone, storeId, pin})` → `String?` UID, `updateCredential({phone, storeId, newPin})` → `bool`, `deleteIdentity({phone, storeId})` → `bool`, `authenticateEmployee({phone, storeId, pin})` → `String?` UID. Email format: `emp_<phone>_<storeId>@store.com`. All methods must catch errors and return null/false on failure (never throw). Log failures via `AppErrorHandler.handle()` at Low severity with operation context.

#### Employee Model

- [x] T007 [P] [US-01] Add nullable `String? firebaseUid` field to `EmployeeModel` in `lib/data/models/employee_model.dart` — update constructor, `toFirestore()`, `fromFirestore()`, and `copyWith()`. Default to `null` for backward compatibility.

#### Employee Repository

- [x] T008 [US-01] Add `provisionIdentity(EmployeeModel employee)` method to `EmployeeRepository` in `lib/data/repositories/employee_repository.dart` — calls `IdentityService.provisionIdentity()`, then updates the employee's Firestore document with the returned `firebaseUid`. Fire-and-forget async, log failure via `AppErrorHandler`.
- [x] T009 [P] [US-01] Add `syncCredential(EmployeeModel employee, String newPin)` method to `EmployeeRepository` in `lib/data/repositories/employee_repository.dart` — calls `IdentityService.updateCredential()`. Fire-and-forget async, log failure via `AppErrorHandler`.
- [x] T010 [P] [US-01] Add `cleanupIdentity(EmployeeModel employee)` method to `EmployeeRepository` in `lib/data/repositories/employee_repository.dart` — calls `IdentityService.deleteIdentity()`. Best-effort: log failure but never block the caller.

#### Employee Provider Orchestration

- [x] T011 [US-01] Update `addEmployee()` in `EmployeeProvider` (`lib/providers/employee_provider.dart`) to call `_employeeRepository.provisionIdentity(employee)` after successful local save + Firestore write. The provisioning call must be non-blocking (fire-and-forget with error logging).
- [x] T012 [US-01] Update PIN change method in `EmployeeProvider` (`lib/providers/employee_provider.dart`) to call `_employeeRepository.syncCredential(employee, newPin)` after successful PIN update. Non-blocking.
- [x] T013 [US-01] Update `deleteEmployee()` in `EmployeeProvider` (`lib/providers/employee_provider.dart`) to call `_employeeRepository.cleanupIdentity(employee)` after successful deletion. Non-blocking, best-effort.

#### Employee Authentication

- [x] T014 [US-02] Update employee login path in `AuthProvider` (`lib/providers/auth_provider.dart`): if `employee.firebaseUid != null`, authenticate via `IdentityService.authenticateEmployee()` and set session with employee's own UID. On failure, fall back to existing local PIN verification. If `employee.firebaseUid == null`, use existing local PIN check and attempt lazy provisioning in background.
- [x] T015 [US-02] Ensure all employee authentication failures in `AuthProvider` route through `AppErrorHandler.handle()` at Critical severity with Arabic error messages — no silent catches on the login path.

#### Tests

- [x] T016 [P] [US-01] Create unit tests in `test/core/services/identity_service_test.dart`: provision creates user on secondary auth, provision does not sign out primary auth, duplicate email returns existing UID, update credential changes password, delete identity removes user
- [x] T017 [P] [US-02] Create unit tests in `test/providers/employee_provider_identity_test.dart`: addEmployee provisions identity on success, addEmployee succeeds even if provisioning fails, deleteEmployee cleans up identity, updatePin syncs credential
- [x] T018 [US-02] Create unit tests in `test/providers/auth_provider_employee_login_test.dart`: employee login with firebaseUid authenticates via IdentityService, employee login without firebaseUid falls back to local PIN, failed login shows user-visible error

---

## Phase 4: Error Handling Sweep (US-03, US-04)

> **Spec Stories:** US-03 (Visible Error Feedback), US-04 (SMS Processing Resilience)
> **Plan Section:** Phase 2
> **Depends on:** Phase 2 (error handler), Phase 3 (identity errors already use handler)

**Goal:** Replace every remaining silent catch in the codebase with severity-routed error handling. Add diagnostic logging to SMS pipeline catches.

**Independent Test Criteria:**
- Zero `catch (e) {}` or `catch (_) {}` blocks remain that don't route through `AppErrorHandler` or log diagnostics
- All user-facing errors display Arabic messages
- SMS pipeline logs diagnostic info on parse failure but continues processing
- No stuck loading spinners — all async operations clear loading state in `finally`

### Tasks

#### Provider Error Remediation

- [ ] T019 [US-03] Audit and remediate all silent catches in `WalletProvider` (`lib/providers/wallet_provider.dart`): replace `catch (e) {}` at line ~370 with `AppErrorHandler.handle(e, severity: ErrorSeverity.low, operation: 'wallet_cache_write')`. Audit all `_setError()` calls to also route through `AppErrorHandler.handle()` at Medium severity. Skip line 156 (`catch (_)` — legitimate stream guard). Ensure all error messages are Arabic.
- [ ] T020 [P] [US-03] Audit and remediate all silent catches in `AuthProvider` (`lib/providers/auth_provider.dart`): route login failures through `AppErrorHandler` at Critical severity, auto-login failures at Medium, cache write failures at Low. All messages Arabic.
- [ ] T021 [P] [US-03] Audit and remediate silent catch in `TransactionProvider` (`lib/providers/transaction_provider.dart`): replace `catch (e) {}` at lines 415-416 in `insertTransactionLocally()` with `AppErrorHandler.handle(e, severity: ErrorSeverity.low, operation: 'transaction_local_insert')`. Audit remaining catch blocks.
- [ ] T022 [P] [US-03] Audit and remediate all silent catches in `EmployeeProvider` (`lib/providers/employee_provider.dart`): route all errors through `AppErrorHandler` with appropriate severity levels and Arabic messages.
- [ ] T023 [P] [US-03] Audit and remediate all silent catches in `DebtProvider` (`lib/providers/debt_provider.dart`): route all errors through `AppErrorHandler` with appropriate severity levels and Arabic messages.
- [ ] T024 [P] [US-03] Audit and remediate all silent catches in `StatisticsProvider` (`lib/providers/statistics_provider.dart`): route all errors through `AppErrorHandler` with appropriate severity levels.
- [ ] T025 [P] [US-03] Audit and remediate all silent catches in `SubscriptionProvider` (`lib/providers/subscription_provider.dart`): route all errors through `AppErrorHandler` with appropriate severity levels.

#### SMS Pipeline Error Isolation

- [ ] T026 [US-04] Add structured diagnostic logging inside the top-level `catch (_)` in `handleIncomingSms()` in `lib/core/services/sms_processing_pipeline.dart` (line 210). Use `debugPrint` with structured format: `[ERROR] [low] [sms_pipeline] $error`. Continue swallowing the error — isolate must not crash.
- [ ] T027 [P] [US-04] Add structured diagnostic logging inside the `catch (_)` in `_backgroundSmsCallback()` in `lib/core/services/background_service.dart` (line 108). Same format as T026. Continue swallowing.

#### Loading State Consistency

- [ ] T028 [US-03] Audit all providers for loading state consistency (FR-05): ensure every async operation that sets a loading status clears it in a `finally` block. Pattern: `if (_status == SomeStatus.loading) { _status = SomeStatus.idle; }` in `finally`. Apply to `WalletProvider`, `TransactionProvider`, `DebtProvider`, `EmployeeProvider`, `StatisticsProvider`, `SubscriptionProvider`.

#### Verification

- [ ] T029 Run `grep -r "catch.*{}" lib/providers/` and `grep -r "catch (_)" lib/` to verify zero silent catches remain (except documented SMS isolate guards which now log diagnostics). Document any remaining legitimate guards.

---

## Phase 5: Architecture & Dependency Injection (US-05)

> **Spec Story:** US-05 (Modular, Testable Business Logic)
> **Plan Section:** Phase 3
> **Depends on:** Phase 4 (all error handling in place so DI migration errors are visible)

**Goal:** Register all 12 repositories in a `get_it` DI container, eliminate residual direct Firestore calls in providers, and decompose the dashboard into focused components.

**Independent Test Criteria:**
- `setupServiceLocator()` registers all 12 repositories as lazy singletons
- `sl<T>()` returns the same instance on repeated calls
- `app.dart` no longer contains any `Repository()` direct instantiation
- `grep "FirebaseFirestore.instance" lib/providers/` returns zero results
- Dashboard renders correctly with 5 extracted component files
- `MainDashboardScreen` is ≤150 lines (composition root only)

### Tasks

#### DI Container Setup

- [ ] T030 [US-05] Add `get_it: ^8.0.3` to `dependencies` in `pubspec.yaml` and run `flutter pub get`
- [ ] T031 [US-05] Create `lib/core/di/service_locator.dart` with `final GetIt sl = GetIt.instance;` and `Future<void> setupServiceLocator()` that registers all 12 repositories as lazy singletons: `AuthRepository`, `WalletRepository`, `TransactionRepository`, `DebtRepository`, `EmployeeRepository`, `StoreRepository`, `StatsRepository`, `SubscriptionRepository`, `SystemConfigRepository`, `DeviceRepository`, `LicenseKeyRepository`, `UserRepository`
- [ ] T032 [US-05] Update `lib/main.dart` to call `await setupServiceLocator()` before `runApp()`

#### Provider Constructor Migration

- [ ] T033 [US-05] Update `lib/app.dart` MultiProvider: replace all direct `Repository()` instantiations with `sl<Repository>()` lookups. Targets: `EmployeeRepository()` (lines 56, 58), `WalletRepository()` (lines 68, 73), `DebtRepository()` (lines 80, 83), `TransactionRepository()` (line 93), `StatsRepository()` (line 95), `SystemConfigRepository()` (line 46). Also fix `update:` callbacks that re-instantiate repositories — these must reuse the existing provider instance, not create new repos.

#### Residual Firestore Call Elimination

- [ ] T034 [P] [US-05] Add `String generateId()` method to `WalletRepository` in `lib/data/repositories/wallet_repository.dart` returning `walletsCollection.doc().id`. Update `WalletProvider` (`lib/providers/wallet_provider.dart` line 474) to replace `FirebaseFirestore.instance.collection('wallets').doc().id` with `_walletRepository.generateId()`.
- [ ] T035 [P] [US-05] Add `String generateId()` method to `DebtRepository` in `lib/data/repositories/debt_repository.dart` returning `debtsCollection.doc().id`. Update `DebtProvider` (`lib/providers/debt_provider.dart` line 303) to replace `FirebaseFirestore.instance.collection('debts').doc().id` with `_debtRepository.generateId()`.

#### Dashboard Decomposition

- [ ] T036 [P] [US-05] Extract `_buildWelcomeHeader()` from `MainDashboardScreen` into `lib/presentation/screens/home/widgets/dashboard_welcome_header.dart` as a `StatelessWidget`. Subscribe to `AuthProvider` via `Selector<AuthProvider, String>` for `fullName` only.
- [ ] T037 [P] [US-05] Extract statistics card section from `MainDashboardScreen` into `lib/presentation/screens/home/widgets/dashboard_quick_stats.dart` as a `StatelessWidget`. Subscribe to `StatisticsProvider` via `Selector` for summary map data.
- [ ] T038 [P] [US-05] Extract quick-action buttons from `MainDashboardScreen` into `lib/presentation/screens/home/widgets/dashboard_quick_actions.dart` as a `StatelessWidget`. Subscribe to `StatisticsProvider` via `Selector` for pending debts count (badge).
- [ ] T039 [P] [US-05] Extract alerts section from `MainDashboardScreen` into `lib/presentation/screens/home/widgets/dashboard_alerts.dart` as a `StatelessWidget`. Subscribe to `WalletProvider` + `DebtProvider` via `Selector2` for alert counts.
- [ ] T040 [P] [US-05] Extract recent transactions list from `MainDashboardScreen` into `lib/presentation/screens/home/widgets/dashboard_recent_txns.dart` as a `StatelessWidget`. Subscribe to `TransactionProvider` via `Selector` for `todayTransactions`.
- [ ] T041 [US-05] Refactor `MainDashboardScreen` in `lib/presentation/screens/home/main_dashboard_screen.dart` to be a composition root (~100-150 lines) that assembles the 5 extracted components. Remove all extracted build methods. Verify the screen renders correctly.

#### Tests

- [ ] T042 [P] [US-05] Create unit tests in `test/core/di/service_locator_test.dart`: `setupServiceLocator` registers all 12 repos, `sl<T>()` returns same singleton instance on repeated calls
- [ ] T043 [US-05] Run `flutter analyze` and `flutter test` to verify zero errors after DI migration and dashboard decomposition

---

## Phase 6: Performance Tuning (US-06)

> **Spec Story:** US-06 (Jank-Free Dashboard & Wallet Browsing)
> **Plan Section:** Phase 4
> **Depends on:** Phase 5 (dashboard decomposed, DI in place, modular components ready for Selector optimization)

**Goal:** Batch `notifyListeners()` calls to fire at most once per operation upon all providers, and verify all dashboard components use targeted `Selector` subscriptions.

**Independent Test Criteria:**
- `createWallet()` fires exactly 1 `notifyListeners()` call (not 2-3)
- `fetchInitialTransactions()` fires exactly 1 `notifyListeners()` call
- Each dashboard component rebuilds independently (DevTools rebuild count)
- Wallet list scrolls at 60fps with 30+ items on mid-range device

### Tasks

#### Notification Batching

- [ ] T044 [US-06] Refactor `WalletProvider` (`lib/providers/wallet_provider.dart`): replace `_setStatus()` helper (which calls `notifyListeners()`) with a private `_updateStatus()` that only sets the field. Move all `notifyListeners()` calls to fire exactly once at the end of each public method (in `finally` block via `_safeNotify()`). Target: reduce from ~19 to ~9 notification calls.
- [ ] T045 [P] [US-06] Refactor `TransactionProvider` (`lib/providers/transaction_provider.dart`): same pattern — replace `_setStatus()`/`_setError()` with non-notifying setters, add single `_safeNotify()` at end of each operation.
- [ ] T046 [P] [US-06] Refactor `StatisticsProvider` (`lib/providers/statistics_provider.dart`): same notification batching pattern. Target: reduce from ~9 to ~5 notification calls.
- [ ] T047 [P] [US-06] Refactor `SubscriptionProvider` (`lib/providers/subscription_provider.dart`): same notification batching pattern. Target: reduce from ~7 to ~4 notification calls.
- [ ] T048 [P] [US-06] Refactor `EmployeeProvider` (`lib/providers/employee_provider.dart`): same notification batching pattern. Target: reduce from ~5 to ~3 notification calls.
- [ ] T049 [P] [US-06] Refactor `DebtProvider` (`lib/providers/debt_provider.dart`): same notification batching pattern.
- [ ] T050 [P] [US-06] Refactor `AuthProvider` (`lib/providers/auth_provider.dart`): same notification batching pattern. Be extra careful with the login/logout flows — ensure single notification after all state mutations complete.

#### Targeted UI Rebuild Verification

- [ ] T051 [US-06] Verify all 5 dashboard components (from Phase 5) use `Selector` (not `Consumer` or `context.watch`). Fix any that don't. Each component must rebuild ONLY when its specific data field changes.
- [ ] T052 [US-06] Audit wallet list screen for root-level `Consumer<WalletProvider>` or `context.watch<WalletProvider>()`. Replace with `Selector<WalletProvider, (List<WalletModel>, WalletStatus)>` subscribing only to `wallets` list and `status`.

#### Tests & Verification

- [ ] T053 [P] [US-06] Create notification batching tests in `test/providers/notification_batching_test.dart`: verify `createWallet` fires exactly 1 `notifyListeners()`, `fetchWallets` fires exactly 1, `createTransaction` fires exactly 1, error path fires exactly 1
- [ ] T054 [US-06] Run `flutter analyze` to verify zero errors after batching refactor
- [ ] T055 [US-06] Run full test suite: `flutter test` — all tests must pass

---

## Phase 7: Polish & Cross-Cutting Verification

> Final verification sweep to confirm all success criteria are met.

- [ ] T056 Run `flutter analyze` — must report zero errors and zero warnings
- [ ] T057 Run `flutter test` — all tests must pass (zero failures)
- [ ] T058 Verify Success Criterion 4: run `grep -rn "catch.*{}" lib/providers/` — must return zero results (no silent catches in providers)
- [ ] T059 Verify Success Criterion 7: run `grep -rn "FirebaseFirestore.instance" lib/providers/` — must return zero results (no direct Firestore calls in providers)
- [ ] T060 Verify Success Criterion 8: count files in `lib/presentation/screens/home/widgets/` — must contain ≥4 dashboard component files
- [ ] T061 Verify `MainDashboardScreen` line count — must be ≤150 lines (composition root only)
- [ ] T062 Manual verification: create an employee → confirm `firebaseUid` field appears in Firestore document
- [ ] T063 Manual verification: force a wallet save error → confirm Arabic error banner appears
- [ ] T064 Manual verification: scroll dashboard and wallet list → confirm smooth 60fps, no visible jank

---

## Dependency Graph

```
Phase 1: Setup
    │
    ▼
Phase 2: Error Infrastructure (T003-T005)
    │
    ▼
Phase 3: Security & Identity (T006-T018)  ──── US-01, US-02
    │
    ▼
Phase 4: Error Handling Sweep (T019-T029)  ──── US-03, US-04
    │
    ▼
Phase 5: Architecture & DI (T030-T043)    ──── US-05
    │
    ▼
Phase 6: Performance Tuning (T044-T055)   ──── US-06
    │
    ▼
Phase 7: Polish & Verification (T056-T064)
```

**Strict sequential execution**: No phase may begin until its predecessor is fully complete and verified per the spec's execution strategy.

## Parallel Execution Opportunities

Within each phase, tasks marked `[P]` can be executed in parallel:

| Phase | Parallel Tasks | Parallelizable |
|-------|---------------|----------------|
| 2     | T003 ∥ (then T004, T005) | 1 of 3 |
| 3     | T007 ∥ T009 ∥ T010 ∥ T016 ∥ T017 | 5 of 13 |
| 4     | T020 ∥ T021 ∥ T022 ∥ T023 ∥ T024 ∥ T025 ∥ T027 | 7 of 11 |
| 5     | T034 ∥ T035 ∥ T036 ∥ T037 ∥ T038 ∥ T039 ∥ T040 ∥ T042 | 8 of 14 |
| 6     | T045 ∥ T046 ∥ T047 ∥ T048 ∥ T049 ∥ T050 ∥ T053 | 7 of 12 |

## Implementation Strategy

**MVP Scope:** Phase 2 + Phase 3 (Error Infrastructure + Security & Identity)
- Delivers the highest-value changes first: employee identity provisioning + visible error feedback
- Unblocks future RBAC work immediately
- All subsequent phases build safely on this foundation

**Incremental Delivery:** Each phase produces a fully functional, deployable application. No phase leaves the app in a broken state.

---

## Summary

| Metric                          | Value |
| ------------------------------- | ----- |
| **Total Tasks**                 | 64    |
| **Phase 1 (Setup)**            | 2     |
| **Phase 2 (Error Infra)**      | 3     |
| **Phase 3 (Security/Identity)**| 13    |
| **Phase 4 (Error Sweep)**      | 11    |
| **Phase 5 (Architecture/DI)**  | 14    |
| **Phase 6 (Performance)**      | 12    |
| **Phase 7 (Polish)**           | 9     |
| **Parallelizable Tasks**       | 28 (44%) |
| **User Stories Covered**        | US-01 through US-06 (100%) |
| **Format Validated**            | ✅ All tasks follow `- [ ] [ID] [P?] [US?] description with file path` |
