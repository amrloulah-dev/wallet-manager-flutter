# Implementation Plan: Minor Issues - Feature Completion & Localization Enforcement

## Phase 1: Password Recovery (Auth Logic) [checkpoint: 7fc07a3]
- [x] Task: TDD - `AuthProvider.sendPasswordReset`
    - [x] Create/Update test file: `test/providers/auth_provider_test.dart`
    - [x] Write failing tests for email validation (Regex).
    - [x] Write failing tests for successful password reset via `_authRepository.sendPasswordResetEmail`.
    - [x] Write failing tests for error mapping: `user-not-found` -> `auth_error_account_not_found`.
    - [x] Write failing tests for error mapping: `invalid-email` -> `auth_error_invalid_email`.
    - [x] Write failing tests for error mapping: `too-many-requests` -> `auth_error_too_many_requests`.
    - [x] Run tests to ensure they fail (Red phase).
- [x] Task: Implement `AuthProvider.sendPasswordReset`
    - [x] Navigate to `lib/providers/auth_provider.dart`.
    - [x] Create method `Future<void> sendPasswordReset(String email)`.
    - [x] Add pre-flight regex validation.
    - [x] Wrap Firebase call in try-catch and map exceptions to semantic snake_case String Constants.
    - [x] Ensure proper handling of employee edge case (`user-not-found`).
- [x] Task: Refactor and Verify
    - [x] Run tests to ensure they pass (Green phase).
    - [x] Refactor code for clarity if necessary.
- [x] Task: Conductor - User Manual Verification 'Phase 1: Password Recovery (Auth Logic)' (Protocol in workflow.md)

## Phase 2: Password Recovery (UI Logic) [checkpoint: d11dd16]
- [x] Task: TDD - Forgot Password UI
    - [x] Create/Update test file: `test/presentation/screens/auth/login_landing_screen_test.dart`
    - [x] Write failing widget test for presence of Forgot Password `TextButton`.
    - [x] Write failing widget test ensuring tapping the button opens a `BottomSheet`.
    - [x] Write failing widget test for email input and "Send" button within the `BottomSheet`.
    - [x] Run tests to ensure they fail (Red phase).
- [x] Task: Implement Forgot Password UI
    - [x] Navigate to `lib/presentation/screens/auth/login_landing_screen.dart`.
    - [x] Replace `// TODO: Implement forgot password` with a `TextButton`.
    - [x] Create `_showForgotPasswordDialog(context)` utilizing a `BottomSheet`.
    - [x] Implement `StatefulBuilder` for local loading state to prevent spam clicks.
    - [x] Wire "Send" button to `context.read<AuthProvider>().sendPasswordReset(email)`.
    - [x] Add `SnackBar` feedback for success/error.
- [x] Task: Refactor and Verify
    - [x] Run tests to ensure they pass (Green phase).
    - [x] Refactor UI code for clarity.
- [x] Task: Conductor - User Manual Verification 'Phase 2: Password Recovery (UI Logic)' (Protocol in workflow.md)

## Phase 3: Decoupling Providers from Hardcoded Strings [checkpoint: 622f3dd]
- [x] Task: TDD - Decouple Providers
    - [x] Update test files for `WalletProvider`, `AuthProvider`, and `OverlayProvider`.
    - [x] Write/Update failing tests to expect semantic String Constants instead of hardcoded Arabic strings on errors.
    - [x] Run tests to ensure they fail (Red phase).
- [x] Task: Refactor Providers
    - [x] Navigate to `lib/providers/wallet_provider.dart` and replace hardcoded Arabic strings with constants like `wallet_limit_reached`.
    - [x] Navigate to `lib/providers/auth_provider.dart` and replace hardcoded Arabic strings with constants like `auth_invalid_credentials`.
    - [x] Navigate to `lib/presentation/overlays/overlay_provider.dart` and replace the hardcoded string with `transaction_limit_exceeded`.
- [x] Task: Refactor and Verify
    - [x] Run tests to ensure they pass (Green phase).
    - [x] Execute regex search `[\u0600-\u06FF]` in `lib/providers/` to ensure 0 results.
- [x] Task: Conductor - User Manual Verification 'Phase 3: Decoupling Providers from Hardcoded Strings' (Protocol in workflow.md)

## Phase 4: Localization Enforcement (UI & Routers) [checkpoint: 93b1484]
- [x] Task: TDD - Localization Utilities and Router
    - [x] Create test file: `test/core/utils/error_mapper_test.dart`
    - [x] Write failing tests for `ErrorMapper.getLocalizedString` to map specific error codes to expected strings.
    - [x] Update router tests to expect localized text instead of hardcoded strings.
    - [x] Run tests to ensure they fail (Red phase).
- [x] Task: Implement Localization Enforcement
    - [x] Create `ErrorMapper` utility class in `lib/core/utils/error_mapper.dart`.
    - [x] Navigate to `lib/routes/app_router.dart` and replace hardcoded text with `AppLocalizations.of(context)` calls.
    - [x] Update `AppLocalizations` `.arb` files to include new keys for error codes and UI elements.
- [x] Task: Refactor and Verify
    - [x] Run tests to ensure they pass (Green phase).
    - [x] Run `flutter analyze` to ensure 0 issues.
- [x] Task: Conductor - User Manual Verification 'Phase 4: Localization Enforcement (UI & Routers)' (Protocol in workflow.md)

## Phase: Review Fixes [checkpoint: 1765e49]
- [x] Task: Apply review suggestions