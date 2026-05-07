# Specification: Performance Optimization (Phase 7)

## 1. Overview
A high-stakes performance refactoring track aimed at eliminating memory leaks, fixing UI jank, and optimizing state propagation across the Wallet Manager app. The primary focus to start will be **Memory Integrity**, followed by Rendering, State Management, and Tech Debt cleanup.

## 2. Refactoring Requirements
### 2.1 Memory Integrity & Listener Lifecycles
*   Convert widgets (e.g., `upgrade_screen.dart`) that instantiate `TextEditingController` into `StatefulWidget`s and dispose of controllers in `dispose()`.
*   Ensure every `TextEditingController`, `FocusNode`, and `ScrollController` globally is explicitly disposed of.
*   Refactor anonymous listeners (e.g., in `main_dashboard_screen.dart`) into named listeners and remove them in `dispose()`.
*   **Audit Method:** Automated Search and Static Analysis.

### 2.2 Rendering & Layout Efficiency
*   Replace nested `ListView`s with `shrinkWrap: true` using `CustomScrollView` and `SliverList.builder` (e.g., `manage_employees_screen.dart`).
*   Eliminate `Opacity` widgets, replacing them with alpha-adjusted colors (e.g., `Color.withAlpha()`).
*   Hoist repetitive provider lookups out of list builders to achieve O(1) lookups.
*   **Audit Method:** Automated Search.

### 2.3 State Management & UI Thread Optimization
*   Replace blanket `context.watch` at screen roots with granular `Selector`s or scoped `Consumer`s (e.g., `transaction_overlay_screen.dart`).
*   Eliminate synchronous Disk I/O (e.g., `SharedPreferences`) during operations like `submitTransaction`. Use pre-initialized `LocalStorageService`.
*   Remove unnecessary `Future.microtask` calls from `safeNotify()` in providers.
*   Fix P7-C-004: In `main_dashboard_screen.dart`, move provider initializations (`setStoreId`) from `didChangeDependencies` to `initState` using a `Future.microtask` and an initialization flag to prevent redundant re-fetches on screen rotation/theme changes.
*   Fix P7-M-006: In `OverlayProvider.notifyListeners()`, ensure that errors (`_errorMessage`) are NOT silently dropped by the `_blockAutoFetch` shield.

### 2.4 Tech Debt & L10n
*   Extract helper methods returning widgets into `const StatelessWidget` classes.
*   Replace hardcoded Arabic strings in providers with localization keys (`l10n`).
*   Cache `ThemeData` to avoid redundant object allocations.
*   Fix P7-M-007: In `main.dart`, add `AppErrorHandler.logSilentError` or `.handle()` to the `initializeBackgroundService` catch block so background startup failures reach Crashlytics.

## 3. Non-Functional Requirements
*   **Zero Memory Leaks:** Ensure proper disposal of all listeners and controllers.
*   **UI Thread Integrity:** No synchronous Disk I/O or redundant provider lookups in lists.
*   **Testing Constraints:** Must be verified on low-end Android devices (2GB-4GB RAM) to ensure no OOM crashes.

## 4. Acceptance Criteria
*   [ ] No `TextEditingController` is instantiated in a `StatelessWidget`.
*   [ ] Every listener added to a provider is removed in `dispose`.
*   [ ] `shrinkWrap: true` is removed from all category lists in favor of Slivers. (Verify smooth scrolling in "Manage Employees" screen).
*   [ ] `Opacity` widgets are replaced with Alpha-based colors.
*   [ ] `context.watch` at screen roots is replaced with `Selector` or scoped `Consumer`.
*   [ ] All `debugPrint` calls in providers are guarded by `kDebugMode`.
*   [ ] All hardcoded error strings in providers are moved to `l10n`.
*   [ ] Zero UI freezing occurs during the Overlay submission flow.
*   [ ] Redundant refetches on screen rotation in `main_dashboard_screen.dart` are eliminated.
*   [ ] OverlayProvider properly surfaces errors despite auto-fetch shields.
*   [ ] Background startup failures are logged to Crashlytics.

## 5. Out of Scope
*   Adding new features to the app.
*   Optimizing backend queries not explicitly related to the existing overlay constraints.