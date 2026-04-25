# Implementation Plan: State Management Remediation (V2)

## Phase 1: Architectural Foundation (Safe Lifecycle) [checkpoint: e841129]
- [x] Task: Create `SafeChangeNotifier` base class (cace69f)
    - [x] Create `lib/core/state/safe_change_notifier.dart`
    - [x] Implement `SafeChangeNotifier` inheriting from `ChangeNotifier`
    - [x] Encapsulate `bool _isDisposed = false`
    - [x] Override `dispose()` setting `_isDisposed = true` before `super.dispose()`
    - [x] Implement `protected` method `safeNotify()` using `Future.microtask()` checking `!_isDisposed && hasListeners`
    - [x] Write unit tests for `SafeChangeNotifier`
- [x] Task: Refactor Providers to extend `SafeChangeNotifier` (829ee69)
    - [x] Update `AuthProvider`
    - [x] Update `WalletProvider`
    - [x] Update `ThemeProvider`
    - [x] Update `LocalizationProvider`
    - [x] Update `TransactionProvider`
    - [x] Update `DebtProvider`
    - [x] Update `EmployeeProvider`
    - [x] Update `StatisticsProvider`
    - [x] Update `SubscriptionProvider`
    - [x] Update `SystemConfigProvider`
    - [x] Purge manual `_isDisposed` fields from all providers
    - [x] Replace `notifyListeners()` with `safeNotify()` in all providers
    - [x] Run tests for all modified providers
- [x] Task: Conductor - User Manual Verification 'Phase 1: Architectural Foundation (Safe Lifecycle)' (Protocol in workflow.md) (e841129)

## Phase 2: Critical Stability & Resource Cleanup
- [x] Task: Fix race condition in `AuthProvider` (733677a)
    - [x] Locate `_setStatus()` in `lib/providers/auth_provider.dart`
    - [x] Remove `notifyListeners()` from `addPostFrameCallback`
    - [x] Replace with `safeNotify()` directly
    - [x] Add unit test verifying `_setStatus()`
- [ ] Task: Fix resource leak in `WalletProvider`
    - [ ] Locate `dispose()` in `lib/providers/wallet_provider.dart`
    - [ ] Add `_fetchShieldTimer?.cancel();` before `super.dispose()`
    - [ ] Add unit test verifying `WalletProvider` disposal
- [ ] Task: Conductor - User Manual Verification 'Phase 2: Critical Stability & Resource Cleanup' (Protocol in workflow.md)

## Phase 3: Selective Rebuild Strategy (Performance)
- [ ] Task: Purge `context.watch<T>()` from screens
    - [ ] Refactor `lib/presentation/screens/login_landing_screen.dart` to remove high-level `watch`
    - [ ] Refactor `lib/presentation/widgets/wallet_card.dart` to remove high-level `watch`
    - [ ] Identify and refactor other high-level `watch` usages in the presentation layer
- [ ] Task: Integrate `Selector` and `context.read<T>()`
    - [ ] Replace `watch` with `Selector<Provider, Value>` where targeted rebuilds are needed
    - [ ] Replace `Provider.of<T>(context)` action calls with `context.read<T>()` or `listen: false`
    - [ ] Verify UI tests or widget tests still pass
- [ ] Task: Conductor - User Manual Verification 'Phase 3: Selective Rebuild Strategy (Performance)' (Protocol in workflow.md)

## Phase 4: UX Responsiveness & State Purity
- [ ] Task: Immediate loading feedback in `AuthProvider`
    - [ ] Update `_setLoading()` to call `safeNotify()` immediately
    - [ ] Verify loading state updates instantly in tests
- [ ] Task: State reset in async actions
    - [ ] Add `_errorMessage = null; safeNotify();` to start of async actions in `WalletProvider`
    - [ ] Add `_errorMessage = null; safeNotify();` to start of async actions in `TransactionProvider`
    - [ ] Add `_errorMessage = null; safeNotify();` to start of async actions in `DebtProvider`
    - [ ] Add `_errorMessage = null; safeNotify();` to start of async actions in `AuthProvider`
    - [ ] Add unit tests verifying error reset logic
- [ ] Task: Conductor - User Manual Verification 'Phase 4: UX Responsiveness & State Purity' (Protocol in workflow.md)

## Phase 5: Dependency Injection & Event Bus
- [ ] Task: Migrate `AppEvents` to Dependency Injection
    - [ ] Delete global `appEvents` instance in `lib/providers/app_events.dart`
    - [ ] Register `AppEvents` as `LazySingleton` in `lib/core/di/service_locator.dart`
    - [ ] Refactor all files referencing `appEvents` to use `sl<AppEvents>()`
    - [ ] Run app-wide tests to verify event bus communication
- [ ] Task: Conductor - User Manual Verification 'Phase 5: Dependency Injection & Event Bus' (Protocol in workflow.md)