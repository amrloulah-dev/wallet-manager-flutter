# 🚀 Wallet Manager - Performance & Optimization Master Blueprint (Phase 7)

## 📌 1. General Context & Strict System Prompt
**To the AI Agent (Antigravity / Gemini CLI):**
You are performing a high-stakes performance refactoring for "Wallet Manager". The goal is to eliminate memory leaks, fix UI jank, and optimize state propagation. 
**Core Constraints:**
1. **Zero Memory Leaks:** Every controller and listener MUST be disposed of.
2. **UI Thread Integrity:** No synchronous Disk I/O or redundant provider lookups in lists.
3. **GLOBAL AUDIT DIRECTIVE:** For every issue fixed, you MUST scan the entire `lib/` directory for the same anti-pattern and apply the fix globally.

---

## 📌 2. CRITICAL: Memory Integrity & Listener Lifecycles (Axis 1)

### Context
Static analysis identified severe memory leaks due to `TextEditingController` being instantiated in `StatelessWidget` and anonymous listeners being attached to global providers without removal.

### The Fix (Surgical + Global Audit)
1. **Controller Lifecycle:** In `lib/presentation/screens/settings/upgrade_screen.dart`, convert the widget to a `StatefulWidget`. Move `keyController` to the `State` class and call `keyController.dispose()` in the `dispose()` method.
2. **Missing Disposes:** Scan `lib/presentation/screens/subscription/payment_modal_screen.dart` and audit all screens. Ensure EVERY `TextEditingController`, `FocusNode`, and `ScrollController` is explicitly disposed of.
3. **Named Listeners:** In `lib/presentation/screens/home/main_dashboard_screen.dart`, refactor the anonymous listener in `_checkPaymentSuccessModal`. Store it as a `late VoidCallback _subListener`, initialize it in `initState`, and call `subProvider.removeListener(_subListener)` in `dispose`.
4. **Global Audit:** Search for any use of `.addListener` across the app and verify a corresponding `removeListener` exists in `dispose`.

---

## 📌 3. HIGH: Rendering & Layout Efficiency (Axis 2)

### Context
The app suffers from layout jank due to `shrinkWrap: true` in nested lists and expensive rasterization passes from the `Opacity` widget.

### The Fix (Surgical + Global Audit)
1. **Sliver Conversion:** In `lib/presentation/screens/employees/manage_employees_screen.dart`, replace the nested `ListView` (with `shrinkWrap: true`) with a `CustomScrollView` and use `SliverList.builder`.
2. **Eliminate Opacity Widgets:** Search for the `Opacity` widget in `wallet_card.dart`, `employee_card.dart`, and globally. Replace them with direct `Color.withOpacity()` or `Color.withAlpha()` on the `Decoration` or `TextStyle` to avoid offscreen buffer allocation.
3. **O(1) List Lookups:** In `manage_employees_screen.dart`, hoist `context.read<EmployeeProvider>()` outside the `itemBuilder` of the `ListView` so the provider lookup happens once per build, not 50 times.
4. **Global Audit:** Scan for `shrinkWrap: true` and `Opacity` widgets globally and replace with Slivers or Alpha colors respectively.

---

## 📌 4. HIGH: State Management & UI Thread Optimization (Axis 3)

### Context
Blanket `context.watch` calls and synchronous Disk I/O in the overlay are causing frame drops. Excessive `Future.microtask` calls are causing stale-frame flickers.

### The Fix (Surgical + Global Audit)
1. **Granular Selectors:** In `lib/presentation/overlays/transaction_overlay_screen.dart`, replace `context.watch<OverlayProvider>()` with `Selector<OverlayProvider, R>` focused only on necessary fields. Apply this to `CreateTransactionScreen` and `AddDebtScreen` to replace blanket `Consumer` usage.
2. **Async Disk I/O Fix:** In `lib/presentation/overlays/overlay_provider.dart`, ensure `SharedPreferences` is not fetched during `submitTransaction`. Use the pre-initialized `LocalStorageService`.
3. **Microtask Cleanup:** In `WalletProvider` and `StatisticsProvider`, remove `Future.microtask` from `_safeNotify()` except where strictly necessary (e.g., when called from `initState`). 
   - **Warning:** Ensure that state mutations are not triggered inside build methods before removing the microtask.
4. **Global Audit:** Enforce the rule: "No blanket watch at screen roots" across the entire project.

---

## 📌 5. MEDIUM: Tech Debt & L10n (Axis 4)

### Context
Helper methods instead of widgets prevent Flutter's element-tree caching, and hardcoded Arabic strings in providers break localization.

### The Fix (Surgical + Global Audit)
1. **Widget Extraction:** Convert `_StatItemWidget` in `general_statistics_screen.dart` from a method to a `const StatelessWidget` class.
2. **L10n Cleanup:** In `lib/providers/statistics_provider.dart`, replace hardcoded Arabic error strings with localization keys (`l10n`).
3. **Theme Caching:** In `lib/presentation/overlays/transaction_overlay_screen.dart`, cache `ThemeData.light()` as a `static final` constant to avoid redundant object allocations on every frame.
4. **Global Audit:** Scan for any private helper methods that return Widgets and convert them to `StatelessWidgets` where state is not required.

---

## 📌  acceptance Criteria
- [ ] No `TextEditingController` is instantiated in a `StatelessWidget`.
- [ ] Every listener added to a provider is removed in `dispose`.
- [ ] `shrinkWrap: true` is removed from all category lists in favor of Slivers.
- [ ] `Opacity` widgets are replaced with Alpha-based colors.
- [ ] `context.watch` at screen roots is replaced with `Selector` or scoped `Consumer`.
- [ ] All `debugPrint` calls in providers are guarded by `kDebugMode`.
- [ ] All hardcoded error strings in providers are moved to `l10n`.