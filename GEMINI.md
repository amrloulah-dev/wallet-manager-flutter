# Wallet Manager - Gemini Context

This document provides essential context and instructions for AI agents working on the Wallet Manager project.

## Project Overview
Wallet Manager is a Flutter-based application designed for store owners and businesses to manage financial wallets, transactions, debts, and employee access. It provides a centralized platform to track cash flows across various payment methods (Vodafone Cash, InstaPay, etc.), enforce transaction limits, and monitor business performance through detailed statistics.

### Key Capabilities
- **Multi-Provider Wallet Support:** Specialized logic for providers like Vodafone Cash, InstaPay, Orange Cash, Etisalat Cash, and WE Pay.
- **Transaction Limit Enforcement:** Automatic validation of Daily and Monthly limits.
- **SMS Automation:** Background monitoring of transaction SMS to automate recording (Guardian Isolate).
- **Overlay Interface:** A specialized overlay window for quick transaction handling.
- **Role-Based Access:** Granular permissions for owners and employees.
- **Subscription System:** License management with trial and premium tiers.

## Tech Stack
- **Framework:** Flutter (Dart)
- **Backend:** Firebase (Authentication, Firestore, Analytics, Performance, Crashlytics)
- **State Management:** `provider` (ChangeNotifier, ProxyProvider)
- **Dependency Injection:** `get_it` (Service Locator)
- **Local Storage:** `shared_preferences`
- **Navigation:** `go_router` (or custom `AppRouter` as seen in `lib/routes/`)
- **Localization:** `flutter_localizations`, `intl` (using `.arb` files)

## Architecture
The project follows a variant of **Clean Architecture** with a clear separation of concerns:

- **`lib/core/`**: Shared utilities, constants, theme, DI setup, and error handling.
- **`lib/domain/`**: Business logic, entities (if separate), and usecases.
- **`lib/data/`**: Implementation details, models (serialization), repositories, and services.
- **`lib/presentation/`**: UI layer (screens, widgets, overlays).
- **`lib/providers/`**: State management layer using `ChangeNotifier`.
- **`lib/routes/`**: Navigation logic and route definitions.

## Key Commands
- **Install Dependencies:** `flutter pub get`
- **Run the App:** `flutter run`
- **Run Tests:** `flutter test`
- **Analyze Code:** `flutter analyze`
- **Format Code:** `dart format .`
- **Localization Generation:** `flutter gen-l10n` (based on `l10n.yaml`)

## Development Conventions

### Coding Style
- **Naming:** Follow standard Dart naming conventions (`PascalCase` for classes, `camelCase` for variables/methods, `snake_case` for files).
- **Immutability:** Prefer final fields in models and widgets.
- **Separation of Concerns:** Keep UI logic in Providers and data fetching in Repositories.
- **Error Handling:** Use `AppErrorHandler` for consistent error reporting and logging.
- **Service Locator:** Access shared instances via `sl<Type>()`.

### State Management Patterns
- Use `ChangeNotifier` for complex state.
- Use `ProxyProvider` when a provider depends on another (e.g., `SubscriptionProvider` depending on `AuthProvider`).
- Prefer `Consumer` or `context.watch<T>()` for UI reactivity.

### Navigation
- Use `RouteConstants` for route names.
- Navigation should be handled via the `NavigationService` or `AppRouter`.

## Important Files
- `lib/main.dart`: App entry point and initialization logic.
- `lib/app.dart`: `MaterialApp` configuration and provider setup.
- `lib/core/di/service_locator.dart`: Dependency injection registrations.
- `lib/core/constants/route_constants.dart`: Centralized route name definitions.
- `pubspec.yaml`: Project dependencies and Flutter configuration.
- `analysis_options.yaml`: Linter and analyzer rules.
- `firebase.json` & `firestore.rules`: Firebase configuration and security rules.

## SMS & Background Tasks
- **Guardian Isolate:** Initialized in `main.dart` via `initializeBackgroundService()`. Monitors SMS in the background.
- **Overlay Window:** Entry point at `overlayMain()` in `main.dart`. Used for quick interaction when an SMS is received.

## Localization
- Supported languages: Arabic (`ar`), English (`en`).
- Templates located in `lib/l10n/arb/`.
- Use `AppLocalizations.of(context)!` to access strings in the UI.
