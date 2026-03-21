------------------------------------
Project Tech Stack Report
------------------------------------

1) Core Technologies
- Programming Languages: Dart (Main), Kotlin (Android Specific), Swift (iOS Specific).
- Framework: Flutter (3.0.0+).
- Application Type: Cross-platform Mobile App (Android & iOS).

2) Architecture
- Architecture Pattern: Layered Architecture with MVVM characteristics.
- State Management: Provider (using MultiProvider, ChangeNotifierProvider, and ChangeNotifierProxyProvider).
- Organization: Separated into 'core' (services, utils, constants, widgets), 'data' (models, repositories, services), 'presentation' (screens, widgets, overlays), and 'providers'.

3) Dependencies & Packages
State Management:
- provider: Core state management solution.
- rxdart: Reactive extensions for streams and data flow.

Firebase / Backend:
- firebase_core: Core Firebase initialization.
- firebase_auth: User authentication management.
- cloud_firestore: NoSQL database for real-time data storage.
- firebase_analytics: App usage and event tracking.
- firebase_performance: Application performance monitoring.
- google_sign_in: OAuth authentication for Google accounts.

Storage:
- shared_preferences: Local persistent storage for user settings and auth states.

UI & UX:
- cupertino_icons: iOS-style iconography.
- font_awesome_flutter: Extensive set of customizable icons.
- shimmer: Placeholder loading effects for list items.
- bot_toast: Specialized toast notifications and loading overlays.
- awesome_dialog: Beautiful and customizable alert dialogs.
- flutter_native_splash: Native-level splash screen management.
- flutter_launcher_icons: Automated app icon generation.

Utilities:
- intl: Internationalization, date/number formatting.
- crypto: Hashing and cryptographic operations (e.g., license keys).
- uuid: Unique identifier generation for transactions and entities.
- url_launcher: Ability to open external URLs, emails, and phone calls.
- collection: Helper functions for managing Dart collections.
- device_info_plus: Accessing hardware and OS metadata.
- package_info_plus: Accessing application version and package name details.

Platform-Specific (Android Interoperability):
- another_telephony: SMS interception and telephony services.
- flutter_overlay_window: Drawing interactive UI overlays over other apps.
- flutter_background_service / flutter_background_service_android: Persistent background execution for automation.
- flutter_local_notifications: Local notification management.

4) Backend & Services
- Authentication: Firebase Auth (Email/Password, Google Sign-In).
- Database: Cloud Firestore (Collections for: users, stores, wallets, transactions, debts, employees, and licenses).
- Analytics: Firebase Analytics for user behavior tracking.
- Performance: Firebase Performance Monitoring for latency and app health.
- Local Storage: SharedPreferences-based 'LocalStorageService' for theme, language, and store-specific configuration caching.

5) Platform-Specific Details
Android:
- Language: Kotlin (interfaced via Flutter plugins).
- Build System: Gradle with Kotlin DSL (.kts).
- Custom Integrations: 
    - IncomingSmsReceiver (BroadCast Receiver) for transaction automation via SMS.
    - OverlayService for floating transaction summaries.
    - Foreground Service (Guardian Isolate) for persistent background monitoring.
- Permissions: SMS interception, Overlay Window, Boot completion, Foreground service.

iOS:
- Language: Swift.
- Standard Flutter configuration with no identified custom native plugins beyond standard SDK defaults.

6) Tools & Build System
- Build Automation: Gradle (Android).
- Package Management: Pub (Dart/Flutter).
- Static Analysis: flutter_lints (with custom rules in analysis_options.yaml).
- Internationalization: arb-based localization (Arabic & English).
- Code Generation: flutter_gen (for assets and localizations).

7) Integrations & Permissions
External Services:
- Google Sign-In (Identity).
- Firebase Suite (Backend).

Permissions (Android):
- android.permission.RECEIVE_SMS: To intercept incoming bank SMS.
- android.permission.READ_SMS: To process SMS content for automation.
- android.permission.SYSTEM_ALERT_WINDOW: To show the transaction overlay.
- android.permission.FOREGROUND_SERVICE: To keep automation running in background.
- android.permission.WAKE_LOCK: To ensure processing of events.
- android.permission.RECEIVE_BOOT_COMPLETED: To restart automation after device reboot.
- android.permission.POST_NOTIFICATIONS: For status updates and alerts.

------------------------------------
VALIDATION STEP
------------------------------------
- Total number of technologies/packages identified: ~56
- Confirmation: FULL recursive scan of lib/, android/, ios/, and root config files completed.
- Expected items NOT found: No local SQLite or Hive usage detected (Firebase & SharedPreferences handle all storage). No CI/CD configuration files (like .github or fastlane) found in the root.

------------------------------------
