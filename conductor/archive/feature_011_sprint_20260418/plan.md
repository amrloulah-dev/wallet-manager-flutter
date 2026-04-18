# Implementation Plan: Security & Performance Optimization (Feature 011)

## Phase 1: Patch Device Data Leak (Security) [checkpoint: a306c6b]
- [x] Task: Update Firestore Rules [68889b5]
    - [x] Update `firestore.rules` to enforce document ownership for `/device_registrations/{deviceId}`.
    - [x] Set `allow get: if isAuthenticated() && resource.data.ownerUid == request.auth.uid;`.
    - [x] Ensure existing legacy documents lacking `ownerUid` are strictly blocked.
- [x] Task: Update Device Registration Logic [18f2c3f]
    - [x] Write/update failing test for the device registration flow to assert `ownerUid` inclusion.
    - [x] Update device registration Dart repository/service to include `'ownerUid': FirebaseAuth.instance.currentUser?.uid` in the payload.
    - [x] Run and pass tests.
- [x] Task: Conductor - User Manual Verification 'Phase 1: Patch Device Data Leak (Security)' (Protocol in workflow.md)

## Phase 2: Eliminate Expensive Builds (Performance) [checkpoint: d356824]
- [x] Task: Refactor MaterialApp State Management [4f98efb]
    - [x] Write/update failing test for `MaterialApp` and `AuthCheckWrapper` initialization/rebuild behavior if applicable.
    - [x] Remove the global `Consumer3<AuthProvider, ThemeProvider, LocalizationProvider>` wrapping the `MaterialApp` in `lib/app.dart`.
    - [x] Wrap `MaterialApp` with a `Selector` or a targeted `Consumer2` specifically for `ThemeProvider` and `LocalizationProvider`.
    - [x] Update `AuthCheckWrapper` to correctly consume `AuthProvider` internally for routing.
    - [x] Run and pass tests.
- [x] Task: Conductor - User Manual Verification 'Phase 2: Eliminate Expensive Builds (Performance)' (Protocol in workflow.md)

## Phase 3: Unblock Main Thread (Performance) [checkpoint: 609b56d]
- [x] Task: Optimize Main Initialization [141a1f8]
    - [x] Write/update failing test verifying `runApp()` timing or mock background service initialization.
    - [x] In `lib/main.dart`, locate heavy initializations like `initializeBackgroundService()` and `SmsService().init()`.
    - [x] Remove the `await` keyword for these services.
    - [x] Wrap them in an asynchronous non-blocking call (e.g., `unawaited()`). Ensure standard Crashlytics logging is preserved.
    - [x] Verify `runApp(const MyApp());` is executed immediately after Firebase and Dependency Injection setup.
    - [x] Run and pass tests.
- [x] Task: Verify Code Quality [90ee901]
    - [x] Run `flutter analyze` and resolve any issues. Output must be `0 issues found`.
- [x] Task: Conductor - User Manual Verification 'Phase 3: Unblock Main Thread (Performance)' (Protocol in workflow.md)