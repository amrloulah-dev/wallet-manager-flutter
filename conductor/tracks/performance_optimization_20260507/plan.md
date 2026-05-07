# Implementation Plan: Performance Optimization (Phase 7)

## Phase 1: Memory Integrity & Listener Lifecycles
- [x] Task: Convert `upgrade_screen.dart` to `StatefulWidget` and dispose `keyController`. 273b474
- [x] Task: Global Audit - Search and fix any `TextEditingController`, `FocusNode`, or `ScrollController` instantiated in `StatelessWidget`s. 76aa9ac
- [x] Task: Write tests to ensure listeners are registered and unregistered correctly in `main_dashboard_screen.dart` (if testable). 158c71d
- [x] Task: Implement named listeners in `main_dashboard_screen.dart` and remove anonymous listener usage. 158c71d
- [x] Task: Global Audit - Search and verify corresponding `removeListener` for every `.addListener` usage across the app. 9b1a410
- [x] Task: Conductor - User Manual Verification 'Memory Integrity & Listener Lifecycles' (Protocol in workflow.md)

## Phase 2: Rendering & Layout Efficiency
- [x] Task: Write UI tests to verify Sliver layout structure in `manage_employees_screen.dart`. ac69a3e
- [x] Task: Replace nested `ListView` (with `shrinkWrap: true`) with `CustomScrollView` and `SliverList.builder` in `manage_employees_screen.dart`. ac69a3e
- [x] Task: Global Audit - Replace `shrinkWrap: true` instances globally with Slivers. 7f98022
- [x] Task: Global Audit - Replace `Opacity` widgets with `Color.withAlpha()` / `Color.withOpacity()` in `wallet_card.dart`, `employee_card.dart`, and globally. 7f98022
- [x] Task: Hoist `context.read<EmployeeProvider>()` outside the `itemBuilder` in `manage_employees_screen.dart`. 7f98022
- [x] Task: Conductor - User Manual Verification 'Rendering & Layout Efficiency' (Protocol in workflow.md)

## Phase 3: State Management & UI Thread Optimization
- [x] Task: Write tests for provider initialization logic in `main_dashboard_screen.dart` to verify re-fetches are avoided on rebuilds. 158c71d
- [x] Task: Move provider initializations (`setStoreId`) from `didChangeDependencies` to `initState` using `Future.microtask` and an initialization flag in `main_dashboard_screen.dart`. 158c71d
- [~] Task: Write tests for `OverlayProvider.notifyListeners()` ensuring `_errorMessage` is propagated correctly.
- [ ] Task: Fix `OverlayProvider.notifyListeners()` to ensure that errors (`_errorMessage`) are NOT silently dropped by the `_blockAutoFetch` shield.
- [ ] Task: Write widget tests for `transaction_overlay_screen.dart` to verify isolated rebuilds via `Selector`.
- [ ] Task: Replace `context.watch<OverlayProvider>()` with granular `Selector`s in `transaction_overlay_screen.dart`.
- [ ] Task: Apply `Selector` or scoped `Consumer` refactoring to `CreateTransactionScreen` and `AddDebtScreen`.
- [ ] Task: Ensure `SharedPreferences` is not fetched during `submitTransaction` in `overlay_provider.dart`. Ensure `LocalStorageService` is used instead.
- [ ] Task: Remove unnecessary `Future.microtask` calls from `_safeNotify()` in `WalletProvider` and `StatisticsProvider`.
- [ ] Task: Conductor - User Manual Verification 'State Management & UI Thread Optimization' (Protocol in workflow.md)

## Phase 4: Tech Debt & L10n
- [ ] Task: Write tests verifying background startup failures are logged.
- [ ] Task: Add `AppErrorHandler.logSilentError` or `.handle()` to the `initializeBackgroundService` catch block in `main.dart` so background startup failures reach Crashlytics.
- [ ] Task: Write widget tests for `_StatItemWidget` ensuring it renders correctly independently.
- [ ] Task: Convert `_StatItemWidget` in `general_statistics_screen.dart` to a `const StatelessWidget`.
- [ ] Task: Global Audit - Scan for private helper methods returning Widgets and convert them to `StatelessWidget`s.
- [ ] Task: Replace hardcoded Arabic error strings in `statistics_provider.dart` with `l10n` localization keys.
- [ ] Task: Cache `ThemeData.light()` as a `static final` constant in `transaction_overlay_screen.dart`.
- [ ] Task: Conductor - User Manual Verification 'Tech Debt & L10n' (Protocol in workflow.md)