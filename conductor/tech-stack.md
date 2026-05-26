# Wallet Manager Tech Stack

## Framework
- **Flutter (Dart):** For cross-platform mobile application development, utilizing `compute()` for background isolate processing of intensive operations.

## Backend
- **Firebase:** Comprehensive backend suite, using O(1) Firestore lookups for authentication. Uses WriteBatch for non-reading atomic operations (e.g., wallet creation) to bypass transaction ordering constraints.
    - **Authentication:** Managing owner (Google/Email) and employee (PIN) logins.
    - **Cloud Firestore:** Scalable NoSQL database. Optimized for $O(1)$ aggregate queries via a centralized `stats/summary` architecture to minimize billing and latency.
    - **Analytics & Performance:** Monitoring user behavior and app health.

## State Management
- **Provider:** Primary state management solution.
    - `SafeChangeNotifier` (Custom): Base class with microtask-wrapped `safeNotify()` and disposal guards.
    - `Selector`: For granular, field-level rebuild optimization.
    - `ProxyProvider`: For cross-provider dependencies.
    - `context.read<T>()`: For action-only provider access.

## Dependency Injection
- **GetIt:** For centralized service and repository registration and decoupled access.
    - Includes `AppEvents` bus for decoupled system events.
    - Provides a unified `FirebaseService` for managed access to Firestore and Auth instances.

## Local Storage
- **Unified Vault Architecture:** Centralized `LocalStorageService` acting as the single source of truth for all disk I/O, abstracting `SharedPreferences` (non-sensitive) and `flutter_secure_storage` (sensitive data) and providing safe data persistence for both UI and background isolates.

## Background Architecture & OS Resilience
- **Single-Isolate Guardian:** Persistent background service (`flutter_background_service`) acting as the single source of truth for SMS automation to prevent data duplication.
- **Hybrid Kill-Switch:** State-aware service lifecycle management that calls `stopSelf()` when features are disabled to minimize battery impact and resource usage.
- **Smart Error Handling:** Context-aware error routing via `AppErrorHandler` that displays UI feedback in the foreground and triggers actionable Local Notifications (`flutter_local_notifications`) in the background. Includes mandatory stack trace capture and propagation via `catch (e, stack)` across all layers, and enforced Clean Architecture boundaries by replacing hardcoded strings in repositories with localized exception codes.
- **OS Constraint Strategy:** Explicit handling of modern Android (12+) constraints, including Battery Optimization exemption requests and high-priority notification triggers for overlay reliability.
- **Isolate Permission Guarding:** Strict enforcement of permission requests (Battery, Notifications, SMS) solely from the main UI isolate to prevent background crashes and comply with modern OS constraints.
- **Dynamic Overlay Refresh:** Resilient overlay communication using `shareData()` for state updates instead of the close/reopen pattern, ensuring stability on restrictive ROMs.
- **Graceful Failure UI:** Dedicated fallback Error UI for overlay initialization failures to prevent silent crashes and guide user recovery.

## Tools & Utilities
- **Internationalization:** `flutter_localizations` and `intl` for bilingual support.
    - **Logical Layout Migration:** Global transition from physical (`EdgeInsets`, `left`/`right`) to logical (`EdgeInsetsDirectional`, `start`/`end`) constraints for seamless RTL/LTR mirroring.
    - **Ambient Locale Propagation:** Removal of hardcoded directionality logic in favor of ambient locale propagation via `MaterialApp` and `Localizations`.
- **Security:** `cryptography` for hardened PBKDF2 (600,000 iterations) with unique salts and constant-time comparison, `crypto` for HMAC subscription cache integrity, and `uuid` for unique identifiers. Includes:
    - **PII Sanitization:** Automated masking of phone numbers and financial data in logs and error reports via `AppErrorHandler`.
    - **Secure Storage:** Mandatory use of `flutter_secure_storage` for sensitive session identifiers (`userId`, `storeId`, `userRole`).
    - **Global Role Enums:** Strict `UserRole` Enum (`owner`, `employee`, `unknown`) replacing all string-based role comparisons.
    - **Post-Fetch Repository Guards:** Mandatory `expectedStoreId` verification for all document fetches to prevent cross-tenant data leakage.
    - **RouteGuard Middleware:** Centralized authorization interceptor in `AppRouter` blocking unauthorized screen access based on granular permissions.
    - **Fail-Closed Enum Parsing:** Robust error handling in Enum conversion defaulting to zero-permission `unknown` states.
    - **Firestore Rule Fortification:** Role-based write restrictions and multi-layer read-access denials for sensitive collections like `license_keys`.
    - **Leaked Data Prevention:** Global `kDebugMode` guards for all `debugPrint` calls to prevent sensitive data leakage in release builds.
- **Data Integrity:** Centralized `NumberParser` utility for safe numeric parsing and null-safety from dynamic sources.
- **Background State TTL:** Strict 24-hour Time-to-Live (TTL) enforcement for subscription and critical metadata in the background isolate, triggering user re-validation via actionable notifications if data becomes stale.
- **Financial Integrity:** Epsilon-aware balance sufficiency checks (0.01 EGP tolerance), atomic Firestore transactions and FieldValue.increment() for all wallet, balance, and stat counter updates, and $O(1)$ aggregate synchronization. Includes a "Zero-Unbounded-Read" guarantee by utilizing Firestore Aggregate Queries and cursor-based pagination for all list operations.
- **Domain Fortification:** Type-safe Enums for all statuses/types and centralized `AmountValidator` guards.
- **Reactive Resilience:** Error-aware Stream pipelines, stateless repository pagination, and transparent exception propagation from providers to the UI layer. Includes explicit `finally` blocks in all async UI flows to guarantee state reset (e.g., `isLoading = false`) and prevent infinite loading states, and a fatal error failsafe via `runZonedGuarded` in `main.dart` ensuring all uncaught exceptions are reported to Crashlytics before termination.
- **Performance Optimization:** Efficient document batching (450-item chunks) to bypass Firestore's 500-operation limit during bulk resets. Includes a "Zero-Unbounded-Read" guarantee for statistical operations by utilizing Firestore Aggregate Queries (count/sum) instead of full collection fetches. **Flat Sliver-Driven Layouts** (CustomScrollView) globally replace nested ListViews and shrinkWrap to eliminate layout overhead and OOM crashes on low-end devices. **ThemeData Caching** and **Granular Selectors** minimize object allocation and redundant rebuilds in high-frequency UIs like the transaction overlay.