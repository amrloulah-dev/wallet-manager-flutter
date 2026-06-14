# 🏗️ Report 3: Architecture & Initialization

## 1. Directory Structure & Architectural Pattern

The Wallet Manager application strictly adheres to a **Layer-First Clean Architecture** pattern. Rather than grouping by feature, the root of the `lib/` directory is partitioned by technical responsibility, ensuring a clean separation of concerns and testability.

### Overarching Folder Structure
*   **`lib/core/`**: Shared, app-wide utilities that don't belong to a specific feature. This includes Dependency Injection (`di/service_locator.dart`), error handling (`errors/app_error_handler.dart`), themes, constants, and global services like SMS processing.
*   **`lib/data/`**: The Data layer containing `models` (DTOs and serialization logic), `repositories` (handling the CRUD logic for Firestore), and `services` (third-party API wrappers, local storage).
*   **`lib/domain/`**: The Domain layer holding business logic encapsulations (`usecases/` like `TransactionFeeCalculator` and `OverlayUseCase`).
*   **`lib/presentation/`**: The UI layer. It is subdivided into `screens/` (grouped internally by feature like `auth`, `home`, `transactions`) and `widgets/` (reusable UI components).
*   **`lib/providers/`**: The State Management layer holding all `SafeChangeNotifier` subclasses that bind the UI to the Data/Domain layers.
*   **`lib/routes/`**: Centralized route definitions and navigation logic.
*   **`lib/l10n/`**: Localization and internationalization files (Arabic/English).

## 2. Tech Stack & Core Dependencies

An analysis of `pubspec.yaml` reveals the following core dependencies driving the app:

### State Management & Dependency Injection
*   **`provider`**: Used as the primary state management solution, binding UI `Consumer` and `Selector` widgets to domain logic.
*   **`get_it`**: A Service Locator pattern used to inject singletons (e.g., Repositories, Services, and core Providers) across the app, ensuring single-instance memory efficiency without cluttering the widget tree.

### Firebase Integration
*   **`firebase_core`**, **`cloud_firestore`**, **`firebase_auth`**: The primary backend infrastructure handling user authentication and NoSQL data storage.
*   **`firebase_crashlytics`**, **`firebase_performance`**, **`firebase_analytics`**: Telemetry and observability suite used in conjunction with the custom `AppErrorHandler`.

### Background & OS Integration
*   **`flutter_background_service`**: Runs the "Guardian Isolate" in the background even when the app is killed, necessary for intercepting SMS.
*   **`another_telephony`**: Listens for incoming SMS messages.
*   **`flutter_overlay_window`**: Requests `SYSTEM_ALERT_WINDOW` permission to draw UI elements (like the quick transaction dialog) directly over other apps on Android.
*   **`flutter_local_notifications`**: Used to send high-priority intents to wake the device screen when a background transaction occurs.

### UI / Styling / Utilities
*   **`shared_preferences`**: Used by `LocalStorageService` to cache sessions, theme preferences, and the "Vault" (secure offline data sharing between isolates).
*   **`intl`**: Core localization formatting (Currency, Dates).
*   **`crypto`** / **`cryptography`**: Used for hashing store passwords and PINs before sending them to the backend.
*   **`bot_toast`**: Used to present non-blocking popups from the global error handler.
*   **`awesome_dialog`**: Pre-built modal interactions.

## 3. App Bootstrapping & Lifecycle

The lifecycle in `main.dart` is carefully orchestrated to ensure safe booting, particularly because the app runs multiple isolates (the main UI and the background SMS service).

### Sequence of Events (`main()`)
1.  **Zone Guarding**: The entire application is wrapped in `runZonedGuarded` to catch unhandled asynchronous exceptions and route them to `AppErrorHandler`.
2.  **Binding**: `WidgetsFlutterBinding.ensureInitialized()` is called to allow asynchronous operations before `runApp`.
3.  **Error Init**: `AppErrorHandler.init()` hooks into `FlutterError.onError` and the Platform Dispatcher.
4.  **Firebase & DI**: `FirebaseService().initialize()` and `setupServiceLocator()` execute sequentially to ready the backend and inject dependencies.
5.  **SMS Start**: If `LocalStorageService.isSmsAutomationEnabled` is true, the `SmsService().init()` is triggered.
6.  **Run App**: `runApp(const MyApp())` kicks off the UI immediately.
7.  **Deferred Background Service**: A 3-second `Future.delayed` triggers `initializeBackgroundService()`. This deliberate delay ensures the heavy lifting of spawning a new isolate does not block the UI thread during the critical first render.

### Isolate Entry Point (`overlayMain()`)
Because `flutter_overlay_window` runs in a separate UI isolate, `main.dart` contains a secondary entry point annotated with `@pragma("vm:entry-point")`. When the overlay triggers, it must independently re-initialize Firebase and `setupServiceLocator()` before running `TransactionOverlayApp()`.

### MultiProvider Injection (`app.dart`)
At the root `MyApp` widget, a `MultiProvider` sets up the state tree. A notable architectural choice is the heavy reliance on **`ChangeNotifierProxyProvider`**. Providers like `WalletProvider` and `TransactionProvider` rely on the authentication state and subscription limits, so they are injected with `AuthProvider` and `SubscriptionProvider` to react dynamically to session changes.

## 4. Initialization Flow (Eager vs. Lazy Loading)

### Auth Wrapper
The app uses an `AuthCheckWrapper` as the `home` widget. Upon `initState`, it calls `auth.tryAutoLogin()`, reading cached tokens from `LocalStorageService`. While verifying credentials, it displays a `CircularProgressIndicator`.
*   If suspended: Renders `AdminBlockScreen`.
*   If authenticated: Replaces the route with `RouteConstants.mainDashboard`.
*   If expired: Pushes the `RouteConstants.upgradeScreen` (Paywall) *on top* of the Dashboard.

### Eager Initialization (Dashboard)
Upon arriving at `MainDashboardScreen`, the app utilizes an **Eager Initialization** strategy for the core user session data.
In `initState()`, a `Future.microtask` calls:
1.  `_initializeProviders()`: Injects the active `storeId` into `StatisticsProvider`, `WalletProvider`, and `DebtProvider`.
2.  `_fetchInitialData()`: Eagerly triggers network requests for:
    *   `fetchDashboardStats()`
    *   `fetchInitialWallets()`
    *   `fetchInitialTransactions()` (usually limited to the current day or recent X records)
    *   `fetchInitialDebts()`

### Lazy Loading Strategy
While the dashboard eagerly fetches *summary* and *recent* data, historical data is lazy-loaded. For example, scrolling down the "All Transactions" screen relies on pagination queries within `TransactionRepository` rather than pulling the entire Firestore collection into RAM at startup.

## 5. Routing & Navigation

### Routing Mechanism
The application avoids third-party router packages (like `go_router`) in favor of standard **Navigator 1.0 (Named Routes)** via `onGenerateRoute`.
*   All routes are centrally defined as static strings in `RouteConstants`.
*   `AppRouter.generateRoute` acts as the global switch statement.
*   **Global Navigator Key**: `NavigationService.navigatorKey` is injected into `MaterialApp`. This allows global utility classes (like `BaseProvider` and `AppErrorHandler`) to trigger navigation or show dialogs without needing a `BuildContext` passed down through every function.

### Navigation Transitions
`AppRouter` uses a custom `PageRouteBuilder` for all screens. It applies a unified `SlideTransition` (sliding in from the right: `Offset(1.0, 0.0)`) combined with a `FadeTransition`, providing a premium native feel across the app.

### Route-Level Security Guard
The `_buildRoute` function inside `AppRouter` acts as a middleware security guard.
1.  It checks if a route is "public" (e.g., `loginLanding`, `storeRegistration`).
2.  For private routes, it delegates to `PermissionHelper.canAccessScreen(context, routeName)`.
3.  If an Employee attempts to navigate to a screen they do not have `UserPermissions` for (e.g., `RouteConstants.manageEmployees`), the router intercepts the request, blocks the page build, redirects them to `RouteConstants.mainDashboard`, and displays an "Access Denied" toast.
