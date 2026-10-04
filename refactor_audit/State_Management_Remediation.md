# 🌊 State Management Remediation Plan - Phase-Based (V2)

**Architectural Role:** Senior Flutter Architect  
**Project:** WalletManager  
**Scope:** Remediation of State Management leaks, crashes, and performance bottlenecks identified in the Audit Report.

---

## Phase 1: Architectural Foundation (Safe Lifecycle)

### 🎯 The Problem (The "Why")
The current architecture suffers from **Boilerplate Duplication** and **Disposal Risks**. Each Provider manually implements `_isDisposed` and `_safeNotify`, leading to inconsistent safety checks. Crucially, `ThemeProvider` and `LocalizationProvider` completely lack disposal logic and `_isDisposed` flags, creating a high risk of `FlutterError` (using after disposal) if accessed during lifecycle transitions or hot restarts.

### 📜 The Execution (The "How")
1. **Create Base Class:** Define `lib/core/state/safe_change_notifier.dart`.
   - Inherit from `ChangeNotifier`.
   - Encapsulate a `bool _isDisposed = false` variable.
   - Override `dispose()` to set `_isDisposed = true` before calling `super.dispose()`.
   - Implement a `protected` method `safeNotify()` that checks `if (!_isDisposed && hasListeners)` and calls `notifyListeners()` inside a `Future.microtask()`.
2. **Refactor Providers:** Update ALL 10 providers (Auth, Wallet, Theme, Localization, etc.) to extend `SafeChangeNotifier` instead of `ChangeNotifier`.
3. **Purge Boilerplate:** Delete all manual `_isDisposed` fields and local `_safeNotify()` implementations from every provider file. Replace internal notification calls with the inherited `safeNotify()`.

---

## Phase 2: Critical Stability & Resource Cleanup

### 🎯 The Problem (The "Why")
There are two "App Killers" currently in the codebase:
1. **Race Condition Crash:** `AuthProvider._setStatus` schedules `notifyListeners()` inside an `addPostFrameCallback` without a disposal guard. If the provider is disposed before the next frame, the app crashes.
2. **Resource Leak:** `WalletProvider` creates a `_fetchShieldTimer` but fails to cancel it in `dispose()`, allowing background execution to persist wastefully after the provider is destroyed.

### 📜 The Execution (The "How")
1. **Auth Fix:** In `lib/providers/auth_provider.dart`, refactor `_setStatus()`. Remove the raw `notifyListeners()` call inside the frame callback and replace it strictly with `safeNotify()`.
2. **Timer Fix:** In `lib/providers/wallet_provider.dart`, locate the `dispose()` method. Add `_fetchShieldTimer?.cancel();` before the `super.dispose()` call.

---

## Phase 3: Selective Rebuild Strategy (Performance)

### 🎯 The Problem (The "Why")
The UI suffers from **Rebuild Anarchy**. Using `context.watch<T>()` at the top of screen `build` methods (e.g., in `login_landing_screen.dart` and `wallet_card.dart`) forces massive widget subtrees to rebuild on *any* change in the provider, even if the data being displayed hasn't changed.

### 📜 The Execution (The "How")
1. **The Watch Purge:** Locate and remove high-level `context.watch<T>()` calls in UI screens and cards.
2. **Selector Integration:** Replace them with `Selector<Provider, Value>` to isolate rebuilds to specific fields (e.g., watching only `isLoading` or `walletList`).
3. **Read Optimization:** Convert `Provider.of<T>(context)` calls that are only used for actions (like `onPressed`) to `context.read<T>()` or `listen: false` to stop invisible rebuilds.

---

## Phase 4: UX Responsiveness & State Purity

### 🎯 The Problem (The "Why")
1. **Loading Blindness:** `AuthProvider._setLoading(true)` does not notify listeners, causing a delay in showing the loading spinner to the user.
2. **Stale Errors:** Providers (Wallet, Transaction, Debt, Auth) do not consistently clear `_errorMessage` before starting new operations, potentially showing old error messages during a retry.

### 📜 The Execution (The "How")
1. **Immediate Feedback:** Update `AuthProvider._setLoading()` to call `safeNotify()` immediately so the UI reflects the loading state instantly.
2. **State Reset:** For every async action in all Providers (e.g., `login`, `fetchData`), add `_errorMessage = null;` and `safeNotify();` as the very first lines of the method to ensure a clean UI state before the work begins.

---

## Phase 5: Dependency Injection & Event Bus

### 🎯 The Problem (The "Why")
The `AppEvents` system is implemented as a **Global Singleton**, making unit testing impossible and creating a lifecycle "orphan" that is never disposed. It also creates a parallel, competing notification system alongside Provider.

### 📜 The Execution (The "How")
1. **DI Migration:** Delete the global instance `final appEvents = AppEvents();` in `lib/providers/app_events.dart`.
2. **GetIt Registration:** Register `AppEvents` as a `LazySingleton` in `lib/core/di/service_locator.dart`.
3. **Usage Update:** Update all parts of the app to access the event bus via `sl<AppEvents>()` instead of the global variable.

---