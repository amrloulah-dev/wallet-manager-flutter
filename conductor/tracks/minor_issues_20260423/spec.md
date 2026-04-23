# Specification: Minor Issues - Feature Completion & Localization Enforcement

## 1. Overview
This track addresses critical pending items from the application's final polish phase. It implements missing authentication features (Password Recovery) and enforces strict separation of concerns by removing hardcoded user-facing strings (Arabic/English) from the Business Logic layer (Providers/Repositories). The UI layer will exclusively handle translations using `AppLocalizations`.

## 2. Functional Requirements
### 2.1 Password Recovery (Auth Logic)
- **Email Reset:** Implement `sendPasswordReset(String email)` in `AuthProvider`.
- **Validation:** Pre-flight regex validation for valid email formatting.
- **Error Mapping:** Wrap Firebase calls in `try-catch` blocks and map `FirebaseAuthException` codes to semantic snake_case String Constants:
  - `user-not-found` -> `auth_error_account_not_found`
  - `invalid-email` -> `auth_error_invalid_email`
  - `too-many-requests` -> `auth_error_too_many_requests`
- **Employee Edge Case:** Handle `user-not-found` properly for employees (who sign in via PIN and are not in Firebase Auth) so they can be instructed to contact management by the UI.

### 2.2 Password Recovery (UI Logic)
- **Access Point:** Replace the `// TODO: Implement forgot password` comment in `login_landing_screen.dart` with a functional `TextButton`.
- **Recovery Component:** Invoke a `BottomSheet` dialog `_showForgotPasswordDialog(context)` containing an email input field and a "Send" button.
- **State Management:** Use `StatefulBuilder` within the BottomSheet to manage loading states and prevent spam clicks.
- **Feedback:** Provide success/error `SnackBar` feedback upon completion.

### 2.3 Decoupling Providers from Hardcoded Strings
- **Refactoring:** Providers must emit semantic String Constants (`ErrorCodes`) exclusively.
- **Target Providers:**
  - `lib/providers/wallet_provider.dart` (e.g., `wallet_limit_reached`)
  - `lib/providers/auth_provider.dart` (e.g., `auth_invalid_credentials`)
  - `lib/presentation/overlays/overlay_provider.dart` (e.g., `transaction_limit_exceeded`)
- **Strict Adherence:** The Business Logic layer must not contain any Arabic or English user-facing text.

### 2.4 Localization Enforcement (UI & Routers)
- **Centralized Translation:** Implement a central `ErrorMapper.getLocalizedString(context, errorCode)` utility class in the UI layer.
- **Router Updates:** Replace hardcoded Arabic text in `lib/routes/app_router.dart` with `AppLocalizations.of(context)` calls.
- **ARB Updates:** Add all newly created `ErrorCodes` to the `.arb` files.

## 3. Non-Functional Requirements
- **Separation of Concerns:** Business Logic (Providers) must not depend on UI context or translation services.
- **Robustness:** Ensure UI loading states correctly guard against duplicate API requests.

## 4. Acceptance Criteria
- [ ] Users can successfully request a password reset via the new BottomSheet UI.
- [ ] Employees attempting a reset receive a localized message to contact management.
- [ ] Global regex search for Arabic characters (`[\u0600-\u06FF]`) inside `lib/providers/` yields 0 results.
- [ ] `flutter analyze` outputs 0 issues found.
- [ ] No `// TODO: Implement forgot password` comments remain in `login_landing_screen.dart`.
- [ ] A mock error (e.g., invalid login) correctly displays the localized text fetched via `ErrorMapper`.

## 5. Out of Scope
- Major architectural changes outside the specified providers and router.
- Full localization of screens not explicitly exhibiting hardcoded strings in the current audit.