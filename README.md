# Wallet Manager

## Project Overview
Wallet Manager is a Flutter-based application designed to help store owners and businesses manage financial wallets, transactions, debts, and employee access. It provides a centralized platform to track cash flows across various payment methods (like Vodafone Cash, InstaPay, etc.), enforce transaction limits, and monitor business performance through detailed statistics.

## Key Features

### 🔐 Authentication & Access Control
*   **Owner Access:** Secure login via Email/Password or Google Sign-In.
*   **Employee Access:** Simplified login using Store Email and a unique PIN.
*   **Role-Based Permissions:** Granular permission settings for employees (e.g., ability to create transactions, view debts, manage wallets).
*   **License Management:** Trial and Premium license validation system.

### 💰 Wallet Management
*   **Multi-Provider Support:** Specific logic for Vodafone Cash, InstaPay, Orange Cash, Etisalat Cash, and WE Pay.
*   **Limit Enforcement:** Automatic validation of Daily and Monthly transaction limits based on provider rules.
*   **Balance Tracking:** Real-time updates of wallet balances.
*   **Management:** Create, edit, delete, and monitor active wallets.

### 💸 Transaction Handling
*   **Send & Receive:** Record outgoing and incoming money transfers.
*   **Fee Calculation:** Automated commission calculation based on service provider rules.
*   **History:** View daily transaction logs and detailed transaction receipts.
*   **Debt Integration:** Option to mark transactions as "Debt" if unpaid at the time of creation.

### 📝 Debt Management
*   **Tracking:** Record debts from transactions or direct store sales.
*   **Status Management:** Track "Open" and "Paid" debts.
*   **Partial Payments:** Support for recording partial payments towards an existing debt.
*   **Customer Details:** Link debts to specific customer names and phone numbers.

### 📊 Statistics & Analytics
*   **Dashboard:** Real-time summary of total balance, transaction counts, commission earnings, and active debts.
*   **Filtering:** View statistics by custom date ranges.
*   **Breakdowns:** Detailed reports on transaction types (Send vs. Receive) and daily performance.

### ⚙️ Settings & Customization
*   **Localization:** Full support for Arabic and English languages.
*   **Theming:** Support for Light, Dark, and System theme modes.

## Project Structure

The project follows a Clean Architecture approach with a separation of concerns between Data, Domain (implicitly handled in providers/models), and Presentation layers.

```
lib/
├── core/               # Shared utilities, constants, and theme configuration
│   ├── constants/      # App-wide constants (Firebase paths, Routes)
│   ├── errors/         # Custom exception handling classes
│   ├── theme/          # App colors and text styles
│   └── utils/          # Helpers (Date, Formatters, Validators, Permission Checks)
├── data/               # Data layer
│   ├── models/         # Data models (JSON/Firestore serialization)
│   ├── repositories/   # Logic for interacting with Firestore collections
│   └── services/       # External services (Firebase, Google Auth, LocalStorage)
├── l10n/               # Localization files (.arb)
├── presentation/       # UI layer
│   ├── screens/        # Full-page screens organized by feature (Auth, Home, Wallets, etc.)
│   └── widgets/        # Reusable UI components
├── providers/          # State management (ChangeNotifier)
└── routes/             # Navigation configuration
```

## Technologies & Dependencies

*   **Framework:** [Flutter](https://flutter.dev/) (Dart)
*   **Backend:** [Firebase](https://firebase.google.com/)
    *   **Authentication:** User management (Email/Password, Google).
    *   **Cloud Firestore:** NoSQL database for data storage.
    *   **Analytics & Performance:** App monitoring.
*   **State Management:** `provider`
*   **Local Storage:** `shared_preferences`
*   **Localization:** `flutter_localizations`, `intl`
*   **Utilities:** `uuid`, `crypto` (for hashing PINs), `device_info_plus`, `url_launcher`.

## Setup & Configuration

1.  **Prerequisites:**
    *   Flutter SDK installed.
    *   Valid Firebase project setup.

2.  **Firebase Configuration:**
    *   Ensure `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) are placed in their respective directories.
    *   Firestore security rules should be configured to allow appropriate access based on the `stores` and `users` collections structure.

3.  **Running the App:**
    ```bash
    flutter pub get
    flutter run
    ```

## Notes & Assumptions

*   **Trial Logic:** The app enforces a trial period logic based on device ID and license keys stored in Firestore.
*   **Permissions:** Employee permissions are stored in the user document and checked locally via `PermissionHelper` before allowing sensitive actions.
*   **Data Consistency:** Critical updates (like transaction creation updating wallet balance and stats) are handled via Firestore Transactions to ensure data integrity.
*   **Platform:** Designed primarily for mobile usage (Android/iOS).

---
*Auto-generated based on codebase analysis.*