# 🧠 Report 2: Business Logic & State Management Documentation

## 1. State Management Architecture

The Wallet Manager application utilizes a Provider-based state management architecture tailored for high responsiveness and safety. The core principles revolve around preventing memory leaks, ensuring optimistic UI updates, and guarding against race conditions during background syncs.

### 1.1 `SafeChangeNotifier` and `BaseProvider`
All state providers in the application extend `BaseProvider`, which in turn extends `SafeChangeNotifier`. 
*   **`SafeChangeNotifier`**: A custom wrapper around Flutter's `ChangeNotifier`. It tracks a boolean `_isDisposed` flag that is set to true when `dispose()` is called. Its primary feature is the `safeNotify()` method, which schedules `notifyListeners()` in a microtask (`Future.microtask`) and only executes it if the provider hasn't been disposed. This entirely eliminates the common "A [ChangeNotifier] was used after being disposed" error, which frequently occurs during rapid navigation or asynchronous operations that complete after a screen is closed.
*   **`BaseProvider`**: Adds global error handling capabilities. It holds a reference to `NavigationService.navigatorKey` to show UI toasts via `AppErrorHandler` on failures, abstracting error presentation away from the UI layer.

### 1.2 The Optimistic UI Pattern
The application strictly enforces an Optimistic UI approach to ensure the interface feels instantaneous, particularly for transactions:
1.  **Capture State**: Before a mutation, the current state (e.g., balances, lists) is saved to a local snapshot.
2.  **Optimistic Mutation**: The local RAM state is updated immediately with the expected outcome, and `safeNotify()` is called. The UI re-renders instantly.
3.  **Network Execution**: The actual asynchronous write operation is sent to Firestore.
4.  **Rollback Mechanism**: If the Firestore operation fails (due to network or rules), the provider catches the error, calls a rollback method (e.g., `_rollbackLocalTx`, `_rollbackWalletBalance`), restores the snapshot, calls `safeNotify()` again to revert the UI, and surfaces an error toast.

### 1.3 The Fetch Shield Mechanism
To prevent race conditions where an incoming Firestore snapshot overwrites a recently executed optimistic update (because the snapshot might be slightly stale or the local write hasn't fully propagated back), providers like `TransactionProvider` implement a "Fetch Shield".
*   **`_fetchShieldActive`**: A boolean flag activated during local mutations.
*   **Debounce Window**: When active, incoming realtime updates from `watchTransactions()` are temporarily ignored for a ~5-second window. After the window expires, the shield is lowered, and the app resumes syncing with the remote source of truth.

---

## 2. Core Providers

### 2.1 `AuthProvider`
Manages the user session, authentication state, and role-based access.
*   **Dependencies**: Relies on `AuthRepository`, `DatabaseSyncService`, and `LocalStorageService`.
*   **Flow**: On initialization, it attempts an auto-login via `tryAutoLogin()`. It distinguishes between Owners (Firebase Auth) and Employees (PIN-based Identity Service).
*   **Permissions**: Exposes `isOwner`, `isEmployee`, and uses `_validateUserAndPermission` to guard critical actions.
*   **Session Management**: Handles Google Sign-In, Email/Password auth, and employee PIN login, routing them through `DatabaseSyncService` to establish the `AuthSessionResult`.

### 2.2 `WalletProvider`
Manages the lifecycle, balances, and configurations of store wallets.
*   **State Structure**: Uses `Map<String, WalletModel> _walletsMap` for O(1) lookups instead of lists.
*   **Optimistic Updates**: `addBalance`, `deductBalance`, and `updateWalletConfig` all mutate local maps first.
*   **Overlay Integration**: Listens to the `FlutterOverlayWindow` message stream. If a background transaction occurs via SMS, the overlay broadcasts `OVERLAY_TX_COMPLETED`. `WalletProvider` intercepts this, optimistically deducts the balance locally, and blocks auto-fetch to prevent jitter.

### 2.3 `TransactionProvider`
The heart of the business logic, handling credit, debit, and transfer operations.
*   **Dependencies**: Requires instances of `AuthProvider`, `WalletProvider`, `StatisticsProvider`, and `DebtProvider`. It's typically provided via a `ProxyProvider`.
*   **State**: Maintains `Map<String, TransactionModel> _transactionsMap`.
*   **Transaction Flow (`processTransaction`)**:
    1. Validates permissions (`canCreateTransaction`).
    2. Calculates service fees and validates limits (Daily/Monthly) using `TransactionFeeCalculator`.
    3. Performs optimistic local insertion and updates the referenced `WalletProvider` balance.
    4. Executes Firestore `createTransaction`.
    5. On failure, triggers `_rollbackLocalTx` and `walletProvider.addBalance` (to undo deduction).
*   **Transfers**: Handled via `processTransfer`, which creates two linked transactions (Debit from source, Credit to destination) with a shared `transferGroupId`.

### 2.4 `DebtProvider`
Manages customer debts and settlement operations.
*   **State**: Maintains `Map<String, DebtModel> _debtsMap`.
*   **Flows**: Allows creating new debts (`createDebt`) and settling them (`settleDebt`).
*   **Cross-Provider Sync**: Settling a debt often involves adding the collected amount to a specific wallet. It safely interacts with `WalletProvider` optimistically, with full rollback support across both providers on failure.

### 2.5 `EmployeeProvider`
Manages staff members and their granular permissions.
*   **Flows**: Owners can add employees (`addEmployee`), update their permissions (`updatePermissions`), and freeze/unfreeze their access.
*   **Security**: Operations are strictly guarded by `_validateOwner()`. Employee PINs are hashed before transmission.

### 2.6 `SubscriptionProvider`
Enforces SaaS limits and monitors license validity.
*   **Flows**: Watches `StoreSubscription`. It exposes getters like `maxWallets`, `maxEmployees`, `subSmsEnabled`, and `isSubLifetime`.
*   **Enforcement**: `WalletUseCase` uses this provider to calculate which wallets should be "frozen" if a store downgrades to a tier with fewer allowed wallets than they currently possess.

### 2.7 `StatisticsProvider`
Provides aggregated dashboard metrics.
*   **Dependencies**: Relies on `StatisticsRepository`.
*   **Optimistic Dashboards**: Provides methods like `optimisticallyUpdateStats(amount, commission)` that are called by `TransactionProvider` when a transaction is made, ensuring the dashboard charts reflect new data instantly without waiting for the server-side aggregation function to run.

### 2.8 Auxiliary Providers
*   **`LocalizationProvider`**: Manages Arabic/English toggling and dynamically configures static utilities (`NumberFormatter`, `CurrencyFormatter`, `DateHelper`) based on the active locale.
*   **`ThemeProvider`**: Manages Dark/Light/System modes and persists preferences to local storage.
*   **`SystemConfigProvider`**: Streams global app configurations from Firestore (e.g., minimum supported version, global maintenance mode).

---

## 3. Core Business Flows

### 3.1 SMS Automation & Overlay Pipeline (`SmsProcessingPipeline`)
A critical background service that monitors incoming SMS messages to automate transaction recording.
1.  **Interception**: `another_telephony` or the Guardian Isolate intercepts an SMS.
2.  **Guards**: Checks `LocalStorageService` to ensure SMS automation is enabled and the subscription is active. Also checks for 24h sync staleness.
3.  **Parsing**: `SmsParserEngine` extracts the amount, counterparty, type, and service provider from the message body.
4.  **Wallet Matching**: Attempts to map the receiving SIM card to a specific `WalletModel` using `subscriptionId`, `slotStr`, or a smart fallback if the OS restricts SIM data.
5.  **Vault Storage**: Saves the parsed `overlayArgs` to SharedPreferences (`Vault`) to ensure persistence.
6.  **Wake Up**: Fires a high-priority, full-screen intent notification via `FlutterLocalNotificationsPlugin` to wake the device screen.
7.  **Overlay Execution**: Invokes `FlutterOverlayWindow.showOverlay` or `shareData`. The overlay UI then uses `OverlayUseCase` to finalize the transaction in the background, bypassing the main app UI entirely.

### 3.2 Transaction Fee Calculation (`TransactionFeeCalculator` & `FeeCalculator`)
Dynamically determines the network fee applied to a transaction.
*   **Network Identification**: Checks the receiver's phone prefix (010 = Vodafone, 011 = Etisalat, 012 = Orange, 015 = WE).
*   **Cross-Network Rules**:
    *   Same Network (e.g., Vodafone to Vodafone): Flat fee of 1.0 EGP.
    *   Cross Network: 0.5% of the amount, with a minimum of 1.0 EGP and a maximum of 15.0 EGP.
    *   InstaPay: 0.1% of the amount, minimum 0.5 EGP, maximum 20.0 EGP.
*   **Limits Check**: `TransactionFeeCalculator` aggregates the base amount + commission + calculated service fee to ensure the total deduction does not exceed the wallet's `dailyLimit` or `monthlyLimit`.

### 3.3 Permissions Validation (`PermissionHelper` & `WalletUseCase`)
*   **`PermissionHelper`**: A UI-layer utility used inside `build` methods or routers to show/hide widgets or block navigation based on `UserPermissions`. It fails-closed on unknown routes.
*   **`WalletUseCase`**: A domain-layer utility that fetches the `UserModel` from `AuthProvider` and actively throws a `PermissionException` if an unauthorized backend operation is attempted.

---

## 4. Validations

Input validation is centralized in the `Validators` class to ensure consistency across all forms.

*   **Store Name**: Must be 3-50 chars, Arabic/English letters and spaces only.
*   **Passwords**: Minimum 6 characters. Store passwords must be digits only.
*   **License Key**: Must match format `WALLET-2025-[A-Z0-9]{4}-[A-Z0-9]{4}` (exactly 21 chars).
*   **Phone Number**: Validates Egyptian format using Regex `^01[0-2,5]{1}[0-9]{8}$`.
*   **Amount**: Handled by `validateAmount` (must be a valid number > minAmount). The domain layer further reinforces this via `AmountValidator.ensurePositive` and `ensurePositiveOrZero` (throwing `DomainException` on NaN/Infinity/Negatives).
*   **General**: `validateName`, `validateEmail`, `validatePin` (exactly 4 digits), `validateRequired`, `validateNotes` (max length 200).

---

## 5. Error Handling Architecture

### 5.1 `AppErrorHandler`
A centralized error diagnostic and reporting engine.
*   **Global Hooks**: Hooks into `FlutterError.onError` and `PlatformDispatcher.instance.onError` for fatal crash reporting.
*   **Silenced Errors**: `logSilentError()` logs to the console in debug mode, and logs non-fatal errors to Crashlytics in release mode, without interrupting the user.
*   **UI Surfacing**: `handle()` checks if a foreground `BuildContext` exists. If so, it shows a Toast. If the app is in the background, it triggers a local notification (`error_channel`) alerting the user to open the app.
*   **PII Sanitization**: Before sending any string to Crashlytics, `sanitizeMessage()` strips out Egyptian phone numbers and financial amounts (e.g., converting "balance: 123.45" to "balance: [SENSITIVE]") to maintain user privacy.

### 5.2 `AppExceptions` Hierarchy
Custom exceptions ensure errors are strongly typed and localizable.
*   **`AppException`**: Base class containing a `message` and optional `code`.
*   **`AuthException`**: Subclassed into `InvalidCredentialsException`, `StoreInactiveException`, `UserNotFoundException`, `EmailAlreadyInUseException`, `WeakPasswordException`.
*   **`LicenseException`**: Subclassed into `InvalidLicenseException`, `LicenseAlreadyUsedException`, `LicenseExpiredException`.
*   **`DomainException`**: Used for business rule violations (e.g., `InvalidAmountException`).
*   **`PermissionDeniedException`**: Thrown when access control rules fail.
*   **`ServerException` / `NetworkException`**: Thrown for infrastructure failures.
