# Spec: Single-Item / Instant-Kill SMS Processing Pivot

## Overview

The Wallet Manager's SMS automation pipeline currently uses a **FIFO Queue** (`pending_overlay_data` in `SharedPreferences`) and a **Fingerprint Deduplication Cache** to bridge parsed SMS data from the background isolate to the overlay UI isolate. Due to `SharedPreferences` disk I/O bottlenecks and multi-isolate sync delays, this architecture causes:

- **Duplicated overlay windows** (race conditions on `reloadDisk()`)
- **UI lag** (multiple async disk reads per SMS cycle)
- **Stale data rendering** (FIFO order violations under concurrency)

This refactor pivots to a **Single-Item / Instant-Kill** architecture: one cache key, no queues, no fingerprints. An incoming SMS overwrites the single key. Submit or Cancel instantly purges the key and closes the overlay.

## Functional Requirements

### FR-1: Single-Item Storage API

Replace all queue and fingerprint methods in `LocalStorageService` with three atomic operations on a single `SharedPreferences` key (`'current_active_sms'`):

| New Method | Behavior |
|---|---|
| `saveCurrentActiveSms(Map<String, dynamic>)` | JSON-encode and overwrite the single key |
| `readCurrentActiveSms() → Map<String, dynamic>?` | JSON-decode and return (synchronous read after init, no `reloadDisk()` needed) |
| `clearCurrentActiveSms()` | Remove the single key |

**Deleted methods (10 total):**
- Queue: `enqueueOverlayData`, `dequeueOverlayData`, `peekOverlayData`, `getOverlayQueueLength`, `clearVault`, `saveToVault`, `readFromVault`
- Fingerprint: `isSmsProcessed`, `cacheSmsFingerprint`, `getRecentSmsFingerprints`

**Deleted constants (5 total):**
- `_kRecentSmsFingerprints`, `_kMaxSmsFingerprints`, `_kPendingOverlayData`, `_kCompletedTxSync`, `_kMaxOverlayQueueSize`

### FR-2: Pipeline Simplification

In `SmsProcessingPipeline.handleIncomingSms()`:

- **Remove** Gate 0 fingerprint/idempotency block (lines 144–158): no fingerprint construction, no `isSmsProcessed()` check, no `cacheSmsFingerprint()` call.
- **Replace** `enqueueOverlayData(overlayArgs)` (line 204) with `saveCurrentActiveSms(overlayArgs)`.
- **Preserve** all other guards: feature flag, subscription checks, 24h staleness, overlay permission, notification trigger, `shareData()` for live updates.

### FR-3: Instant-Kill Overlay Lifecycle

#### Submit Flow (`OverlayProvider.submitTransaction`)
1. Validate wallet selection & auth cache (unchanged)
2. `await _localStorageService.clearCurrentActiveSms()` — **Instant-Kill**
3. `unawaited(_overlayUseCase.execute(...))` — Fire-and-Forget Firestore write
4. Send IPC `'update_ui'` via `IsolateNameServer` (unchanged)
5. `await FlutterOverlayWindow.closeOverlay()` — Instant close, no queue-advance

#### Cancel/Close Flow (`OverlayProvider.close`)
1. `await _localStorageService.clearCurrentActiveSms()`
2. `await FlutterOverlayWindow.closeOverlay()`

#### Dismiss All Flow (`OverlayProvider.dismissAll`)
1. `await _localStorageService.clearCurrentActiveSms()`
2. `await FlutterOverlayWindow.closeOverlay()`

#### State Cleanup
- **Remove** `_queueCount` field and `updateQueueCount()` method from `OverlayProvider`
- **Remove** all `dequeueOverlayData()` / `getOverlayQueueLength()` calls

### FR-4: Overlay Screen Initialization

In `TransactionOverlayScreen`:

- **Replace** `dequeueOverlayData()` with `readCurrentActiveSms()` in `initState`
- **Remove** `getOverlayQueueLength()` calls and `updateQueueCount()` wiring
- **Remove** queue count badge UI (the `Selector<OverlayProvider, int>` on `queueCount`)
- **Keep** `overlayListener` stream for live SMS overwrites (newest SMS wins silently)
- **Keep** self-event filter (`action == 'local_deduct'`)
- **Keep** instant focus via `addPostFrameCallback`

### FR-5: Silent Collision Handling

When a new SMS arrives while the overlay is open:
1. `saveCurrentActiveSms()` overwrites the cache key (pipeline side)
2. `FlutterOverlayWindow.shareData()` pushes the new data to the overlay (pipeline side)
3. The overlay's `overlayListener` receives the event and calls `ingestNewEvent()` — the UI updates instantly with the new SMS data
4. No toast, no prompt, no queue — newest SMS wins

### FR-6: Test Updates

Update all 11 affected test files to:
- Replace mocked queue/fingerprint method stubs with new single-item method stubs
- Remove test cases validating FIFO ordering, fingerprint deduplication, and queue draining
- Add test cases for the new overwrite-and-kill semantics

## Non-Functional Requirements

- **NFR-1: Reduced Disk I/O** — Eliminate multiple `reloadDisk()` calls per SMS cycle; `readCurrentActiveSms()` may use a synchronous read path since data is written immediately before overlay launch
- **NFR-2: Zero Race Conditions** — Single-key overwrite is atomic by nature; no ordering assumptions
- **NFR-3: No Performance Regression** — Overlay open-to-close latency must remain ≤100ms

## Acceptance Criteria

- [ ] All 10 deleted methods are removed from `LocalStorageService` with zero compilation errors
- [ ] All 5 deleted constants are removed
- [ ] 3 new methods (`save`/`read`/`clear CurrentActiveSms`) exist and work correctly
- [ ] Gate 0 fingerprint block is fully removed from `SmsProcessingPipeline`
- [ ] Pipeline writes to single key instead of queue
- [ ] Submit flow: clears key → fire-and-forget write → IPC → close (no dequeue)
- [ ] Close flow: clears key → close (no dequeue)
- [ ] DismissAll flow: clears key → close
- [ ] No `queueCount` state, no queue badge in overlay UI
- [ ] Overlay initializes from `readCurrentActiveSms()` instead of dequeuing
- [ ] New SMS while overlay is open silently overwrites and updates UI
- [ ] All 11 test files compile and pass
- [ ] `flutter analyze` passes with zero new errors
- [ ] SMS parsing engine (`SmsParserEngine`, `SmsParserStrategy`) is completely untouched

## Out of Scope

- SMS parsing regex/anchor logic
- Notification trigger logic
- Subscription/feature-flag guard logic
- Overlay UI layout, theming, or localization
- Firebase/Firestore write logic in `OverlayUseCase`
- Main app isolate providers (`WalletProvider`, `TransactionProvider`, etc.)
