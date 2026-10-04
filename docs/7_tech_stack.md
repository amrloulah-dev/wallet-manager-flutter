# 🛠️ Report 7: Tech Stack & Ecosystem

## 1. Core Framework & Environment

**Flutter & Dart Versioning:**
- **Dart SDK Target:** `>=3.0.0 <4.0.0`
- **Flutter Framework:** Uses the standard `flutter` SDK mapping, indicating a modern stable release (likely Flutter 3.19+ given the dependency versions).

**Native Configurations:**
- **Android (`build.gradle.kts`):**
  - **Java/Kotlin Target:** Configured for `JavaVersion.VERSION_17` and Kotlin `jvmTarget = "17"`.
  - **Desugaring Enabled:** `isCoreLibraryDesugaringEnabled = true` is explicitly set with `com.android.tools:desugar_jdk_libs:2.0.4`. This is a critical configuration that allows the app to use modern Java 8+ time APIs (like `java.time`) on much older Android devices.
  - **Release Optimization:** The release build type strictly enables `isMinifyEnabled = true` and `isShrinkResources = true` using `proguard-rules.pro`, optimizing the final APK/AAB size and obfuscating code.
- **iOS:**
  - The project contains the standard iOS scaffolds (`Runner.xcodeproj`, `Runner.xcworkspace`), but currently lacks an initialized `Podfile`. This indicates the local environment has not yet run a build targeting iOS, or the project currently prioritizes Android-specific deployment (especially given the heavy reliance on SMS automation, which is impossible on iOS).

## 2. State Management & Architecture

**State Management:**
- `provider: ^6.1.5+1`: The primary state management solution. Used heavily via custom `SafeChangeNotifier` classes to maintain optimistic UI state and manage data across the widget tree.

**Dependency Injection & Architecture:**
- `get_it: ^9.2.1`: Acts as the Service Locator. Used to lazily initialize and retrieve Singletons (like Repositories and Services) from anywhere in the app, preventing massive constructor injection chains and decoupling the data layer from the UI.

## 3. Backend & Cloud Infrastructure (Firebase)

The project relies completely on Firebase for its backend infrastructure, utilizing almost the entire suite:

- `firebase_core: ^3.8.1`: Fundamental initialization required before any other Firebase service.
- `firebase_auth: ^5.3.3` & `google_sign_in: ^6.2.2`: Handles user identity. Supports standard email/password, and Google OAuth integration.
- `cloud_firestore: ^5.5.2`: The primary NoSQL database. Handles real-time syncing of wallets, transactions, employees, and stats.
- `firebase_analytics: ^11.6.0`: Tracks user behaviors, screen views, and custom business events (like "Transaction Created").
- `firebase_crashlytics: ^4.3.10`: Crucial for logging fatal and non-fatal errors (`AppErrorHandler` pipes errors here).
- `firebase_performance: ^0.10.0`: Monitors network latency, slow rendering frames, and startup times.

## 4. UI, Utilities & Native Integrations

**UI & Localization:**
- `flutter_localizations` & `intl: ^0.20.2`: Handles deep Arabic/English translation (`.arb` files) and currency/date formatting.
- `awesome_dialog: ^3.2.0`: Provides beautiful, animated alert dialogs (success/error popups).
- `bot_toast: ^4.1.3`: Handles sophisticated, context-less toast notifications and loading overlays.
- `shimmer: ^3.0.0`: Renders skeleton loading animations while Firestore fetches data.
- `cupertino_icons` & `font_awesome_flutter: ^10.7.0`: Extended icon libraries.

**Native & Hardware Bridge:**
- `shared_preferences: ^2.5.3`: General persistent local storage (used as the "Vault" for the background isolate).
- `flutter_secure_storage: 9.2.4`: Encrypted storage, likely used for sensitive tokens or license keys.
- `another_telephony: ^0.4.1`: Intercepts and reads raw SMS messages from the Android OS.
- `flutter_overlay_window: ^0.5.0`: Draws the "New Transaction" popup over other apps (System Alert Window).
- `flutter_background_service: ^5.1.0` & `flutter_background_service_android: ^6.3.1`: Manages the persistent, headless "Guardian Isolate" for background execution.
- `flutter_local_notifications: ^18.0.1`: Triggers high-priority intents to wake the device screen.
- `permission_handler: ^11.3.1`: Requests runtime OS permissions gracefully.
- `device_info_plus: ^12.4.0` & `package_info_plus: ^9.0.0`: Retrieves hardware specs and app versioning (often used for bug reports or Crashlytics logs).
- `url_launcher: ^6.3.2`: Opens external web links or dials phone numbers.

**Utilities:**
- `crypto: ^3.0.6` & `cryptography: 2.7.0`: Handles hashing (e.g., generating SHA-256 signatures or license keys).
- `uuid: ^4.5.2`: Generates unique identifiers for locally created transactions before they sync to Firestore.
- `rxdart: ^0.28.0`: Extends Dart streams for complex reactive programming pipelines.
- `collection: ^1.18.0`: Provides advanced list/map manipulation tools (like `firstWhereOrNull` or grouping).
- `ntp: ^2.0.0`: Fetches true network time, preventing users from spoofing their device clock to bypass subscription expiration dates.

## 5. Development Tools & Code Generation

**Testing:**
- `flutter_test`: The core Flutter unit/widget testing framework.
- `mocktail: ^1.0.3`: A null-safety compatible mocking library used for unit testing repositories without real implementations.
- `fake_cloud_firestore: ^3.1.0`: Creates a mocked, in-memory Firestore instance. This is a brilliant architectural choice that allows rapid, parallel database testing without the massive overhead of spinning up the Dockerized Firebase Emulator suite.

**Code Generators & Tooling:**
- `flutter_launcher_icons: ^0.13.1`: Automatically generates varying resolution Android (`mipmap`) and iOS app icons from a single source image (`assets/images/app_icon.png`).
- `flutter_native_splash: ^2.4.0`: Injects a native splash screen (`assets/images/native_screen.jpg`) that displays instantly while the Flutter engine is warming up, eliminating white-screen flicker.
- `flutter_lints: ^5.0.0`: Enforces strict Dart coding conventions and static analysis rules to maintain codebase health.
