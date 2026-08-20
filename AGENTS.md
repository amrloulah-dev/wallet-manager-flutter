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
8. **Optimistic Math Parity** — All providers (`WalletProvider`, `StatisticsProvider`) MUST apply identical formulas for financial mutations (e.g., deducting `amount + serviceFee` for debits), guaranteeing 100% RAM parity before Firestore confirmation.
9. **Fine-Grained Live Financial Selectors** — Live liquid metrics (`totalBalance`) MUST be bound using dedicated `Selector<StatisticsProvider, double>` subscribing directly to `dashboardSummary.totalBalance`, rather than date-filtered snapshots or static widget state.

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

## UI & Theming Rules
1. **Dynamic Theme Compliance** — Never hardcode static theme colors (e.g., `Colors.black`, `Colors.white`, `Colors.grey.shade900`, `0xFF1E1E1E`). All backgrounds, borders, dividers, and text colors MUST dynamically resolve via `ThemeData` and `AppColors` tokens (e.g., `AppColors.surface(context)`, `AppColors.textPrimary(context)`, `AppColors.textSecondary(context)`, `AppColors.divider(context)`).
2. **Unicode LTR Phone Number Guarding** — All displayed phone numbers in RTL/Arabic interfaces MUST be wrapped in LTR Unicode markers (`'\u200E${phone}\u200E'`) and specify `textDirection: TextDirection.ltr` to avoid number reversal and punctuation misplacement.

## Background Services
- **SMS Monitor**: `flutter_background_service` + `another_telephony`; parses transaction SMS and shows overlay
- **Overlay Window**: `flutter_overlay_window`; entry via `overlayMain()`, uses `IsolateNameServer` to communicate with main isolate
- **Vault SSOT & Disk Synchronization**: `readFromVault()` MUST be `async` and execute `await reloadDisk()` before reading `SharedPreferences` to ensure multi-isolate disk cache sync.
- **Overlay Vault-First Initialization**: `TransactionOverlayScreen` MUST read from the Vault (`readFromVault()`) upon mounting as the primary source of truth, rather than relying 100% on transient `overlayListener` stream events.
- **Stream Event Filtering**: `overlayListener` MUST filter out self-emitted broadcast actions (e.g. `event['action'] == 'local_deduct'`) to prevent stream self-pollution.
- **Ephemeral Vault Cleanup**: `clearVault()` MUST be called immediately after vault ingestion on overlay boot, as well as during teardown (`submitTransaction()` and `close()`), preventing stale data bleed across SMS sessions.
- **Dynamic Service Lifecycle**: UI toggles controlling background service status MUST invoke dynamic controllers (`startBackgroundMonitoring()` / `stopBackgroundMonitoring()`) in `onChanged` handlers immediately after persisting storage state.
- **Cold-Boot Configuration Guard**: `startBackgroundMonitoring()` MUST verify configuration status (`_isConfigured`) and execute `initializeBackgroundService()` if invoked before cold boot initialization completes.
- **Toggle Debouncing & Rollback**: Toggle UI handlers MUST use an async lock (`_isToggling`) to prevent rapid tap collisions and execute full state rollbacks (reverting `SharedPreferences` + UI switch) if dynamic service start fails.
- **Multi-Isolate Cache Key Symmetry**: When caching lite models in `LocalStorageService` for consumption by background/overlay isolates (e.g., `cacheWalletLiteList`), always serialize both primary and alias property keys (e.g., `'walletType'` and `'type'`, `'phone'` and `'phoneNumber'`) to guarantee robust cross-isolate deserialization.
- **Overlay Dropdown Responsiveness & Selected State Flex Density**: In constrained windows (e.g., `TransactionOverlayScreen`):
  - Differentiate between dropdown popup items (`itemWidgetBuilder`) and closed selected item views (`selectedItemWidgetBuilder`).
  - Dropdown content padding must use compact insets (`contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6)`).
  - Allocate priority flex to phone numbers (`Expanded(flex: 3, ...)` with `softWrap: false`) and wrap secondary badges with `Flexible(flex: 2, fit: FlexFit.loose, ...)`.

## Firestore
- Rules: `firestore.rules` (enforces owner/employee access per `storeId`)
- Indexes: `firestore.indexes.json`
- Collections: `stores/`, `stores/{id}/stats/`, `stores/{id}/daily_stats/`, `wallets/`, `transactions/`, `debts/`, `users/`, `device_registrations/`, `license_keys/`
- **Atomic Stats Aggregation**: In Firestore transaction closures (`TransactionValidatorService.validateAndSave`), aggregate documents (`stores/{storeId}/stats/summary`) MUST atomically update `totalBalance` via `FieldValue.increment(balanceChange)` alongside transaction and volume counters.
- **Read-Before-Write Phase Ordering**: In all `_firestore.runTransaction` blocks, all document reads (`tx.get(statsSummaryRef)`) MUST precede all mutations (`tx.update` / `tx.set(..., SetOptions(merge: true))`).
- **Repository Status Idempotency**: Methods toggling entity status with attached stats side-effects (e.g., `WalletRepository.setWalletActiveStatus`) MUST verify current status (`if (entity.isActive == isActive) return;`) before executing balance/counter adjustments.

## Analysis Notes
- Config: `analysis_options.yaml`
- Suppressed: `non_constant_identifier_names`, `deprecated_member_use`, `subtype_of_sealed_class` (intentional)
- Lint set: `package:flutter_lints/flutter.yaml`
