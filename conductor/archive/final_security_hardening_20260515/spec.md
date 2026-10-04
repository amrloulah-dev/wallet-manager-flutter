# Specification: Final Security Hardening (Phase 11.5)

## Overview
This track focuses on critical security remediations for the Wallet Manager application, addressing cryptographic weaknesses, inefficient O(N) auth queries, and UI data leakage, while ensuring no Git secrets are left exposed.

## Functional Requirements
1. **O(1) Auth Query Refactoring (C-04)**
   - Deprecate/remove the `getStoresByPassword` method in `store_repository.dart`.
   - Implement an email-based authentication flow querying Firestore by `email` to retrieve exactly one store document (O(1)).
   - Extract the unique `salt` from this document and hash the user-provided password using this specific salt.
   - Update the existing login screen UI to include an Email input field.
   - Enforce email login immediately for all users without legacy PIN/password fallback.

2. **UI Leakage & Git Secrets (C-01 & C-05)**
   - Update the initial initialization fallback screen in `main.dart` to display a safe, generic message: "App initialization failed. Please check your connection and try again."
   - Ensure the raw `e.toString()` and `stackTrace.toString()` are removed from the UI.
   - Ensure `AppErrorHandler.logSilentError(e, stackTrace)` continues to be invoked for Crashlytics logging.
   - Run terminal commands to untrack `google-services.json` and `GoogleService-Info.plist` from Git cache and ensure they are added to `.gitignore`.

## Non-Functional Requirements
1. **Cryptographic Tuning (C-02 & C-03)**
   - Upgrade PBKDF2 iterations to `600000` in `password_hasher.dart`.
   - Execute the PBKDF2 hashing process inside a background isolate using Flutter's `compute()` to prevent main UI thread freezing.
   - Implement constant-time comparison for hash verification to mitigate timing side-channel attacks, replacing the simple `==` comparison.

## Acceptance Criteria
- [ ] PBKDF2 `_kIterations` is strictly set to `600000`.
- [ ] Hash generation utilizes `compute()` to run on a background Isolate.
- [ ] Hash verification employs constant-time comparison.
- [ ] Authentication queries Firestore by `email` (O(1) lookup), eliminating the full table scan.
- [ ] Existing login UI is updated to require an email input field; legacy login is disabled.
- [ ] Fallback error screen in `main.dart` shows only a generic, safe string to the user.
- [ ] Terminal commands executed to clear `google-services.json` and `GoogleService-Info.plist` from Git cache.
- [ ] No medium/low findings or out-of-scope modules were altered.

## Out of Scope
- Fixing any findings categorized as MEDIUM or LOW (e.g., SMS in SharedPreferences, Predictable Emails).
- Refactoring features outside of the explicitly defined C-01 to C-05 findings.
- Migration of legacy users (email login is strictly enforced immediately).