# Research: Master Architecture Refactor (002)

**Feature:** 002-master-arch-refactor
**Date:** 2026-04-14
**Status:** Complete

---

## R-01: Secondary Firebase Auth Context for Virtual Identity Provisioning

### Decision
Use `FirebaseAuth.instanceFor(app: secondaryApp)` with a secondary `FirebaseApp` initialized via `Firebase.initializeApp(name: 'employeeAuth', options: Firebase.app().options)` to create employee accounts without signing out the owner.

### Rationale
- Firebase Auth's `createUserWithEmailAndPassword()` **automatically signs in** the newly created user on the calling `FirebaseAuth` instance. Using a secondary app instance isolates this side-effect.
- The secondary app reuses the same Firebase project options—no additional Firebase project or configuration required.
- The secondary `FirebaseAuth` instance is completely independent from `FirebaseAuth.instance`, so the owner's session on the primary instance is never interrupted.
- This is the officially documented pattern for Firebase multi-auth scenarios.

### Alternatives Considered
| Alternative                         | Rejected Because                                                                 |
| ----------------------------------- | -------------------------------------------------------------------------------- |
| Cloud Function                     | Adds server-side dependency, latency, and cost. Out of scope for a client-only sprint. |
| Admin SDK                          | Not available in client-side Dart. Would require Cloud Functions.                 |
| Sign out / Sign in cycle           | Violates FR-01 (owner session must never be interrupted).                         |
| Firebase Anonymous Auth            | Cannot be used for email/password credential matching in future RBAC.             |

### Implementation Notes
- Initialize once in `EmployeeRepository` or a dedicated `IdentityService`.
- Dispose the secondary app after provisioning to avoid resource leaks.
- The secondary `FirebaseAuth` instance's `currentUser` after `createUserWithEmailAndPassword` gives us the `uid` to store on the employee record.

---

## R-02: `get_it` as DI Container

### Decision
Use `get_it` (v8.0+) as the centralized dependency injection container. It replaces the existing pattern of `SomeRepository()` direct instantiation.

### Rationale
- `get_it` is the most widely used DI container in the Flutter ecosystem (16M+ downloads).
- It provides `registerLazySingleton` which aligns with the current repository lifecycle (single instance per app lifetime).
- It is pure Dart — no code generation required (unlike `injectable`).
- It integrates cleanly with the existing `Provider` architecture: repositories are registered in `get_it`, then injected into providers via `GetIt.I<T>()`.
- It supports testing via `GetIt.I.reset()` and `registerSingleton` overrides.

### Alternatives Considered
| Alternative     | Rejected Because                                                                          |
| --------------- | ----------------------------------------------------------------------------------------- |
| `injectable`   | Requires `build_runner` code generation — adds build complexity for marginal benefit.      |
| `riverpod`     | Would require rewriting the entire state management layer. Out of scope.                   |
| Manual Service Locator | `get_it` IS a service locator, but battle-tested and with lifecycle management.     |

### Migration Path
1. Add `get_it` to `pubspec.yaml`.
2. Create `lib/core/di/service_locator.dart` with a `setupServiceLocator()` method.
3. Register all 12 repositories as lazy singletons.
4. Update `app.dart` provider constructors to pull from `GetIt.I<T>()` instead of `T()`.
5. Update individual providers that internally `new` their repos.

---

## R-03: Centralized Error Handler Architecture

### Decision
Create a single `AppErrorHandler` service class with static methods for 3 severity tiers, using the existing `bot_toast` dependency for toasts/banners.

### Rationale
- `bot_toast` (already in `pubspec.yaml`) supports toasts, notifications, and custom widgets — covers Low and Medium severity natively.
- Critical dialogs use Flutter's `showDialog` via the existing `NavigationService.navigatorKey` for context-free dialog display.
- A single `AppErrorHandler.handle(error, severity, context)` call replaces every silent catch.
- Structured logging to `debugPrint` with consistent format prepares for future Crashlytics integration.

### Error Severity Mapping
| Severity | UI Treatment | Example |
|----------|-------------|---------|
| Low      | `BotToast.showText()` — auto-dismiss 3s | Cache write failure, non-critical sync |
| Medium   | `BotToast.showNotification()` — persistent banner | Wallet save failure, transaction rollback |
| Critical | `showDialog()` via NavigatorKey — blocking | Auth failure, complete data corruption |

### Structured Log Format
```
[ERROR] [severity] [operation_context] message
  Stack: <trace>
  Timestamp: <ISO8601>
```

---

## R-04: Notification Batching Strategy

### Decision
Audit each provider's mutation paths and consolidate `notifyListeners()` calls to fire exactly once per logical operation.

### Rationale
- Current `WalletProvider` has **19** `notifyListeners()` calls. Many operations fire 2-3 times (status change + data change + status change).
- The pattern `_setStatus(loading) → mutate → _setStatus(loaded)` fires 2 notifications. Refactor to `_status = loading; mutate; _status = loaded; notifyListeners()`.
- The `_setStatus()` helper itself calls `notifyListeners()`. This must be changed to a private setter that does NOT notify, with notification deferred to the end of the operation.

### Current Hotspots (by file)
| Provider                 | Total `notifyListeners()` | Estimated Redundant |
|--------------------------|--------------------------|---------------------|
| `wallet_provider.dart`   | 19                       | ~10                 |
| `statistics_provider.dart` | 9                      | ~4                  |
| `subscription_provider.dart` | 7                    | ~3                  |
| `employee_provider.dart` | 5                        | ~2                  |
| `transaction_provider.dart` | 4                     | ~2                  |

---

## R-05: Dashboard Decomposition Target Architecture

### Decision
Extract `MainDashboardScreen` (746 lines) into 5 focused widget files under `lib/presentation/screens/home/widgets/`.

### Rationale
- The current file contains 5 distinct visual sections that have independent data dependencies.
- Decomposition enables per-component `Selector` subscriptions and reduces cognitive load.

### Target Components
| Component File               | Extracted From        | Lines (est.) | Provider Dependency                |
| ----------------------------- | --------------------- | ------------ | ---------------------------------- |
| `dashboard_welcome_header.dart` | `_buildWelcomeHeader` | ~40         | `AuthProvider` (fullName only)     |
| `dashboard_quick_stats.dart`  | `_buildQuickStats`    | ~180        | `StatisticsProvider` (summary)     |
| `dashboard_quick_actions.dart`| `_buildQuickActions`  | ~170        | `StatisticsProvider` (debts count) |
| `dashboard_alerts.dart`       | `_buildAlerts`        | ~100        | `WalletProvider` + `DebtProvider`  |
| `dashboard_recent_txns.dart`  | `_buildRecentTransactions` | ~80    | `TransactionProvider` (top 5)      |

---

## R-06: Residual Direct Data Calls in Providers

### Decision
Migrate the 2 remaining `FirebaseFirestore.instance` calls in providers to their respective repositories.

### Findings
| File                      | Line | Current Call                                                    | Migration Target           |
| ------------------------- | ---- | --------------------------------------------------------------- | -------------------------- |
| `wallet_provider.dart`    | 474  | `FirebaseFirestore.instance.collection('wallets').doc().id`     | `WalletRepository.generateId()` |
| `debt_provider.dart`      | 303  | `FirebaseFirestore.instance.collection('debts').doc().id`       | `DebtRepository.generateId()` |

### Silent Catches Inventory
| File                      | Line | Current Code       | Severity to Assign |
| ------------------------- | ---- | ------------------- | -------------------- |
| `wallet_provider.dart`    | 370  | `catch (e) {}`     | Low (cache write)    |
| `auth_provider.dart`      | 387  | `catch (e) {}`     | Low (cache write)    |
| `transaction_provider.dart`| 415-416 | `catch (e) {}`  | Low (local insert)   |
| `wallet_provider.dart`    | 156  | `catch (_) {}`     | N/A (legitimate stream guard) |
| `sms_processing_pipeline.dart` | 210 | `catch (_) {}`  | Low (logging only—isolate guard) |
| `background_service.dart` | 108  | `catch (_) {}`     | Low (logging only—isolate guard) |

**Note:** The isolate catches (SMS pipeline, background service) are legitimately swallowing errors to prevent isolate crashes. These must continue to swallow but should add diagnostic logging.
