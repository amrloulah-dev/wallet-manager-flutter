# Wallet Manager Tech Stack

## Framework
- **Flutter (Dart):** For cross-platform mobile application development.

## Backend
- **Firebase:** Comprehensive backend suite.
    - **Authentication:** Managing owner (Google/Email) and employee (PIN) logins.
    - **Cloud Firestore:** Scalable NoSQL database for wallets, transactions, and debts.
    - **Analytics & Performance:** Monitoring user behavior and app health.

## State Management
- **Provider:** Simple and scalable state management for app-wide and local states, using a centralized `BaseProvider` for common functionality.

## Dependency Injection
- **GetIt:** For centralized service and repository registration and decoupled access.

## Local Storage
- **Shared Preferences:** Storing local settings and non-sensitive metadata.

## Tools & Utilities
- **Internationalization:** `flutter_localizations` and `intl` for bilingual support.
- **Security:** `crypto` for PIN hashing and `uuid` for unique identifiers.
- **Data Integrity:** Centralized `NumberParser` utility for safe numeric parsing and null-safety from dynamic sources.