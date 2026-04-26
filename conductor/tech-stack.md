# Wallet Manager Tech Stack

## Framework
- **Flutter (Dart):** For cross-platform mobile application development.

## Backend
- **Firebase:** Comprehensive backend suite.
    - **Authentication:** Managing owner (Google/Email) and employee (PIN) logins.
    - **Cloud Firestore:** Scalable NoSQL database for wallets, transactions, and debts.
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

## Local Storage
- **Shared Preferences:** Storing local settings and non-sensitive metadata.

## Tools & Utilities
- **Internationalization:** `flutter_localizations` and `intl` for bilingual support.
- **Security:** `crypto` for PIN hashing and `uuid` for unique identifiers.
- **Data Integrity:** Centralized `NumberParser` utility for safe numeric parsing and null-safety from dynamic sources.
- **Domain Fortification:** Type-safe Enums for all statuses/types and centralized `AmountValidator` guards.
- **Reactive Resilience:** Error-aware Stream pipelines with explicit propagation and cost-capping limits.