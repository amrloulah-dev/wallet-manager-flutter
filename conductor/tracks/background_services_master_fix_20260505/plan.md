# Implementation Plan: Background Services Master Fix (Phase 8.1)

## Phase 1: Background Isolate Stabilization
- [x] Task: Make background entrypoints public [2d15d7f]
    - [x] Write failing test/verification script ensuring `backgroundSmsCallback` and `onIosBackground` cannot be aggressively tree-shaken.
    - [x] Implement fix: Remove underscores from `_backgroundSmsCallback` and `_onIosBackground` in `lib/core/services/background_service.dart` and update references.
- [ ] Task: Safe Firebase Initialization in Isolate
    - [ ] Write failing test simulating cold-start isolate environment for Firebase access.
    - [ ] Implement fix: Add `if (Firebase.apps.isEmpty) { await Firebase.initializeApp(); }` to `backgroundSmsCallback`.
- [ ] Task: Conductor - User Manual Verification 'Phase 1: Background Isolate Stabilization' (Protocol in workflow.md)

## Phase 2: Subscription TTL & Notifications
- [ ] Task: Implement 24h Subscription TTL
    - [ ] Write failing test for stale subscription check (> 24 hours).
    - [ ] Implement fix: Add TTL validation logic in `lib/core/services/sms_processing_pipeline.dart`.
    - [ ] Refactor: Ensure clean separation of time-checking logic.
- [ ] Task: Actionable TTL Notification & Unique IDs
    - [ ] Write failing test for multiple notifications overwriting each other and actionable intents.
    - [ ] Implement fix: Trigger local notification on TTL block with unique hash ID and localized Arabic text exactly as specified.
- [ ] Task: Conductor - User Manual Verification 'Phase 2: Subscription TTL & Notifications' (Protocol in workflow.md)

## Phase 3: Unified Vault & Dependency Injection
- [ ] Task: Refactor and Delete OverlayRepository
    - [ ] Write failing test verifying dependency decoupling.
    - [ ] Implement fix: Migrate all logic from `OverlayRepository` to use `LocalStorageService.saveToVault()`. Delete `lib/data/repositories/overlay_repository.dart`.
- [ ] Task: Unify Local Storage Keys
    - [ ] Write failing test verifying SMS pipeline writes/reads from a unified key.
    - [ ] Implement fix: Unify keys using `LocalStorageService._kPendingOverlayData` and clean up orphans.
- [ ] Task: Refactor GlobalOverlayListener and LocalizationProvider DI
    - [ ] Write failing test to ensure components use `LocalStorageService` instead of direct `SharedPreferences`.
    - [ ] Implement fix: Refactor `GlobalOverlayListener` and `LocalizationProvider` to strictly use `LocalStorageService.instance` or injected instances.
- [ ] Task: Conductor - User Manual Verification 'Phase 3: Unified Vault & Dependency Injection' (Protocol in workflow.md)

## Phase 4: Overlay Resilience & Graceful Failure
- [ ] Task: Dynamic Overlay Update
    - [ ] Write failing test simulating active overlay receiving new data (should not close).
    - [ ] Implement fix: Update `lib/core/services/sms_processing_pipeline.dart` to use `shareData()` if overlay is already active.
- [ ] Task: Graceful Overlay Fallback UI
    - [ ] Write failing test for overlay initialization failure.
    - [ ] Implement fix: Wrap `overlayMain` in `try/catch` and run `OverlayErrorApp` with hardcoded Arabic error text on failure.
- [ ] Task: Conductor - User Manual Verification 'Phase 4: Overlay Resilience & Graceful Failure' (Protocol in workflow.md)

## Phase 5: Global Audit & Tech Debt Cleanup
- [ ] Task: Isolate Permission Guarding
    - [ ] Write failing test ensuring no permission requests originate from background isolate.
    - [ ] Implement fix: Move all permission requests to `init` in `lib/core/services/sms_service.dart`.
- [ ] Task: Global Logging Audit
    - [ ] Write failing test verifying `debugPrint` calls are suppressed in release mode.
    - [ ] Implement fix: Wrap all `debugPrint` statements in `if (kDebugMode)` across the `lib/` directory.
- [ ] Task: Conductor - User Manual Verification 'Phase 5: Global Audit & Tech Debt Cleanup' (Protocol in workflow.md)