# Specification: Background Services Master Fix (Phase 8.1)

## Overview
This track focuses on the final remediation for Phase 8, addressing deep architectural flaws related to Android isolates, tree-shaking, OS-level constraints, and data consistency in Wallet Manager. The budget constraint is strict: $0 (Spark Plan), minimizing Cloud Functions and reads.

## Functional Requirements
1. **Public Background Entrypoints:** All `@pragma('vm:entry-point')` functions, specifically `backgroundSmsCallback` and `onIosBackground` in `lib/core/services/background_service.dart`, must be public to prevent aggressive tree-shaking by ProGuard/R8.
2. **Safe Isolate Initialization:** The background SMS isolate must explicitly call `Firebase.initializeApp()` before attempting to log errors to Crashlytics to avoid cold-start crashes.
3. **Subscription TTL Validation:** Implement a 24-hour Time-to-Live (TTL) check for subscription data in the background. If stale, SMS processing is blocked, and an actionable local notification (hardcoded Arabic: "⚠️ انتهت صلاحية مزامنة الاشتراك...") directs the user back to the app.
4. **Unique Overlay Notifications:** Overlay wake-up notifications must use uniquely generated hashes (not a hardcoded ID `0`) so pending notifications stack gracefully.
5. **Unified Vault & Strict DI:** `OverlayRepository` must be deleted. `GlobalOverlayListener` and `LocalizationProvider` must be refactored to strictly use `LocalStorageService.instance` or an injected instance. The app must rely on `LocalStorageService` as the single source of truth for disk reads/writes.
6. **Dynamic Overlay Updates:** Replace the close-and-reopen overlay pattern with dynamic `shareData()` updates if the overlay is already active, to prevent failures on restrictive ROMs.
7. **Graceful Overlay Failures:** Wrap `overlayMain` initialization (Firebase, DI) in a `try/catch`. On failure, present a fallback `OverlayErrorApp` with hardcoded Arabic text ("❌ خطأ في الاتصال...").
8. **Isolate Permission Guarding:** Ensure background isolates never request OS permissions (like battery optimization or notifications). These must solely be handled by the main UI isolate.
9. **Global Logging Audit:** All `debugPrint` calls must be strictly guarded by `if (kDebugMode)` across the entire `lib/` folder.

## Non-Functional Requirements
1. **Performance:** Changes must not increase memory leaks or background execution times.
2. **Reliability:** The overlay and background SMS parsing must be highly resilient on aggressive Android ROMs (MIUI, EMUI, Samsung OneUI, Stock Android).
3. **Architecture:** Enforce Clean Architecture by decoupling dependencies from `SharedPreferences.getInstance()` in favor of the unified `LocalStorageService`.

## Acceptance Criteria
- [ ] `@pragma` background callbacks are strictly `public`.
- [ ] Firebase is explicitly initialized in the cold-start isolate before Crashlytics usage.
- [ ] Background SMS pipeline is blocked if subscription data is > 24 hours stale.
- [ ] `LocalStorageService` is strictly used for the overlay vault and all internal direct `SharedPreferences` calls are removed.
- [ ] `OverlayRepository` is deleted and its logic migrated.
- [ ] Active overlays are dynamically updated via `shareData()` instead of being closed and reopened.
- [ ] Overlay initialization failures result in a dedicated Error UI, not a crash.
- [ ] Zero permissions are requested from background isolates.
- [ ] All `debugPrint` statements in background paths are guarded by `kDebugMode`.