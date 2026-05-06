# Implementation Plan: Background Services Master Fix (Phase 8.1)

## Phase 1: Background Isolate Stabilization [checkpoint: 468ceac]
- [x] Task: Make background entrypoints public [2d15d7f]
    - [x] Write failing test/verification script ensuring `backgroundSmsCallback` and `onIosBackground` cannot be aggressively tree-shaken.
    - [x] Implement fix: Remove underscores from `_backgroundSmsCallback` and `_onIosBackground` in `lib/core/services/background_service.dart` and update references.
- [x] Task: Safe Firebase Initialization in Isolate [f5e3b55]
    - [x] Write failing test simulating cold-start isolate environment for Firebase access.
    - [x] Implement fix: Add `if (Firebase.apps.isEmpty) { await Firebase.initializeApp(); }` to `backgroundSmsCallback`.
- [x] Task: Conductor - User Manual Verification 'Phase 1: Background Isolate Stabilization' (Protocol in workflow.md)

## Phase 2: Subscription TTL & Notifications [checkpoint: a1523ff]
- [x] Task: Implement 24h Subscription TTL [ea47ce5]
    - [x] Write failing test for stale subscription check (> 24 hours).
    - [x] Implement fix: Add TTL validation logic in `lib/core/services/sms_processing_pipeline.dart`.
    - [x] Refactor: Ensure clean separation of time-checking logic.
- [x] Task: Actionable TTL Notification & Unique IDs [677d34e]
    - [x] Write failing test for multiple notifications overwriting each other and actionable intents.
    - [x] Implement fix: Trigger local notification on TTL block with unique hash ID and localized Arabic text exactly as specified.

- [x] Task: Conductor - User Manual Verification 'Phase 2: Subscription TTL & Notifications' (Protocol in workflow.md)


## Phase 3: Unified Vault & Dependency Injection [checkpoint: 350d877]
- [x] Task: Refactor and Delete OverlayRepository [41c5d83]
    - [x] Write failing test verifying dependency decoupling.
    - [x] Implement fix: Migrate all logic from `OverlayRepository` to use `LocalStorageService.saveToVault()`. Delete `lib/data/repositories/overlay_repository.dart`.


- [x] Task: Unify Local Storage Keys [857d544]
    - [x] Write failing test verifying SMS pipeline writes/reads from a unified key.
    - [x] Implement fix: Unify keys using `LocalStorageService._kPendingOverlayData` and clean up orphans.
- [x] Task: Refactor GlobalOverlayListener and LocalizationProvider DI [20beefc]
    - [x] Write failing test to ensure components use `LocalStorageService` instead of direct `SharedPreferences`.
    - [x] Implement fix: Refactor `GlobalOverlayListener` and `LocalizationProvider` to strictly use `LocalStorageService.instance` or injected instances.
- [x] Task: Conductor - User Manual Verification 'Phase 3: Unified Vault & Dependency Injection' (Protocol in workflow.md)

## Phase 4: Overlay Resilience & Graceful Failure [checkpoint: 334b992]
- [x] Task: Dynamic Overlay Update [fe40457]
    - [x] Write failing test simulating active overlay receiving new data (should not close).
    - [x] Implement fix: Update `lib/core/services/sms_processing_pipeline.dart` to use `shareData()` if overlay is already active.
- [x] Task: Graceful Overlay Fallback UI [334b992]
    - [x] Write failing test for overlay initialization failure.
    - [x] Implement fix: Wrap `overlayMain` in `try/catch` and run `OverlayErrorApp` with hardcoded Arabic error text on failure.
- [x] Task: Conductor - User Manual Verification 'Phase 4: Overlay Resilience & Graceful Failure' (Protocol in workflow.md)

## Phase 5: Global Audit & Tech Debt Cleanup
- [x] Task: Isolate Permission Guarding [36a9152]
    - [x] Write failing test ensuring no permission requests originate from background isolate.
    - [x] Implement fix: Move all permission requests to `init` in `lib/core/services/sms_service.dart`.
- [ ] Task: Global Logging Audit
    - [ ] Write failing test verifying `debugPrint` calls are suppressed in release mode.
    - [ ] Implement fix: Wrap all `debugPrint` statements in `if (kDebugMode)` across the `lib/` directory.
- [ ] Task: Conductor - User Manual Verification 'Phase 5: Global Audit & Tech Debt Cleanup' (Protocol in workflow.md)