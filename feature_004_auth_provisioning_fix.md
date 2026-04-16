# 🛠️ Detailed Execution Plan: Fix Silent Provisioning Failure (Feature 004)

**CRITICAL DIRECTIVES FOR DEVELOPER / AI AGENT:**
This document outlines the remediation for the silent failure vulnerability in the employee authentication flow (`lazyProvision`). Implement the "Smart Retry & Block" hybrid architecture exactly as specified. Do NOT proceed to the next phase without completing the Verification Gates and ensuring `flutter analyze` returns zero issues.

---

### 🔴 Problem Definition
During employee login, the application attempts to provision a virtual identity in the background via the `lazyProvision` function. If network connectivity drops or Firebase servers timeout, the function fails and currently swallows the error (using an empty `catch` block). 
**Critical Impact:** The employee is allowed into the application in a "limbo" or "ghost" state. They lack a valid Firebase `UID` in the database, breaking Role-Based Access Control (RBAC) and causing subsequent write operations to fail mysteriously.

### 🟢 Architectural Solution (Hybrid Approach)
Implement a "Smart Retry followed by Fail-Fast Block" strategy:
1. **Smart Retry:** If the initial provisioning fails, the system will wait 1 second and retry exactly once to bypass transient network hiccups.
2. **Fail-Fast & Cleanup:** If the second attempt fails, the system will immediately abort the login process, purge any pending session via `FirebaseAuth.instance.signOut()`, and throw an explicit exception.
3. **Error Routing:** The UI layer will catch this exception and route it to the central `ErrorHandler` to display a blocking, user-friendly dialog.

---

### 📋 Implementation Tasks

**1. Refactor Provisioning Logic (`lazyProvision`):**
- [x] Navigate to the file containing `lazyProvision` (e.g., `auth_provider.dart` or `auth_repository.dart`).
- [x] Locate and remove the empty `catch (e) {}` block that is swallowing the error.
- [x] Wrap the Firebase identity creation code in a `try-catch` block.
- [x] Inside the `catch` block, implement a single retry mechanism: `await Future.delayed(const Duration(seconds: 1));` followed by a second attempt to create the user.
- [x] If the second attempt also fails, throw an explicit exception: `throw Exception('Failed to provision employee identity. Please check your internet connection and try again.');`

**2. Secure the Login Flow (`loginAsEmployee`):**
- [x] Navigate to the `loginAsEmployee` function.
- [x] Ensure the invocation of `lazyProvision` is wrapped in a robust `try-catch` block.
- [x] In the `catch` block for provisioning failure, invoke `FirebaseAuth.instance.signOut()` to ensure no incomplete Firebase Auth session remains active.
- [x] Ensure that `isLoading = false` is executed inside a `finally` block so the UI never gets stuck in an infinite loading state, regardless of success or failure.
- [x] Re-throw the exception so the UI controller can handle it.

**3. Implement User Feedback (UI Layer):**
- [x] Navigate to the Login Screen or its respective UI Controller.
- [x] Catch the exception thrown by the login process.
- [x] Pass the error to the global `ErrorHandler` configured with `ErrorSeverity.critical` to display a blocking dialog informing the user of the network/provisioning failure.

---

### 🔍 Verification Gates

- [x] **Code Audit:** Inspect `lazyProvision`. Verify there are NO empty `catch (e) {}` blocks. The failure path MUST terminate with a `throw`.
- [x] **Logic Audit:** Inspect the `catch` block in `loginAsEmployee`. Verify that `FirebaseAuth.instance.signOut()` is explicitly called to clean up ghost sessions.
- [x] **State Audit:** Verify that `isLoading` is set to `false` within a `finally` block in the login flow.
- [x] **Static Analysis:** Run `flutter analyze` on the entire project. The terminal output MUST be exactly `0 issues found` before considering this feature complete.
