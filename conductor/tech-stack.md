# Wallet Manager Tech Stack

## Framework
- **Flutter (Dart):** For cross-platform mobile application development.

## Backend
- **Firebase:** Comprehensive backend suite.
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
- **Shared Preferences:** Storing local settings and non-sensitive metadata.

## Background Architecture & OS Resilience
- **Single-Isolate Guardian:** Persistent background service (`flutter_background_service`) acting as the single source of truth for SMS automation to prevent data duplication.
- **Hybrid Kill-Switch:** State-aware service lifecycle management that calls `stopSelf()` when features are disabled to minimize battery impact and resource usage.
- **Smart Error Handling:** Context-aware error routing via `AppErrorHandler` that displays UI feedback in the foreground and triggers actionable Local Notifications (`flutter_local_notifications`) in the background.
- **OS Constraint Strategy:** Explicit handling of modern Android (12+) constraints, including Battery Optimization exemption requests and high-priority notification triggers for overlay reliability.

## Tools & Utilities
- **Internationalization:** `flutter_localizations` and `intl` for bilingual support.
- **Security:** `crypto` for PIN hashing and `uuid` for unique identifiers.
- **Data Integrity:** Centralized `NumberParser` utility for safe numeric parsing and null-safety from dynamic sources.
- **Financial Integrity:** Epsilon-aware balance sufficiency checks (0.01 EGP tolerance), atomic Firestore transactions and FieldValue.increment() for all wallet, balance, and stat counter updates, and $O(1)$ aggregate synchronization. Includes a "Zero-Unbounded-Read" guarantee by utilizing Firestore Aggregate Queries and cursor-based pagination for all list operations.
- **Domain Fortification:** Type-safe Enums for all statuses/types and centralized `AmountValidator` guards.
- **Reactive Resilience:** Error-aware Stream pipelines, stateless repository pagination, and transparent exception propagation from providers to the UI layer.
- **Performance Optimization:** Efficient document batching (450-item chunks) to bypass Firestore's 500-operation limit during bulk resets. Includes a "Zero-Unbounded-Read" guarantee for statistical operations by utilizing Firestore Aggregate Queries (count/sum) instead of full collection fetches.