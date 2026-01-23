# Wallet Manager

## Overview

**Wallet Manager** is a comprehensive Flutter application designed to assist store owners and individuals in managing financial digital wallets. Tailored specifically for the Egyptian market context, it supports various mobile wallet providers (Vodafone Cash, Etisalat Cash, Orange Cash, WE Pay) and banking services like InstaPay.

The application serves as a central hub for tracking transactions, managing balances, monitoring debts, and supervising employee activities with role-based access control. It relies on **Firebase** for backend services, authentication, and real-time data synchronization.

## Key Features

### 💼 Wallet Management
*   **Multi-Provider Support**: Manage wallets for Vodafone Cash, Etisalat Cash, Orange Cash, WE Pay, and InstaPay.
*   **Status Tracking**: Categorize wallets as "New", "Old", or "Registered Store" to apply correct transaction limits.
*   **Balance Monitoring**: Real-time tracking of current balances for each wallet.
*   **Limit Enforcement**: Automatic tracking of daily and monthly limits for sending and receiving, with visual warnings when limits are approached.

### 💸 Transaction Handling
*   **Operations**: Support for Sending, Receiving, and Deposits.
*   **Fee Calculation**: Automated calculation of transaction fees based on the specific provider and transaction type.
*   **Commission Tracking**: separate tracking for service fees and store commissions.
*   **History**: Detailed transaction history with filtering by date and type.

### 📝 Debt Management
*   **Debt Tracking**: Record debts from transactions or direct store sales.
*   **Status Workflow**: Track debts as "Open" or "Paid".
*   **Partial Payments**: Support for recording partial payments or adding to existing debts.
*   **Customer Log**: Store customer names and phone numbers associated with debts.

### 👥 Role-Based Access Control
*   **Store Owner**: Full access to all features, including statistics, settings, and employee management.
*   **Employees**: Restricted access based on granular permissions (e.g., can create transactions, can view debts, can mark debts as paid).
*   **Secure Login**: Employees log in using a store password and a personal 4-digit PIN.

### 📊 Statistics & Analytics
*   **Dashboard**: Real-time summary of total balance, transaction counts, and commission.
*   **Daily Reports**: Detailed breakdown of daily performance.
*   **Date Filtering**: Custom date range filtering for financial reports.
*   **Performance Metrics**: Track sending vs. receiving volumes and total profits.

### 🔐 Security & Licensing
*   **License System**: App access is controlled via a secure license key validation system linked to the store.
*   **Google Sign-In**: Secure authentication for store owners.
*   **PIN Protection**: Hashed PIN verification for employee actions.

## Technical Architecture

The project follows a **Clean Architecture** approach using the **MVVM** (Model-View-ViewModel) pattern with **Provider** for state management.

### Tech Stack
*   **Framework**: Flutter (Dart)
*   **State Management**: `provider`
*   **Backend**: Firebase (Firestore, Auth)
*   **Local Storage**: `shared_preferences`
*   **Localization**: `flutter_localizations` (Arb files)
*   **Utilities**: `bot_toast`, `intl`, `crypto`

### Folder Structure

```text
lib/
├── core/                   # Core utilities, constants, themes, and error handling
│   ├── constants/          # App-wide constants (Limits, Routes, Firebase keys)
│   ├── errors/             # Custom exception and failure classes
│   ├── theme/              # App themes (Light/Dark) and text styles
│   └── utils/              # Helpers (Date, Validation, Hashing, Formatting)
├── data/                   # Data layer
│   ├── models/             # Data models (Wallet, Transaction, User, etc.)
│   ├── repositories/       # Repositories interacting with Firestore
│   └── services/           # External services (Firebase, Google Auth, LocalStorage)
├── l10n/                   # Localization files (Arabic & English)
├── presentation/           # UI Layer
│   ├── screens/            # Application screens (Auth, Home, Wallets, etc.)
│   └── widgets/            # Reusable UI components
├── providers/              # State management logic (ViewModels)
├── routes/                 # Navigation configuration
├── app.dart                # App entry widget
└── main.dart               # App entry point
```

## Setup & Configuration

### Prerequisites
*   Flutter SDK
*   Dart SDK
*   Firebase Project

### Installation
1.  **Clone the repository**:
    ```bash
    git clone <repository-url>
    ```
2.  **Install dependencies**:
    ```bash
    flutter pub get
    ```
3.  **Firebase Configuration**:
    *   Ensure `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) are placed in their respective native project folders.
    *   Enable **Authentication** (Google Sign-In) and **Cloud Firestore** in the Firebase Console.

### Running the App
```bash
flutter run
```

## Localization
The application supports **Arabic (ar)** and **English (en)**.
*   **Default Locale**: Arabic.
*   **Switching**: Can be changed via the Settings screen.
*   **Resources**: Translation strings are managed in `lib/l10n/arb/`.

## Limits & Rules
The application hardcodes specific financial limits based on Egyptian regulations found in `lib/core/constants/app_constants.dart`:
*   **New Wallets**: Lower daily/monthly transaction limits.
*   **Old/Registered Wallets**: Higher limits.
*   **InstaPay**: Specific limits for bank transfers.

## License
This software is protected by a custom license key mechanism. A valid license key is required to register a new store. License keys are validated against the backend `license_keys` collection.