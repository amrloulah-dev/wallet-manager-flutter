# Implementation Plan: General Security & Data Protection Blueprint (Phase 11)

## Phase 1: Local Storage Migration & Ephemeral SMS
- [ ] Task: Integrate `flutter_secure_storage`
    - [ ] Add `flutter_secure_storage` dependency if not present.
    - [ ] Update DI setup (`service_locator.dart`) if needed.
- [ ] Task: Migrate `local_storage_service.dart`
    - [ ] Write Failing Tests for secure storage logic.
    - [ ] Implement to Pass Tests: Migrate `userRole`, `storeId`, and `userId` to use secure storage.
    - [ ] Implement to Pass Tests: Remove hardcoded pepper string `wallet_manager_sub_integrity_2025`.
- [ ] Task: Ephemeral SMS Storage in `local_storage_service.dart` and `sms_processing_pipeline.dart`
    - [ ] Write Failing Tests for immediate SMS data cleanup.
    - [ ] Implement to Pass Tests: Add logic to remove SMS queue keys immediately after parsing.
- [ ] Task: Update `auth_provider.dart`
    - [ ] Write Failing Tests for updated auth flow storage.
    - [ ] Implement to Pass Tests: Use secure storage methods where applicable.
- [ ] Task: Conductor - User Manual Verification 'Phase 1: Local Storage Migration & Ephemeral SMS' (Protocol in workflow.md)

## Phase 2: Cryptographic Upgrade
- [ ] Task: PBKDF2 Setup
    - [ ] Add `cryptography` or `pointycastle` dependency.
- [ ] Task: Refactor `password_hasher.dart`
    - [ ] Write Failing Tests for PBKDF2 hashing and verification (including salt).
    - [ ] Implement to Pass Tests: Remove unsalted SHA-256. Implement PBKDF2 with unique, randomly generated cryptographic salt.
    - [ ] Implement to Pass Tests: Update hash verification logic to use the stored salt.
- [ ] Task: Conductor - User Manual Verification 'Phase 2: Cryptographic Upgrade' (Protocol in workflow.md)

## Phase 3: PII & Exception Sanitization
- [ ] Task: Sanitize `AppErrorHandler`
    - [ ] Write Failing Tests for error sanitization before logging.
    - [ ] Implement to Pass Tests: Strip raw exception payloads before sending to Crashlytics or showing BotToasts.
- [ ] Task: Clean `debugPrint` Statements
    - [ ] Inspect and update `transaction_repository.dart` to remove PII and replace with structural logs.
    - [ ] Inspect and update `overlay_provider.dart` to remove PII and replace with structural logs.
    - [ ] Inspect and update `sms_processing_pipeline.dart` and `debt_model.dart` to ensure no PII logging.
- [ ] Task: Conductor - User Manual Verification 'Phase 3: PII & Exception Sanitization' (Protocol in workflow.md)