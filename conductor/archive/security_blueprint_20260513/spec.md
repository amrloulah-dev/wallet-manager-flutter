# Specification: General Security & Data Protection Blueprint (Phase 11)

## Overview
This track focuses on targeted security remediation for the Wallet Manager application to prevent local privilege escalation and rainbow table attacks. It strictly adheres to the constraint of remaining on Firebase free-tier services, accepting predictable identities and client-side auth sync as an acceptable risk, while heavily fortifying local storage, cryptography, and PII logging.

## Functional Requirements
- **Secure Storage Migration:**
  - Migrate `userRole`, `storeId`, and `userId` from `SharedPreferences` to `flutter_secure_storage` inside `local_storage_service.dart`.
- **Ephemeral SMS Storage:**
  - Keep the SMS queue (`_kPendingOverlayData`) in `SharedPreferences` for isolate compatibility, but immediately remove these keys after the Main UI thread consumes and parses them.
- **Cryptographic Upgrade:**
  - Refactor `password_hasher.dart` to replace unsalted SHA-256 with PBKDF2.
  - Generate a unique, randomly generated cryptographic salt for each user/PIN. Store the salt alongside the hash in the database.
  - Remove the hardcoded pepper string (`wallet_manager_sub_integrity_2025`) from `local_storage_service.dart`.
- **PII & Exception Sanitization:**
  - Refactor `AppErrorHandler` to strip raw exception objects containing sensitive database payloads before logging to Crashlytics or showing BotToasts.
  - Strip sensitive fields (phone numbers, wallet balances, transaction amounts) from `debugPrint` calls in `transaction_repository.dart` and `overlay_provider.dart`. Replace with structural logs.
  - Extend PII sanitization and storage migration sweeps to: `lib/providers/auth_provider.dart`, `lib/core/services/sms_processing_pipeline.dart`, and `lib/data/models/debt_model.dart`.

## Non-Functional Requirements
- Maintain background isolate compatibility when dealing with `SharedPreferences` for SMS queuing.
- Do NOT migrate authentication handling to Cloud Functions or modify identity generation logic.

## Acceptance Criteria
- [ ] `flutter_secure_storage` is used for `userRole`, `storeId`, and `userId`.
- [ ] `SharedPreferences` actively deletes SMS data immediately after UI ingestion.
- [ ] Employee PINs are hashed using PBKDF2 with a unique salt. Plain SHA-256 is entirely removed.
- [ ] The hardcoded pepper string is deleted from the source code.
- [ ] `AppErrorHandler` strips sensitive payload data before logging.
- [ ] `debugPrint` statements do not echo raw PII or financial amounts in designated files.
- [ ] No modifications to Cloud Functions or Identity Generation logic are introduced.

## Out of Scope
- Backend migration of authentication logic to Cloud Functions.
- Overhauling identity generation beyond the current scope.