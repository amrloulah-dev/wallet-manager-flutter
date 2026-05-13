# Implementation Plan: General Security & Data Protection Blueprint (Phase 11)

## Phase 1: Local Storage Migration & Ephemeral SMS [checkpoint: 0306a8e]
- [x] Task: Integrate `flutter_secure_storage` [0306a8e]
    - [x] Add `flutter_secure_storage` dependency if not present.
    - [x] Update DI setup (`service_locator.dart`) if needed.
- [x] Task: Migrate `local_storage_service.dart` [0306a8e]
    - [x] Write Failing Tests for secure storage logic.
    - [x] Implement to Pass Tests: Migrate `userRole`, `storeId`, and `userId` to use secure storage.
    - [x] Implement to Pass Tests: Remove hardcoded pepper string `wallet_manager_sub_integrity_2025`.
- [x] Task: Ephemeral SMS Storage in `local_storage_service.dart` and `sms_processing_pipeline.dart` [0306a8e]
    - [x] Write Failing Tests for immediate SMS data cleanup.
    - [x] Implement to Pass Tests: Add logic to remove SMS queue keys immediately after parsing.
- [x] Task: Update `auth_provider.dart` [0306a8e]
    - [x] Write Failing Tests for updated auth flow storage.
    - [x] Implement to Pass Tests: Use secure storage methods where applicable.
- [x] Task: Conductor - User Manual Verification 'Phase 1: Local Storage Migration & Ephemeral SMS' (Protocol in workflow.md) [0306a8e]

## Phase 2: Cryptographic Upgrade [checkpoint: 37fdaa3]
- [x] Task: PBKDF2 Setup [37fdaa3]
    - [x] Add `cryptography` or `pointycastle` dependency.
- [x] Task: Refactor `password_hasher.dart` [37fdaa3]
    - [x] Write Failing Tests for PBKDF2 hashing and verification (including salt).
    - [x] Implement to Pass Tests: Remove unsalted SHA-256. Implement PBKDF2 with unique, randomly generated cryptographic salt.
    - [x] Implement to Pass Tests: Update hash verification logic to use the stored salt.
- [x] Task: Conductor - User Manual Verification 'Phase 2: Cryptographic Upgrade' (Protocol in workflow.md) [37fdaa3]

## Phase 3: PII & Exception Sanitization
- [ ] Task: Sanitize `AppErrorHandler`
    - [ ] Write Failing Tests for error sanitization before logging.
    - [ ] Implement to Pass Tests: Strip raw exception payloads before sending to Crashlytics or showing BotToasts.
- [ ] Task: Clean `debugPrint` Statements
    - [ ] Inspect and update `transaction_repository.dart` to remove PII and replace with structural logs.
    - [ ] Inspect and update `overlay_provider.dart` to remove PII and replace with structural logs.
    - [ ] Inspect and update `sms_processing_pipeline.dart` and `debt_model.dart` to ensure no PII logging.
- [ ] Task: Conductor - User Manual Verification 'Phase 3: PII & Exception Sanitization' (Protocol in workflow.md)