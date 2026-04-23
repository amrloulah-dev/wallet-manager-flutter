# 🛠️ Detailed Execution Plan: Feature Completion & Localization Enforcement (Minor Issues)

**CRITICAL DIRECTIVES FOR DEVELOPER / AI AGENT:**
This document outlines the final polish phase. It involves completing pending Authentication features and eradicating hardcoded strings from the Business Logic layer to strictly adhere to Clean Architecture and i18n standards.
1. Execution MUST be strictly sequential. Do not jump phases.
2. Business logic (Providers/Repositories) MUST NOT contain any user-facing languages (Arabic/English). They must yield standard error codes ONLY.
3. Pass all Verification Gates before proceeding.

---

## 🔐 Phase 1: Clear TODO - Implement Password Recovery (Auth Logic)

### 🔴 Problem Definition
A critical feature is missing: users cannot reset their passwords. Furthermore, the system must handle the edge case where an Employee (who is not registered in Firebase Auth, but rather in Firestore via PIN) attempts to reset a password, causing an unhandled `user-not-found` exception.

### 🟢 Architectural Solution
Implement the `sendPasswordReset` method in `AuthProvider`. Map Firebase exceptions to specific, predictable error codes rather than hardcoded UI messages.

### 📋 Implementation Tasks
- [ ] Navigate to `lib/providers/auth_provider.dart`.
- [ ] Create a new method `Future<void> sendPasswordReset(String email)`.
- [ ] Implement pre-flight validation (Regex for valid email).
- [ ] Wrap `_authRepository.sendPasswordResetEmail(email)` in a try-catch block.
- [ ] Map `FirebaseAuthException` codes to standard system keys:
    - `user-not-found` -> `auth_error_account_not_found`
    - `invalid-email` -> `auth_error_invalid_email`
    - `too-many-requests` -> `auth_error_too_many_requests`
- [ ] Specifically for the `user-not-found` case, format the UI translation later to instruct employees to contact management.

### 🔍 Verification Gates (Phase 1)
- [ ] **Code Audit:** Ensure the new method is fully asynchronous and explicitly logs critical events/failures using `AppErrorHandler`.

---

## 🖥️ Phase 2: Clear TODO - Implement Password Recovery (UI Logic)

### 🔴 Problem Definition
The UI currently contains a dead `// TODO: Implement forgot password` comment in the landing screen, confusing end-users and leaving the feature inaccessible.

### 🟢 Architectural Solution
Replace the TODO with a functional `TextButton` that invokes a clean, localized Dialog or BottomSheet for email input, securely wired to the newly created `AuthProvider` method.

### 📋 Implementation Tasks
- [ ] Navigate to `lib/presentation/screens/auth/login_landing_screen.dart`.
- [ ] Locate line 242 (or the exact `// TODO` line).
- [ ] Replace it with a `TextButton` triggering a private method `_showForgotPasswordDialog(context)`.
- [ ] Implement `_showForgotPasswordDialog` using `StatefulBuilder` to manage internal loading states (preventing spam clicks).
- [ ] Wire the 'Send' button to `context.read<AuthProvider>().sendPasswordReset(email)`.
- [ ] Implement success/error `SnackBar` feedback.

### 🔍 Verification Gates (Phase 2)
- [ ] **UI Audit:** Verify that clicking the "Send" button disables it while loading to prevent duplicate Firebase requests.
- [ ] **Code Audit:** Ensure there are exactly `0` instances of `// TODO: Implement forgot password` remaining in the file.

---

## 🧹 Phase 3: Decouple Providers from Hardcoded Strings (Architecture)

### 🔴 Problem Definition
Providers (`wallet_provider.dart`, `auth_provider.dart`, `overlay_provider.dart`) are heavily polluted with hardcoded Arabic text. This breaks Separation of Concerns (SoC) and makes multi-language support (i18n) impossible.

### 🟢 Architectural Solution
Providers must act purely as Business Logic components. They will emit semantic `ErrorCodes` (Strings or Enums) only. The UI layer, which holds the `BuildContext`, is solely responsible for translating these codes into user-facing text via `AppLocalizations`.

### 📋 Implementation Tasks
- [ ] Navigate to `lib/providers/wallet_provider.dart`. Replace hardcoded errors (lines 204, 284, 339, 347, 398) with standard keys (e.g., `throw Exception('wallet_limit_reached');`).
- [ ] Navigate to `lib/providers/auth_provider.dart`. Replace hardcoded errors (lines 375, 617, 766, 857) with standard keys (e.g., `auth_invalid_credentials`).
- [ ] Navigate to `lib/presentation/overlays/overlay_provider.dart`. Replace line 149 with a key: `transaction_limit_exceeded`.

### 🔍 Verification Gates (Phase 3)
- [ ] **Architecture Audit:** Execute a global regex search for Arabic characters (`[\u0600-\u06FF]`) inside the `lib/providers/` directory. The search MUST yield `0` results.

---

## 🌐 Phase 4: Localization Enforcement (UI & Routers)

### 🔴 Problem Definition
UI files and Routers (`app_router.dart`) contain static Arabic text inside `Text()` widgets, bypassing the `AppLocalizations` translation engine entirely.

### 🟢 Architectural Solution
Route all UI text through `AppLocalizations.of(context)`. Create an `ErrorMapper` utility in the UI layer to translate the new Provider Error Codes into localized strings dynamically.

### 📋 Implementation Tasks
- [ ] Navigate to `lib/routes/app_router.dart` (lines 78, 88, 97). Replace hardcoded text with appropriate localization keys.
- [ ] Implement `ErrorMapper.getLocalizedString(context, errorCode)` utility function to handle the keys generated in Phase 3.
- [ ] Update `AppLocalizations` (.arb files) to encompass all newly created keys.

### 🔍 Verification Gates (Phase 4)
- [ ] **Compile Test:** Run `flutter analyze`. Must output `0 issues found`.
- [ ] **Runtime Test:** Trigger a mock error (e.g., invalid login). Ensure the error dialog displays the correct text fetched via `AppLocalizations`, verifying the mapping pipeline works.