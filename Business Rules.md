# Business Rules Report

------------------------------------
Rule Title:
Wallet Balance Sufficiency Check

Rule Type:
Wallet Rule

Description:
A wallet cannot perform a sending transaction if its current balance is less than the transaction amount. This ensures that wallets do not fall into a negative balance.

Condition:
Applies whenever a transaction of type 'send' is being created.

Effect:
The transaction is blocked, and a ValidationException is thrown.

Source Code:
```dart
if (transaction.isSend) {
  if (validationWallet.balance < transaction.amount) {
    throw ValidationException(
        'المبلغ المراد إرساله أكبر من الرصيد المتاح.');
  }
```

File Path:
lib/data/repositories/transaction_repository.dart
------------------------------------

------------------------------------
Rule Title:
Transaction Modification Time Limit

Rule Type:
Wallet Rule

Description:
A transaction can only be modified (edited or deleted) within a strict window of 5 minutes after its initial creation.

Condition:
Applies when a user attempts to edit or delete an existing transaction.

Effect:
The modification is allowed if within 5 minutes; otherwise, the action is restricted.

Source Code:
```dart
bool get canBeModified {
  // Can be modified within 5 minutes of creation
  return DateTime.now().difference(createdAt.toDate()).inMinutes < 5;
}
```

File Path:
lib/data/models/transaction_model.dart
------------------------------------

------------------------------------
Rule Title:
Store Inactivity Block

Rule Type:
Wallet Rule

Description:
Users (Owners and Employees) are prevented from logging into or using a store that is marked as inactive in the system.

Condition:
Applies during the login process or session finalization.

Effect:
Login is denied and a StoreInactiveException is thrown.

Source Code:
```dart
if (!store.isActive) throw StoreInactiveException();
```

File Path:
lib/providers/auth_provider.dart
------------------------------------

------------------------------------
Rule Title:
Employee PIN Code Format

Rule Type:
Wallet Rule

Description:
Every employee PIN code must be exactly 4 digits long.

Condition:
Applies when an owner resets an employee's PIN code.

Effect:
Validation fails and a ValidationException is thrown if the PIN is not exactly 4 digits.

Source Code:
```dart
if (newPin.length != 4) {
  throw ValidationException('PIN must be 4 digits');
}
```

File Path:
lib/data/repositories/employee_repository.dart
------------------------------------

------------------------------------
Rule Title:
Employee PIN Uniqueness

Rule Type:
Wallet Rule

Description:
An employee PIN code must be unique within a specific store to prevent identification conflicts.

Condition:
Applies when adding a new employee or resetting a PIN.

Effect:
The operation is blocked and a ServerException/ValidationException is thrown if the PIN is already in use by another active employee in the same store.

Source Code:
```dart
if (pinQuery.docs.isNotEmpty) {
  throw ServerException('الرقم السري مستخدم بالفعل');
}
```

File Path:
lib/data/repositories/employee_repository.dart
------------------------------------

------------------------------------
Rule Title:
Maximum Employee Limit

Rule Type:
Wallet Rule

Description:
A store has a maximum number of active employees it can register, which defaults to 5 unless overridden in store settings.

Condition:
Applies when an owner attempts to add a new employee.

Effect:
The addition is blocked if the current count of active employees reaches the maximum allowed.

Source Code:
```dart
final maxEmployees = storeData['settings']?['maxEmployees'] ?? 5;
// ...
if (currentCount >= maxEmployees) {
  throw ServerException('تم الوصول للحد الأقصى من الموظفين');
}
```

File Path:
lib/data/repositories/employee_repository.dart
------------------------------------

------------------------------------
Rule Title:
Positive Transaction Amount Validation

Rule Type:
Transaction Limit

Description:
All transactions (send, receive, or deposit) must have an amount strictly greater than zero.

Condition:
Applies during the transaction creation process.

Effect:
The operation is blocked and a ValidationException is thrown if the amount is zero or negative.

Source Code:
```dart
if (amount <= 0) throw ValidationException('Amount must be positive.');
```

File Path:
lib/providers/transaction_provider.dart
------------------------------------

------------------------------------
Rule Title:
Single Transaction Amount Cap

Rule Type:
Transaction Limit

Description:
The amount for a single transaction cannot exceed the specific transaction limit assigned to the wallet based on its status or type.

Condition:
Applies to every transaction creation.

Effect:
Validation fails and a ValidationException is thrown if the amount exceeds the limit.

Source Code:
```dart
if (transaction.amount > validationWallet.getLimits().dailyLimit) {
  throw ValidationException(
      'المبلغ يتجاوز الحد الأقصى للمعاملة الواحدة.');
}
```

File Path:
lib/data/repositories/transaction_repository.dart
------------------------------------

------------------------------------
Rule Title:
Monthly Cumulative Amount Cap

Rule Type:
Transaction Limit

Description:
The total volume of transactions for a wallet in a single month cannot exceed its monthly limit.

Condition:
Applies to every transaction creation.

Effect:
The transaction is rejected and a ValidationException is thrown if the new transaction would push the monthly total over the limit.

Source Code:
```dart
if (validationWallet.getLimits().monthlyUsed + transaction.amount >
    validationWallet.getLimits().monthlyLimit) {
  throw ValidationException('تم تجاوز الحد الشهري لهذه المحفظة.');
}
```

File Path:
lib/data/repositories/transaction_repository.dart
------------------------------------

------------------------------------
Rule Title:
New Wallet Type Capacity Limits

Rule Type:
Transaction Limit

Description:
Wallets with 'new' status are limited to 10,000 EGP per transaction and 60,000 EGP per month.

Condition:
Applies to wallets with 'new' status.

Effect:
Sets default limits during wallet initialization.

Source Code:
```dart
static const double newWalletTransactionLimit = 10000.0;
static const double newWalletMonthlyLimit = 60000.0;
```

File Path:
lib/core/constants/app_constants.dart
------------------------------------

------------------------------------
Rule Title:
Old Wallet Type Capacity Limits

Rule Type:
Transaction Limit

Description:
Wallets with 'old' status are limited to 60,000 EGP per transaction and 200,000 EGP per month.

Condition:
Applies to wallets with 'old' status.

Effect:
Sets default limits during wallet initialization.

Source Code:
```dart
static const double oldWalletTransactionLimit = 60000.0;
static const double oldWalletMonthlyLimit = 200000.0;
```

File Path:
lib/core/constants/app_constants.dart
------------------------------------

------------------------------------
Rule Title:
Registered Store Wallet Capacity Limits

Rule Type:
Transaction Limit

Description:
Wallets with 'registered_store' status are limited to 60,000 EGP per transaction and 400,000 EGP per month.

Condition:
Applies to wallets with 'registered_store' status.

Effect:
Sets default limits during wallet initialization.

Source Code:
```dart
static const double registeredStoreTransactionLimit = 60000.0;
static const double registeredStoreMonthlyLimit = 400000.0;
```

File Path:
lib/core/constants/app_constants.dart
------------------------------------

------------------------------------
Rule Title:
InstaPay Wallet Capacity Limits

Rule Type:
Transaction Limit

Description:
InstaPay type wallets are limited to 120,000 EGP per transaction and 400,000 EGP per month.

Condition:
Applies specifically to wallets of type 'instapay'.

Effect:
Overrides default status-based limits for InstaPay wallets.

Source Code:
```dart
static const double instapayTransactionLimit = 120,000.0;
static const double instapayMonthlyLimit = 400000.0;
```

File Path:
lib/core/constants/app_constants.dart
------------------------------------

------------------------------------
Rule Title:
Vodafone Cash Inter-Network Fees

Rule Type:
Transfer Rule

Description:
Transfers from a Vodafone Cash wallet to another Vodafone number cost 1 EGP. Transfers to other networks cost 0.5% of the amount, capped between 1 EGP and 15 EGP.

Condition:
Applies when the source wallet is 'vodafone_cash'.

Effect:
Calculates the exact network fee to be deducted.

Source Code:
```dart
case walletVodafone:
  if (provider == 'Vodafone') {
    return 1.0;
  } else {
    return _calculatePercentageFee(amount, 0.005, 1.0, 15.0);
  }
```

File Path:
lib/core/utils/fee_calculator.dart
------------------------------------

------------------------------------
Rule Title:
Etisalat Cash Inter-Network Fees

Rule Type:
Transfer Rule

Description:
Transfers from an Etisalat Cash wallet to another Etisalat number cost 1 EGP. Transfers to other networks cost 0.5% of the amount, capped between 1 EGP and 15 EGP.

Condition:
Applies when the source wallet is 'etisalat_cash'.

Effect:
Calculates the exact network fee to be deducted.

Source Code:
```dart
case walletEtisalat:
  if (provider == 'Etisalat') {
    return 1.0;
  } else {
    return _calculatePercentageFee(amount, 0.005, 1.0, 15.0);
  }
```

File Path:
lib/core/utils/fee_calculator.dart
------------------------------------

------------------------------------
Rule Title:
Orange Cash Inter-Network Fees

Rule Type:
Transfer Rule

Description:
Transfers from an Orange Cash wallet to another Orange number cost 1 EGP. Transfers to other networks cost 0.5% of the amount, capped between 1 EGP and 15 EGP.

Condition:
Applies when the source wallet is 'orange_cash'.

Effect:
Calculates the exact network fee to be deducted.

Source Code:
```dart
case walletOrange:
  if (provider == 'Orange') {
    return 1.0;
  } else {
    return _calculatePercentageFee(amount, 0.005, 1.0, 15.0);
  }
```

File Path:
lib/core/utils/fee_calculator.dart
------------------------------------

------------------------------------
Rule Title:
InstaPay Universal Transfer Fees

Rule Type:
Transfer Rule

Description:
Transfers from an InstaPay wallet to any destination cost 0.1% of the amount, capped between 0.5 EGP and 20 EGP.

Condition:
Applies when the source wallet is 'instapay'.

Effect:
Calculates the exact network fee to be deducted.

Source Code:
```dart
case walletInstaPay:
  return _calculatePercentageFee(amount, 0.001, 0.5, 20.0);
```

File Path:
lib/core/utils/fee_calculator.dart
------------------------------------

====================================
VALIDATION STEP
====================================
- Total number of rules found: 17
- Confirmation that ALL files were scanned: YES (full recursive scan performed)
- Note if any expected rules were NOT found:
  - No rules found for 'WE' (Telecom Egypt) wallet types (only prefixes identified, no specific fee logic).
  - No explicit minimum transaction amount other than > 0.
  - No cross-provider special bonuses or discounts found.
