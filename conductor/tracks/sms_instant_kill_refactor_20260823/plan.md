# Plan: Single-Item / Instant-Kill SMS Processing Pivot

> **Track Type:** Refactor
> **Spec:** `spec.md` (approved)
> **Workflow:** TDD — Red → Green → Refactor → Verify

---

## Phase 1: Storage Layer — Single-Key API [checkpoint: 83d4898]

> **Goal:** Remove all queue/fingerprint infrastructure from `LocalStorageService` and replace with 3 atomic single-key methods.

- [x] Task 1.1: Write Failing Tests for New Storage API (da683a7)
  - [x] Create/update test for `saveCurrentActiveSms()` — writes a Map, verify key `'current_active_sms'` contains the JSON payload
  - [x] Create/update test for `readCurrentActiveSms()` — reads back the Map, returns `null` when empty
  - [x] Create/update test for `clearCurrentActiveSms()` — clears the key, subsequent read returns `null`
  - [x] Test overwrite behavior: calling `save()` twice replaces the first value entirely
  - [x] Run tests — confirm they **fail** (Red phase)

- [x] Task 1.2: Implement New Single-Key Methods (0939054)
  - [x] Add constant `_kCurrentActiveSms = 'current_active_sms'` to `LocalStorageService`
  - [x] Implement `Future<void> saveCurrentActiveSms(Map<String, dynamic> data)` — `jsonEncode` + `setString`
  - [x] Implement `Map<String, dynamic>? readCurrentActiveSms()` — `getString` + `jsonDecode`, return `null` on missing/error
  - [x] Implement `Future<void> clearCurrentActiveSms()` — `remove(_kCurrentActiveSms)`
  - [x] Run tests — confirm they **pass** (Green phase)

- [x] Task 1.3: Delete Queue Methods & Constants (76560b2)
  - [x] Delete `enqueueOverlayData()` (lines 553–589)
  - [x] Delete `dequeueOverlayData()` (lines 593–638)
  - [x] Delete `getOverlayQueueLength()` (lines 641–659)
  - [x] Delete `peekOverlayData()` (lines 662–680)
  - [x] Delete `saveToVault()` (lines 683–685)
  - [x] Delete `readFromVault()` (lines 688–690)
  - [x] Delete `clearVault()` (lines 693–698)
  - [x] Delete constants: `_kPendingOverlayData`, `_kCompletedTxSync`, `_kMaxOverlayQueueSize`

- [x] Task 1.4: Delete Fingerprint Methods & Constants (76560b2)
  - [x] Delete `isSmsProcessed()` (lines 468–474)
  - [x] Delete `cacheSmsFingerprint()` (lines 477–490)
  - [x] Delete `getRecentSmsFingerprints()` (lines 493–497)
  - [x] Delete constants: `_kRecentSmsFingerprints`, `_kMaxSmsFingerprints`

- [x] Task 1.5: Verify Storage Layer Compiles (76560b2)
  - [x] Run `flutter analyze` on `lib/data/services/local_storage_service.dart` — expect downstream errors in callers only, no errors in the file itself
  - [x] Run storage-specific tests — confirm all pass

- [x] Task: Phase Verification & Checkpoint (Refer to workflow.md)

---

## Phase 2: Pipeline Layer — Gate 0 Removal & Single-Key Write

> **Goal:** Remove fingerprint deduplication from the SMS pipeline and rewire vault writes to the single-key API.

- [x] Task 2.1: Write Failing Tests for Pipeline Changes (38bad84)
  - [x] Update `sms_processing_pipeline_test.dart`: remove/replace mocks for `isSmsProcessed`, `cacheSmsFingerprint`, `enqueueOverlayData`
  - [x] Add test: incoming SMS calls `saveCurrentActiveSms()` with correct `overlayArgs`
  - [x] Add test: duplicate SMS is NOT blocked (no fingerprint check — pipeline processes it)
  - [x] Add test: second SMS call overwrites previous `saveCurrentActiveSms()` data
  - [x] Run tests — confirm they **fail** (Red phase)

- [~] Task 2.2: Remove Gate 0 & Rewire Storage Call
  - [ ] Delete the entire Gate 0 block (lines 144–158): fingerprint construction, `isSmsProcessed()` check, `cacheSmsFingerprint()` call
  - [ ] Replace `await storage.enqueueOverlayData(overlayArgs)` (line 204) with `await storage.saveCurrentActiveSms(overlayArgs)`
  - [ ] Remove any remaining imports/references to fingerprint methods
  - [ ] Run tests — confirm they **pass** (Green phase)

- [ ] Task 2.3: Update Related Pipeline Tests
  - [ ] Update `dynamic_overlay_update_test.dart`: remove fingerprint mocks, use `saveCurrentActiveSms` stubs
  - [ ] Update `subscription_ttl_test.dart`: remove fingerprint/vault mocks, use new API stubs
  - [ ] Run all pipeline tests — confirm pass

- [ ] Task 2.4: Verify Pipeline Compiles End-to-End
  - [ ] Run `flutter analyze` on `lib/core/services/sms_processing_pipeline.dart`
  - [ ] Run full pipeline test suite

- [ ] Task: Phase Verification & Checkpoint (Refer to workflow.md)

---

## Phase 3: Overlay Lifecycle — Instant-Kill Rewrite

> **Goal:** Rewrite `OverlayProvider` and `TransactionOverlayScreen` to use the Instant-Kill pattern with zero queue logic.

- [ ] Task 3.1: Write Failing Tests for Overlay Provider
  - [ ] Update `overlay_provider_test.dart`: replace all queue/vault mocks with `saveCurrentActiveSms`/`readCurrentActiveSms`/`clearCurrentActiveSms` stubs
  - [ ] Add test: `submitTransaction()` calls `clearCurrentActiveSms()` before fire-and-forget write
  - [ ] Add test: `submitTransaction()` calls `closeOverlay()` — no dequeue attempt
  - [ ] Add test: `close()` calls `clearCurrentActiveSms()` then `closeOverlay()`
  - [ ] Add test: `dismissAll()` calls `clearCurrentActiveSms()` then `closeOverlay()`
  - [ ] Run tests — confirm they **fail** (Red phase)

- [ ] Task 3.2: Rewrite OverlayProvider
  - [ ] Remove `_queueCount` field and `updateQueueCount()` method
  - [ ] Remove `queueCount` getter (and its `Selector` usage downstream)
  - [ ] Rewrite `submitTransaction()`:
    1. Validate wallet + auth (unchanged)
    2. `await _localStorageService.clearCurrentActiveSms()`
    3. `unawaited(_overlayUseCase.execute(...))`
    4. IPC `'update_ui'` via `IsolateNameServer`
    5. `await FlutterOverlayWindow.closeOverlay()`
  - [ ] Rewrite `close()`: clear key → close overlay
  - [ ] Rewrite `dismissAll()`: clear key → close overlay
  - [ ] Remove all `dequeueOverlayData` / `getOverlayQueueLength` / `clearVault` calls
  - [ ] Run tests — confirm they **pass** (Green phase)

- [ ] Task 3.3: Rewrite TransactionOverlayScreen Initialization
  - [ ] Replace `dequeueOverlayData()` with `readCurrentActiveSms()` in `initState`
  - [ ] Remove `getOverlayQueueLength()` calls
  - [ ] Remove `updateQueueCount()` calls
  - [ ] Remove queue count badge widget (the `Selector<OverlayProvider, int>` block, lines ~282–307)
  - [ ] Keep `overlayListener` stream with self-event filter for live SMS updates
  - [ ] Keep instant focus via `addPostFrameCallback`

- [ ] Task 3.4: Update Overlay-Related Tests
  - [ ] Update `transaction_overlay_commission_clear_test.dart`: replace vault/queue mocks with new single-key stubs
  - [ ] Update `phase1_data_duplication_stale_state_test.dart`: replace `dequeueOverlayData`/`clearVault` mocks
  - [ ] Run all overlay tests — confirm pass

- [ ] Task 3.5: Verify Overlay Layer Compiles End-to-End
  - [ ] Run `flutter analyze` on overlay files
  - [ ] Run full overlay test suite

- [ ] Task: Phase Verification & Checkpoint (Refer to workflow.md)

---

## Phase 4: Test Suite Cleanup & Final Verification

> **Goal:** Ensure all remaining test files compile and pass, and the full project is clean.

- [ ] Task 4.1: Update Remaining Test Files
  - [ ] Update `unified_keys_test.dart`: replace `saveToVault`/`readFromVault` with new API methods
  - [ ] Update `sms_queue_and_key_separation_test.dart`: remove queue-specific tests, add single-key overwrite tests
  - [ ] Update `local_storage_security_test.dart`: replace `saveToVault`/`readFromVault`/`clearVault` mocks
  - [ ] Update `overlay_usecase_test.dart`: replace `saveToVault` mock
  - [ ] Update `phase4_tech_debt_test.dart`: replace `saveToVault` mock

- [ ] Task 4.2: Full Project Verification
  - [ ] Run `flutter analyze` — zero errors
  - [ ] Run `CI=true flutter test` — all tests pass
  - [ ] Verify SMS parsing engine files are **completely unmodified** (`git diff` check)

- [ ] Task 4.3: Update Tech Stack Documentation
  - [ ] Update `conductor/tech-stack.md` Local Storage section: replace "Unified Vault Architecture" queue description with Single-Item architecture
  - [ ] Update `conductor/tech-stack.md` Background Architecture section: replace "Single-Isolate Guardian" queue references with single-key overwrite model
  - [ ] Add dated note documenting the architectural pivot

- [ ] Task: Phase Verification & Checkpoint (Refer to workflow.md)
