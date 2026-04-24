# Implementation Plan: Architectural Refactoring & Domain-Driven Design (Phase 1)

## Phase 1: Setup & BaseProvider Creation [checkpoint: 85a44a2]
- [x] Task: Write Failing Tests for `BaseProvider` (Red Phase)
    - [x] Create `test/providers/base_provider_test.dart`.
    - [x] Write tests for `safeNotify()` and `setError()`.
- [x] Task: Implement `BaseProvider` to Pass Tests (Green Phase)
    - [x] Create `lib/providers/base_provider.dart`.
    - [x] Implement `_isDisposed`, `dispose()`, `safeNotify()`, and `setError()`.
- [x] Task: Refactor `BaseProvider` code if needed (No refactoring needed)
- [x] Task: Conductor - User Manual Verification 'Setup & BaseProvider Creation' (Protocol in workflow.md)

## Phase 2: Firebase DI Registration [checkpoint: 8da723c]
- [x] Task: Write Failing Tests for Firebase DI Registration (Red Phase)
    - [x] Update tests for `service_locator.dart` to verify `FirebaseFirestore.instance` and `FirebaseAuth.instance` are registered.
- [x] Task: Implement Firebase DI Registration to Pass Tests (Green Phase)
    - [x] Update `lib/core/di/service_locator.dart` to register Firebase singletons.
- [x] Task: Refactor DI code if needed (No refactoring needed)
- [x] Task: Conductor - User Manual Verification 'Firebase DI Registration' (Protocol in workflow.md)

## Phase 3: Global Provider Cleanup [checkpoint: 33607fa]
- [x] Task: Write Failing Tests for Provider Cleanup (Red Phase)
    - [x] Ensure existing tests for all providers (`auth_provider.dart`, `wallet_provider.dart`, etc.) fail or need updating for the new base class structure.
- [x] Task: Implement Provider Cleanup to Pass Tests (Green Phase)
    - [x] Refactor all providers in `lib/providers/` to extend `BaseProvider`.
    - [x] Remove all localized `_safeNotify` and `_setError` methods.
    - [x] Replace calls to localized methods with calls to the `BaseProvider` methods.
- [x] Task: Refactor and clean up imports
- [x] Task: Conductor - User Manual Verification 'Global Provider Cleanup' (Protocol in workflow.md)

## Phase 4: Final Verification
- [x] Task: Static Analysis
    - [x] Run `flutter analyze` and ensure zero errors. (Minor lint warnings in tests ignored)
- [x] Task: Full Test Suite
    - [x] Run all unit tests to ensure nothing was broken during the refactor. (91 tests passed)
- [x] Task: Conductor - User Manual Verification 'Final Verification' (Protocol in workflow.md)