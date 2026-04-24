# Implementation Plan: Architectural Refactoring & Domain-Driven Design (Phase 1)

## Phase 1: Setup & BaseProvider Creation
- [ ] Task: Write Failing Tests for `BaseProvider` (Red Phase)
    - [ ] Create `test/providers/base_provider_test.dart`.
    - [ ] Write tests for `safeNotify()` and `setError()`.
- [ ] Task: Implement `BaseProvider` to Pass Tests (Green Phase)
    - [ ] Create `lib/providers/base_provider.dart`.
    - [ ] Implement `_isDisposed`, `dispose()`, `safeNotify()`, and `setError()`.
- [ ] Task: Refactor `BaseProvider` code if needed
- [ ] Task: Conductor - User Manual Verification 'Setup & BaseProvider Creation' (Protocol in workflow.md)

## Phase 2: Firebase DI Registration
- [ ] Task: Write Failing Tests for Firebase DI Registration (Red Phase)
    - [ ] Update tests for `service_locator.dart` to verify `FirebaseFirestore.instance` and `FirebaseAuth.instance` are registered.
- [ ] Task: Implement Firebase DI Registration to Pass Tests (Green Phase)
    - [ ] Update `lib/core/di/service_locator.dart` to register Firebase singletons.
- [ ] Task: Refactor DI code if needed
- [ ] Task: Conductor - User Manual Verification 'Firebase DI Registration' (Protocol in workflow.md)

## Phase 3: Global Provider Cleanup
- [ ] Task: Write Failing Tests for Provider Cleanup (Red Phase)
    - [ ] Ensure existing tests for all providers (`auth_provider.dart`, `wallet_provider.dart`, etc.) fail or need updating for the new base class structure.
- [ ] Task: Implement Provider Cleanup to Pass Tests (Green Phase)
    - [ ] Refactor all providers in `lib/providers/` to extend `BaseProvider`.
    - [ ] Remove all localized `_safeNotify` and `_setError` methods.
    - [ ] Replace calls to localized methods with calls to the `BaseProvider` methods.
- [ ] Task: Refactor and clean up imports
- [ ] Task: Conductor - User Manual Verification 'Global Provider Cleanup' (Protocol in workflow.md)

## Phase 4: Final Verification
- [ ] Task: Static Analysis
    - [ ] Run `flutter analyze` and ensure zero errors.
- [ ] Task: Full Test Suite
    - [ ] Run all unit tests to ensure nothing was broken during the refactor.
- [ ] Task: Conductor - User Manual Verification 'Final Verification' (Protocol in workflow.md)