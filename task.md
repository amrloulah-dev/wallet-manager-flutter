# Phase 8.1 — Background Services Remediation Tasks

## WS1: Isolate Visibility & Firebase Cold-Start
- [x] Rename `_backgroundSmsCallback` → `backgroundSmsCallback` + update reference
- [x] Rename `_onIosBackground` → `onIosBackground` + update reference
- [x] Add safe Firebase init in `backgroundSmsCallback`
- [x] Replace `debugPrint` with `AppErrorHandler.logSilentError` in catch block
- [x] Add required imports

## WS2: 24h Subscription TTL & Unique Notification IDs
- [/] Add `_kSubLastSyncMs` key, accessors, and `isSubscriptionSyncFresh` to `LocalStorageService`
- [ ] Call `saveSubLastSyncMs()` in `SubscriptionProvider._syncToStorage()`
- [ ] Add 24h TTL guard + `_showStaleSyncNotification()` in `sms_processing_pipeline.dart`
- [ ] Replace hardcoded notification ID `0` with unique hash

## WS3: Unified Vault & Clean DI
- [ ] Refactor `OverlayRepository` to use `LocalStorageService` (DELETE class)
- [ ] Update `service_locator.dart` — remove OverlayRepository registration
- [ ] Update `OverlayUseCase` to use `LocalStorageService` directly
- [ ] Migrate `GlobalOverlayListener` off orphan key to `LocalStorageService`

## WS4: Overlay Dynamic Update & Graceful Failure
- [ ] Replace close/reopen overlay logic with dynamic `shareData()`
- [ ] Wrap entire `overlayMain` in try-catch, rename failsafe widget to `OverlayErrorApp`

## WS5: debugPrint Guards
- [ ] Guard all unguarded `debugPrint` calls in `wallet_provider.dart`

## Additional Refactors (per architect directive)
- [ ] Refactor `LocalizationProvider` to use `LocalStorageService`
- [ ] Add locale methods to `LocalStorageService` if needed

## Verification
- [ ] Run `flutter analyze`
- [ ] Run `flutter test`
