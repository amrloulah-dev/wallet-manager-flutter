# 🛠️ Detailed Execution Plan: Security & Performance Optimization (Feature 011)

**CRITICAL DIRECTIVES FOR DEVELOPER / AI AGENT:**
This document resolves the final vulnerabilities and performance bottlenecks: Device Data Leak, Expensive Builds, and Main Thread Blocking.
1. Execution MUST be strictly sequential.
2. Ensure `Selector` is used for optimal Provider performance.

---

## 🔒 Phase 1: Patch Device Data Leak (Security)

### 🔴 Problem Definition
The `device_registrations` rule allows any authenticated user to `get` any device document, causing a horizontal data leak.

### 🟢 Architectural Solution
Enforce document ownership. The user can only read the document if their UID matches the `ownerUid` stored in the document.

### 📋 Implementation Tasks
- [ ] Navigate to `firestore.rules`.
- [ ] Locate the `match /device_registrations/{deviceId}` block.
- [ ] Update the `allow get` rule to: 
      `allow get: if isAuthenticated() && resource.data.ownerUid == request.auth.uid;`
- [ ] Navigate to the Dart file responsible for registering the device (e.g., `lib/data/repositories/device_repository.dart` or similar). Ensure that when `create` is called, the payload includes: `'ownerUid': FirebaseAuth.instance.currentUser?.uid`.

### 🔍 Verification Gates (Phase 1)
- [ ] **Code Audit:** Verify `firestore.rules` enforces `ownerUid` checking for `device_registrations`.

---

## ⚡ Phase 2: Eliminate Expensive Builds (Performance)

### 🔴 Problem Definition
In `lib/app.dart`, `Consumer3` wraps the entire `MaterialApp`. Any state change in `AuthProvider` rebuilds the whole app, causing UI jank.

### 🟢 Architectural Solution
Remove the global `Consumer3`. Use `Selector` for `Theme` and `Locale` to only rebuild `MaterialApp` when UI settings change. Leave `AuthProvider` to be consumed only where needed (e.g., inside `AuthCheckWrapper`).

### 📋 Implementation Tasks
- [ ] Navigate to `lib/app.dart`.
- [ ] Remove `Consumer3<AuthProvider, ThemeProvider, LocalizationProvider>`.
- [ ] Wrap `MaterialApp` with a `Selector` or a targeted `Consumer2` that ONLY listens to `ThemeProvider` and `LocalizationProvider`.
      ```dart
      // Example using Consumer2 (or nested Selectors):
      child: Consumer2<ThemeProvider, LocalizationProvider>(
        builder: (context, themeProvider, localizationProvider, child) {
          return MaterialApp(
             // ... Theme and Locale setup ...
             home: const AuthCheckWrapper(), // AuthProvider is consumed INSIDE this wrapper
          );
        }
      )
      ```
- [ ] Ensure `AuthCheckWrapper` correctly uses `context.watch<AuthProvider>()` or a `Consumer` internally to handle routing based on auth state.

### 🔍 Verification Gates (Phase 2)
- [ ] **Code Audit:** Verify `MaterialApp` is NO LONGER wrapped in an `AuthProvider` consumer.

---

## 🚀 Phase 3: Unblock Main Thread (Performance)

### 🔴 Problem Definition
Heavy initializations like `initializeBackgroundService()` in `main.dart` block `runApp()`, causing a slow startup (delayed first frame).

### 🟢 Architectural Solution
Keep absolute essentials in `main()` (like Firebase init) but defer background services and non-blocking inits to the Splash Screen or run them asynchronously without awaiting them before `runApp`.

### 📋 Implementation Tasks
- [ ] Navigate to `lib/main.dart`.
- [ ] Locate `await initializeBackgroundService();` and `await SmsService().init();`.
- [ ] Remove the `await` keyword and wrap them in an asynchronous non-blocking call, OR move them entirely to the `initState` of your Splash Screen widget.
      ```dart
      // If kept in main, run without blocking:
      unawaited(initializeBackgroundService());
      if (sl<LocalStorageService>().isSmsAutomationEnabled) {
        unawaited(SmsService().init());
      }
      ```
      *(Note: Ensure `import 'dart:async';` is added for `unawaited`)*
- [ ] Ensure `runApp(const MyApp());` is called as quickly as possible after Firebase and Dependency Injection setup.

### 🔍 Verification Gates (Phase 3)
- [ ] **Code Audit:** Inspect `main.dart`. Verify `runApp` is not blocked by background service initialization.
- [ ] **Final Global Compile:** Run `flutter analyze`. The terminal MUST output `0 issues found`.