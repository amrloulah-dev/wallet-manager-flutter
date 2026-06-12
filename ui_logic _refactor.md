Act as an Elite Senior Flutter Developer. We have successfully completed the database schema refactor. Now, we must execute a targeted bug-fix sweep to resolve 3 remaining UI/Logic edge cases.

Apply the following 3 fixes immediately. Do NOT stop for checkpoints. Execute all of them and present the modified code files.

### 1. Fix Transaction Creator Name ("Unknown")
**Targets:** `transaction_provider.dart` (or wherever `createTransaction` is handled)
- **Bug:** `transaction_details_screen` displays "Unknown" (غير معروف) because `createdByName` is not being properly saved when a new transaction is created.
- **Fix:** Locate the method responsible for creating transactions (e.g., `addTransaction` or `createTransaction`). Ensure that when instantiating the new `TransactionModel`, the `createdByName` and `creatorRole` properties are explicitly populated using the currently logged-in user's data (from `AuthProvider` or `EmployeeProvider`).

### 2. Fix Wallet Card (RTL Phone, Scale, and Inactive Badge)
**Targets:** `number_formatter.dart` & `wallet_card.dart`
- **Phone Number RTL Bug:** In `number_formatter.dart`, the `formatPhoneNumber` method uses naive substring concatenation which reverses the phone number in Arabic (RTL) locales. Fix it by returning the parts logically, or simply return the normalized number and let the UI handle the direction.
- **Phone Number UI Fix:** In `wallet_card.dart`, wrap the phone number `Text` widget with `Directionality(textDirection: TextDirection.ltr, child: ...)` to force correct left-to-right reading.
- **Card Scale (15% Shrink):** In `wallet_card.dart`, wrap the outermost main container/card widget with `Transform.scale(scale: 0.85)` to shrink the entire card uniformly by 15%.
- **Inactive Badge Fix:** In `wallet_card.dart`, the badge currently checks `isFrozen` to show "غير نشطة". Update the logic so it ONLY shows the red/inactive badge if `wallet.walletStatus == WalletStatus.suspended`. If the wallet is active, it should not be marked as inactive.

### 3. Fix Employee Limit Validation
**Targets:** `employee_provider.dart` & `subscription_provider.dart`
- **Bug:** The system throws an `employee_error_max_limit_reached` error even when the count is `0 / 999`. 
- **Fix:** In `employee_provider.dart`, review the `addEmployee` method:
  `if (!_subscriptionProvider!.canAddEmployee(employeesCount))`
  Ensure the logic inside `canAddEmployee` strictly returns `true` if `currentEmployees < maxLimit`. Fix the conditional check to properly allow adding employees if the limit hasn't been reached.

Execute these 3 specific fixes. Ensure no existing logic is broken. Output the updated code for the affected files!