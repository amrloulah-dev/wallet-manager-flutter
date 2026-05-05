# 🛠️ Wallet Manager - Background Services Master Fix Blueprint (Phase 8.1)

## 📌 1. General Context & Strict System Prompt
**To the AI Agent (Antigravity / Gemini CLI):**
You are working on "Wallet Manager", a Flutter-based financial operations app. This is the FINAL remediation for Phase 8. You must fix deep architectural flaws related to Android isolates, tree-shaking, OS-level constraints, and data consistency.
**Core Constraints:**
1. **$0 Budget (Spark Plan):** No Cloud Functions. Minimal reads.
2. **Context-Aware Refactoring:** Read the "Context" of each task to understand *why* you are making the change. Do not blindly apply fixes without understanding the architectural goal.
3. **GLOBAL AUDIT DIRECTIVE:** For every issue, you MUST scan the entire codebase for similar anti-patterns.

---

## 📌 2. CRITICAL: Isolate Visibility & Firebase Cold-Start (C-1, C-2, M-1, Q-1)

### Context
Android's `another_telephony` plugin cannot reliably invoke private dart functions (`_`) due to release-mode tree-shaking (ProGuard/R8). Furthermore, cold-start isolates crash when calling Crashlytics because Firebase is uninitialized in that specific memory space.

### The Fix (Surgical + Global Audit)
1. **Public Entrypoint:** In `lib/core/services/background_service.dart`, rename `_backgroundSmsCallback` to `backgroundSmsCallback` (remove the underscore). Update the registration reference in `onStart()` to match.
2. **Safe Firebase Init:** Inside `backgroundSmsCallback`, BEFORE any `try/catch` error logging, add a safe Firebase initialization block: 
   `if (Firebase.apps.isEmpty) { await Firebase.initializeApp(); }`
3. **Standardize Logging:** Replace any raw `debugPrint` inside the `catch` blocks of `backgroundSmsCallback` with `AppErrorHandler.logSilentError(...)` so errors reach Crashlytics.
4. **Global Audit:** Ensure NO background entrypoint (`@pragma('vm:entry-point')`) in the app is marked as private.

---

## 📌 3. HIGH: The 24h Subscription TTL & Notification IDs (M-3, Q-3)

### Context
Users can bypass subscription expiry by closing the app; the background service keeps using a stale cached `sub_end_date_ms`. Also, all SMS notifications use hardcoded ID `0`, overwriting each other.

### The Fix (Surgical + Global Audit)
1. **24h TTL Stale Check:** In `lib/core/services/sms_processing_pipeline.dart` (or where subscription limits are checked in the background), implement a TTL check. If the difference between `DateTime.now()` and the last synced subscription timestamp is greater than 24 hours, **BLOCK** the SMS processing.
2. **Actionable Sync Notification:** If blocked by the TTL, trigger an actionable local notification stating: *"⚠️ انتهت صلاحية مزامنة الاشتراك. يرجى فتح التطبيق لتحديث بياناتك."* (Tapping must open the Main App).
3. **Unique Notification IDs:** In `_showWakeUpNotification`, replace ID `0` with a generated hash (e.g., based on the SMS timestamp or sender) so multiple pending overlay notifications stack instead of replacing each other.

---

## 📌 4. HIGH: Unified Vault & Clean DI (C-6, Q-2)

### Context
The app uses two different SharedPreferences keys (`pending_overlay_data` and `pending_overlay_tx`) creating memory leaks and data fragmentation. Direct `SharedPreferences.getInstance()` calls bypass the DI layer.

### The Fix (Surgical + Global Audit)
1. **Refactor OverlayRepository:** In `lib/data/repositories/overlay_repository.dart`, remove all direct calls to `SharedPreferences.getInstance()`. 
2. **Inject LocalStorageService:** Pass `LocalStorageService` via the constructor (update `service_locator.dart` accordingly).
3. **Unify Keys:** Ensure `OverlayRepository` and the SMS pipeline both write to and read from the exact same key constant (e.g., `LocalStorageService._kPendingOverlayData`). Delete the orphan key.

---

## 📌 5. MEDIUM: Overlay Dynamic Update & Graceful Failure (M-2, C-5)

### Context
Closing and rapidly re-opening the overlay causes silent failures on aggressive Android ROMs (MIUI, EMUI). Additionally, if dependency injection or Firebase fails inside `overlayMain`, it causes a blank screen or a UI freeze.

### The Fix (Surgical + Global Audit)
1. **Dynamic Overlay Update:** In `lib/core/services/sms_processing_pipeline.dart` (around line 221), change the overlay trigger logic. 
   - Check `if (await FlutterOverlayWindow.isActive())`. 
   - If `true`: Do NOT close it. Directly call `shareData()`.
   - If `false`: Call `showOverlay()` followed by `shareData()`.
2. **Graceful Error UI:** In `lib/main.dart` (`overlayMain`), if `Firebase.initializeApp()` or `setupServiceLocator()` throws an exception, do NOT proceed. Catch the error and run a fallback widget (e.g., `runApp(const OverlayErrorApp())`) that displays a simple, clean UI stating: *"❌ خطأ في الاتصال. يرجى إتمام المعاملة من التطبيق الأساسي."* with a close button.

---

## 📌 6. STRICT ENFORCEMENT: Permissions & Tech Debt (C-4, M-5, Q-4)

### Context
Requesting OS permissions from a background isolate crashes the app. Unwrapped `debugPrint` calls consume I/O resources in release builds.

### The Fix (Surgical + Global Audit)
1. **UI-Bound Permissions ONLY:** Ensure `Permission.ignoreBatteryOptimizations` and `Permission.notification` (`POST_NOTIFICATIONS` for Android 13+) are ONLY requested inside `lib/core/services/sms_service.dart` (`init` method running in the main UI isolate). NEVER request permissions from `background_service.dart`.
2. **Guard debugPrint:** Scan `lib/providers/wallet_provider.dart` and `lib/core/services/background_service.dart`. Wrap EVERY `debugPrint` in `if (kDebugMode)`.

---

## 📌 7. Acceptance Criteria
- [ ] `@pragma` background callbacks are strictly `public`.
- [ ] Firebase is explicitly initialized in the cold-start isolate before Crashlytics usage.
- [ ] Background SMS pipeline is blocked if subscription data is > 24 hours stale.
- [ ] `LocalStorageService` is strictly used for the overlay vault with a single, unified key.
- [ ] Active overlays are dynamically updated via `shareData()` instead of being closed and reopened.
- [ ] Overlay initialization failures result in a dedicated Error UI, not a crash.
- [ ] Zero permissions are requested from background isolates.
- [ ] All `debugPrint` statements in background paths are guarded by `kDebugMode`.