# Specification: Security & Performance Optimization (Feature 011)

## Overview
This track addresses final vulnerabilities and performance bottlenecks within the Wallet Manager app, specifically focusing on a Device Data Leak in Firestore rules, expensive application builds caused by improper state management placement, and a blocked main thread delaying the initial `runApp()` execution.

## Functional Requirements

### Phase 1: Patch Device Data Leak (Security)
*   **Firestore Rules:** The `/device_registrations/{deviceId}` rule must be updated to enforce document ownership. Only authenticated users whose `uid` matches the `ownerUid` stored in the document can read or write it.
    *   *Constraint:* Existing documents lacking the `ownerUid` field will be strictly blocked from access.
*   **Dart Implementation:** The Dart code responsible for device registration must be updated to ensure the payload includes `'ownerUid': FirebaseAuth.instance.currentUser?.uid` when a device is created or updated.

### Phase 2: Eliminate Expensive Builds (Performance)
*   **State Management Optimization:** The global `Consumer3<AuthProvider, ThemeProvider, LocalizationProvider>` wrapping the `MaterialApp` in `lib/app.dart` must be removed.
*   **Targeted Rebuilds:** `MaterialApp` should only rebuild when `Theme` and `Locale` change. Use a `Selector` or a targeted `Consumer2` specifically for `ThemeProvider` and `LocalizationProvider`.
*   **Auth Consumption:** `AuthProvider` should only be consumed where needed, such as inside `AuthCheckWrapper`, to handle routing based on authentication state without triggering full application rebuilds.

### Phase 3: Unblock Main Thread (Performance)
*   **Asynchronous Initialization:** Heavy initializations in `lib/main.dart` (like `initializeBackgroundService()` and `SmsService().init()`) must not block `runApp()`.
*   **Non-Blocking Execution:** Remove `await` for these background services, wrapping them in an asynchronous non-blocking call (e.g., `unawaited()`).
*   **Failure Handling:** If background services fail to initialize, they will rely on standard silent Crashlytics logging, keeping startup fast and invisible to the user.

## Non-Functional Requirements
*   **Code Quality:** The final output must pass all static analysis checks with `0 issues found` when running `flutter analyze`.
*   **Performance:** The initial application frame must render significantly faster after unblocking `runApp()`.

## Acceptance Criteria
1.  **Security:** Unauthorized reads of `device_registrations` are blocked by Firestore rules.
2.  **State Management:** `MaterialApp` is no longer a child of `AuthProvider`. Changing auth state does not rebuild the entire widget tree.
3.  **Startup:** `runApp(const MyApp());` is called immediately after Firebase and Dependency Injection setup, without waiting for background services to complete.
4.  **Static Analysis:** `flutter analyze` returns `0 issues found`.

## Out of Scope
*   Data migration scripts for legacy `device_registrations` documents lacking `ownerUid`.
*   Adding new UI elements or refactoring unrelated providers.