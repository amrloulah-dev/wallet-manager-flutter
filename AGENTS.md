# AGENTS.md — Wallet Manager

## Project Overview
Flutter/Dart mobile app (Android/iOS) for store owners to manage wallets, transactions, debts, and employees. Backend is Firebase (Auth, Firestore, Analytics, Crashlytics, Performance).

Firebase project: `ewallet-manager-421b8`

## Architecture
Clean Architecture with layered separation:
- `lib/core/` — Shared utilities, DI (`GetIt`), theme, errors, SMS automation
- `lib/domain/` — Business logic (`usecases/`, `entities/`)
- `lib/data/` — Models, repositories, services (Firebase, local storage)
- `lib/presentation/` — Screens and widgets
- `lib/providers/` — State management (`SafeChangeNotifier` subclasses)
- `lib/routes/` — Navigation via `AppRouter` + `NavigationService`

## Key Commands
```bash
flutter pub get                 # Install dependencies
flutter run                     # Run app (mobile)
flutter test                    # Run all tests
CI=true flutter test            # Non-interactive test run
flutter analyze                 # Static analysis
dart format .                   # Format code
flutter gen-l10n                # Generate localization (from lib/l10n/arb/)
```

## State Management Rules
Read `.specify/memory/constitution.md` — these are non-negotiable:

1. **Optimistic UI** — Mutate RAM first via provider, `safeNotify()` immediately, Firestore write in background
2. **No blanket `watch`** — Use `Selector<T, R>` or scoped `Consumer`, never `context.watch<T>()` at screen root
3. **No `StreamBuilder`** for Provider-managed data — RAM is source of truth; use `Consumer`/`Selector`
4. **O(1) lookups** — Providers keep `Map<String, Model>` (not lists) for wallets/transactions; access via `provider.map[id]`
5. **Safe rollbacks** — Capture previous state before optimistic mutation; on Firestore failure, revert + `safeNotify()` + show error
6. **Fetch shield** — After background isolate injects state, block auto-fetch for ~5s to prevent stale overwrite
7. **Composite `ValueKey`** — Use `ValueKey('${model.id}_${model.balance}')` on mutable list items (e.g., `WalletCard`)

## Custom Base Class
All providers extend `SafeChangeNotifier` (not `ChangeNotifier`):
- Calls `notifyListeners()` via microtask to avoid "rebuild during build" errors
- Tracks disposal state to prevent use-after-dispose

## Dependency Injection
`GetIt` service locator via `lib/core/di/service_locator.dart`:
- Access via `sl<Type>()`
- Call `await setupServiceLocator()` before running app
- Repositories/services registered as lazy singletons

## Entry Points
- `lib/main.dart:main()` — Primary app entry; initializes Firebase, DI, SMS service, background service
- `lib/main.dart:overlayMain()` — Overlay window entry (SMS-triggered quick transactions); marked with `@pragma("vm:entry-point")`

## Testing
- Framework: `flutter_test` + `mocktail` for mocking
- Firestore: `fake_cloud_firestore` (avoids emulator)
- Run single test: `flutter test test/path/to/file_test.dart`
- Tests mirror structure: `test/core/`, `test/domain/`, `test/data/`, `test/presentation/`, `test/providers/`

## Localization
- Languages: Arabic (`ar`), English (`en`)
- Config: `l10n.yaml` → template at `lib/l10n/arb/app_ar.arb`
- Access strings: `AppLocalizations.of(context)!`
- Regenerate after editing `.arb`: `flutter gen-l10n`

## Background Services
- **SMS Monitor**: `flutter_background_service` + `another_telephony`; parses transaction SMS and shows overlay
- **Overlay Window**: `flutter_overlay_window`; entry via `overlayMain()`, uses `IsolateNameServer` to communicate with main isolate
- **Vault SSOT & Disk Synchronization**: `readFromVault()` MUST be `async` and execute `await reloadDisk()` before reading `SharedPreferences` to ensure multi-isolate disk cache sync.
- **Overlay Vault-First Initialization**: `TransactionOverlayScreen` MUST read from the Vault (`readFromVault()`) upon mounting as the primary source of truth, rather than relying 100% on transient `overlayListener` stream events.
- **Stream Event Filtering**: `overlayListener` MUST filter out self-emitted broadcast actions (e.g. `event['action'] == 'local_deduct'`) to prevent stream self-pollution.
- **Ephemeral Vault Cleanup**: `clearVault()` MUST be called immediately after vault ingestion on overlay boot, as well as during teardown (`submitTransaction()` and `close()`), preventing stale data bleed across SMS sessions.

## Firestore
- Rules: `firestore.rules` (enforces owner/employee access per `storeId`)
- Indexes: `firestore.indexes.json`
- Collections: `stores/`, `stores/{id}/stats/`, `stores/{id}/daily_stats/`, `wallets/`, `transactions/`, `debts/`, `users/`, `device_registrations/`, `license_keys/`

## Analysis Notes
- Config: `analysis_options.yaml`
- Suppressed: `non_constant_identifier_names`, `deprecated_member_use`, `subtype_of_sealed_class` (intentional)
- Lint set: `package:flutter_lints/flutter.yaml`
