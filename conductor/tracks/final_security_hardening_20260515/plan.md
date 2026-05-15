# Implementation Plan: Final Security Hardening (Phase 11.5)

## Phase 1: Cryptographic Tuning (C-02 & C-03)
- [ ] Task: Upgrade PBKDF2 Iterations and Isolate Support
    - [ ] Write failing test for PBKDF2 hashing functionality.
    - [ ] Update `_kIterations` to `600000` in `password_hasher.dart`.
    - [ ] Wrap the hashing logic in Flutter's `compute()` to run in a background isolate.
- [ ] Task: Constant-Time Verification
    - [ ] Write failing test for hash verification.
    - [ ] Replace simple `==` string comparison with a constant-time equality check.
- [ ] Task: Conductor - User Manual Verification 'Cryptographic Tuning' (Protocol in workflow.md)

## Phase 2: O(1) Auth Query Refactoring (C-04)
- [ ] Task: Implement Email-Based Auth
    - [ ] Write failing test for fetching store by email.
    - [ ] Implement query by `email` to retrieve store document and its salt.
    - [ ] Integrate constant-time verification using the retrieved salt.
- [ ] Task: Deprecate Full Table Scan
    - [ ] Remove or deprecate the `getStoresByPassword` method in `store_repository.dart`.
- [ ] Task: Update Login UI
    - [ ] Write widget test for the new Email input field.
    - [ ] Add Email input field to existing login screen.
    - [ ] Connect new UI fields to the updated email-based auth flow.
- [ ] Task: Conductor - User Manual Verification 'O(1) Auth Query Refactoring' (Protocol in workflow.md)

## Phase 3: UI Leakage & Git Secrets (C-01 & C-05)
- [ ] Task: Sanitize Fallback UI
    - [ ] Write widget test to ensure raw exceptions (`e.toString()`) are not rendered.
    - [ ] Update fallback error screen in `main.dart` to show a generic, safe string.
    - [ ] Verify `AppErrorHandler.logSilentError(e, stackTrace)` is invoked for Crashlytics.
- [ ] Task: Purge Git Secrets
    - [ ] Execute `git rm --cached android/app/google-services.json`.
    - [ ] Execute `git rm --cached ios/Runner/GoogleService-Info.plist`.
    - [ ] Ensure both files are listed in `.gitignore`.
- [ ] Task: Conductor - User Manual Verification 'UI Leakage & Git Secrets' (Protocol in workflow.md)