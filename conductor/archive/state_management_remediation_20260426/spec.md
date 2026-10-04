# Specification: State Management Remediation (V2)

## 1. Overview
The goal of this track is to remediate state management leaks, crashes, and performance bottlenecks identified in the Audit Report. The application currently suffers from boilerplate duplication, disposal risks, race condition crashes, and rebuild anarchy across providers. This track will stabilize the architecture by introducing a safe foundation and purging these issues phase by phase.

## 2. Functional Requirements
- **Phase 1: Architectural Foundation (Safe Lifecycle)**
  - Implement a `SafeChangeNotifier` in `lib/core/state/safe_change_notifier.dart` with robust disposal logic and a microtask-wrapped `safeNotify()`.
  - Refactor all 10 providers to extend `SafeChangeNotifier`.
  - Purge manual `_isDisposed` fields and replace `notifyListeners` with `safeNotify()`.
- **Phase 2: Critical Stability & Resource Cleanup**
  - Fix the race condition in `AuthProvider._setStatus` by removing unguarded `notifyListeners()` within frame callbacks.
  - Cancel the `_fetchShieldTimer` in `WalletProvider.dispose()`.
- **Phase 3: Selective Rebuild Strategy (Performance)**
  - Remove high-level `context.watch<T>()` from screens (e.g., `login_landing_screen.dart`, `wallet_card.dart`).
  - Integrate `Selector<Provider, Value>` to restrict rebuilds to specific fields.
  - Optimize action-only reads via `context.read<T>()` or `listen: false`.
- **Phase 4: UX Responsiveness & State Purity**
  - Ensure `safeNotify()` is called immediately in `AuthProvider._setLoading()`.
  - Add state reset logic (`_errorMessage = null; safeNotify();`) at the start of all async actions in providers.
- **Phase 5: Dependency Injection & Event Bus**
  - Delete the global instance in `AppEvents`.
  - Register `AppEvents` as a `LazySingleton` in GetIt (`lib/core/di/service_locator.dart`).
  - Access the event bus exclusively via `sl<AppEvents>()`.

## 3. Non-Functional Requirements
- **Stability:** The app must be resilient to Hot Restarts and transitions during lifecycle changes without throwing `FlutterError`s for disposed providers.
- **Performance:** Redundant UI widget subtree rebuilds must be eliminated.
- **Maintainability:** Boilerplate for disposal and state notifications must be centralized.

## 4. Acceptance Criteria
- All providers are strictly using `SafeChangeNotifier` and `safeNotify()`.
- Critical `WalletProvider` background timers are cancelled on disposal.
- The UI properly uses `Selector` or `context.read<T>()` instead of over-using `context.watch<T>()`.
- Loading states and error messages instantly reflect the operation status and reset on retries.
- The `AppEvents` system runs through dependency injection, abandoning global singletons.
- Verification includes both automated tests to ensure logic works and manual UI verification for responsiveness.

## 5. Out of Scope
- Architectural changes beyond the identified Provider fixes (e.g., swapping Provider for Riverpod or Bloc).
- Adding new feature enhancements not related to fixing the identified State Management issues.