# Implementation Plan: Final Security Hardening (Phase 11.5)

## Phase 1: Cryptographic Tuning (C-02 & C-03)
- [x] Task: Upgrade PBKDF2 Iterations and Isolate Support
    - [x] Write failing test for PBKDF2 hashing functionality.
    - [x] Update `_kIterations` to `600000` in `password_hasher.dart`.
    - [x] Wrap the hashing logic in Flutter's `compute()` to run in a background isolate.
- [x] Task: Constant-Time Verification
    - [x] Write failing test for hash verification.
    - [x] Replace simple `==` string comparison with a constant-time equality check.
- [x] Task: Conductor - User Manual Verification 'Cryptographic Tuning' (Protocol in workflow.md)

## Phase 2: O(1) Auth Query Refactoring (C-04)
- [x] Task: Implement Email-Based Auth
    - [x] Write failing test for fetching store by email.
    - [x] Implement query by `email` to retrieve store document and its salt.
    - [x] Integrate constant-time verification using the retrieved salt.
- [x] Task: Deprecate Full Table Scan
    - [x] Remove or deprecate the `getStoresByPassword` method in `store_repository.dart`.
- [x] Task: Update Login UI
    - [x] Write widget test for the new Email input field.
    - [x] Add Email input field to existing login screen.
    - [x] Connect new UI fields to the updated email-based auth flow.
- [x] Task: Conductor - User Manual Verification 'O(1) Auth Query Refactoring' (Protocol in workflow.md)

## Phase 3: UI Leakage & Git Secrets (C-01 & C-05)
- [x] Task: Sanitize Fallback UI
    - [x] Write widget test to ensure raw exceptions (`e.toString()`) are not rendered.
    - [x] Update fallback error screen in `main.dart` to show a generic, safe string.
    - [x] Verify `AppErrorHandler.logSilentError(e, stackTrace)` is invoked for Crashlytics.
- [x] Task: Purge Git Secrets
    - [x] Execute `git rm --cached android/app/google-services.json`.
    - [x] Execute `git rm --cached ios/Runner/GoogleService-Info.plist`.
    - [x] Ensure both files are listed in `.gitignore`.
- [x] Task: Conductor - User Manual Verification 'UI Leakage & Git Secrets' (Protocol in workflow.md)