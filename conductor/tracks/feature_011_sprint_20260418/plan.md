# Implementation Plan: Security & Performance Optimization (Feature 011)

## Phase 1: Patch Device Data Leak (Security)
- [ ] Task: Update Firestore Rules
    - [ ] Update `firestore.rules` to enforce document ownership for `/device_registrations/{deviceId}`.
    - [ ] Set `allow get: if isAuthenticated() && resource.data.ownerUid == request.auth.uid;`.
    - [ ] Ensure existing legacy documents lacking `ownerUid` are strictly blocked.
- [ ] Task: Update Device Registration Logic
    - [ ] Write/update failing test for the device registration flow to assert `ownerUid` inclusion.
    - [ ] Update device registration Dart repository/service to include `'ownerUid': FirebaseAuth.instance.currentUser?.uid` in the payload.
    - [ ] Run and pass tests.
- [ ] Task: Conductor - User Manual Verification 'Phase 1: Patch Device Data Leak (Security)' (Protocol in workflow.md)

## Phase 2: Eliminate Expensive Builds (Performance)
- [ ] Task: Refactor MaterialApp State Management
    - [ ] Write/update failing test for `MaterialApp` and `AuthCheckWrapper` initialization/rebuild behavior if applicable.
    - [ ] Remove the global `Consumer3<AuthProvider, ThemeProvider, LocalizationProvider>` wrapping the `MaterialApp` in `lib/app.dart`.
    - [ ] Wrap `MaterialApp` with a `Selector` or a targeted `Consumer2` specifically for `ThemeProvider` and `LocalizationProvider`.
    - [ ] Update `AuthCheckWrapper` to correctly consume `AuthProvider` internally for routing.
    - [ ] Run and pass tests.
- [ ] Task: Conductor - User Manual Verification 'Phase 2: Eliminate Expensive Builds (Performance)' (Protocol in workflow.md)

## Phase 3: Unblock Main Thread (Performance)
- [ ] Task: Optimize Main Initialization
    - [ ] Write/update failing test verifying `runApp()` timing or mock background service initialization.
    - [ ] In `lib/main.dart`, locate heavy initializations like `initializeBackgroundService()` and `SmsService().init()`.
    - [ ] Remove the `await` keyword for these services.
    - [ ] Wrap them in an asynchronous non-blocking call (e.g., `unawaited()`). Ensure standard Crashlytics logging is preserved.
    - [ ] Verify `runApp(const MyApp());` is executed immediately after Firebase and Dependency Injection setup.
    - [ ] Run and pass tests.
- [ ] Task: Verify Code Quality
    - [ ] Run `flutter analyze` and resolve any issues. Output must be `0 issues found`.
- [ ] Task: Conductor - User Manual Verification 'Phase 3: Unblock Main Thread (Performance)' (Protocol in workflow.md)