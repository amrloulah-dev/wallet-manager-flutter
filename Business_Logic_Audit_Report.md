# Business Logic & Domain Integrity Audit Report

### 🔴 CRITICAL (Blockers / Financial Risks / Data Corruption)

| File Path | Line(s) | Exact Code Snippet | Root Cause | Why This Is Critical |
|----------|--------|-------------------|------------|---------------------|
| `lib/data/services/transaction_validator_service.dart` | 46-50 | `if (transaction.isDeposit) {`<br>`  tx.update(walletRef, {'balance': FieldValue.increment(transaction.amount)});`<br>`  return;`<br>`}` | Early return bypasses `tx.set(txRef, transaction.toFirestore());` executed later in the method. | The deposit transaction document is NEVER written to Firestore. The wallet balance updates invisibly, breaking the audit trail and corrupting financial history. |
| `lib/data/services/transaction_validator_service.dart` | 37-39 | `final balanceChange = transaction.isSend`<br>`  ? -(transaction.amount + transaction.serviceFee)`<br>`  : (transaction.amount + transaction.commission);` | For a receive transaction, the wallet's digital balance is incremented by `amount + commission`. | Commission is cash taken from the customer for the service of receiving. Adding it to the digital e-wallet balance artificially inflates it, causing permanent mismatch between the app's records and the real provider's balance. |
| `lib/data/models/debt_model.dart` | 49-50 | `final amountDue = NumberParser.toDouble(data['amountDue']);`<br>`AmountValidator.ensurePositive(amountDue);` | `ensurePositive` explicitly throws if `value <= 0`. Fully paid debts have `amountDue == 0.0`. | Any attempt to fetch or load a paid debt from Firestore will immediately crash the parser. This completely blocks users from viewing their debt history or accessing paid debts. |
| `lib/data/models/wallet_model.dart` | 215-219 | `bool canSendAmount(double amount) {`<br>`  final limits = getLimits();`<br>`  return amount <= limits.dailyLimit &&`<br>`      !limits.isMonthlyLimitReached &&`<br>`      (limits.monthlyRemaining >= amount);`<br>`}` | Checks if the requested `amount` alone is less than the `dailyLimit`, failing to check if `limits.dailyRemaining >= amount`. | A user can completely bypass daily provider limits by simply executing multiple smaller transactions. As long as each individual `amount` is under `dailyLimit`, it returns `true`. (Same bug in `canReceiveAmount`). |
| `lib/providers/debt_provider.dart` | 196-200 | `final existingDebtByPhone = await _debtRepository.getDebtByCustomerPhone(_currentStoreId!, customerPhone);`<br>`if (existingDebtByPhone != null) {`<br>`  return await addPartialDebt(existingDebtByPhone.debtId, amountDue, user.userId);`<br>`}` | Creating a new debt automatically merges the amount into *any* existing debt found by the customer's phone number. | If a customer has a previously paid/closed debt, or requires multiple independent debts, this forcefully merges them into the first found `debtId`. This corrupts debt tracking and could inadvertently reopen settled debts. |

---

### 🟠 MEDIUM (Tech Debt / Fragile Logic)

| File Path | Line(s) | Exact Code Snippet | Issue | Recommended Pattern |
|----------|--------|-------------------|-------|---------------------|
| `lib/data/models/store_model.dart` | 51-52 | `settings: StoreSettings.fromMap(data['settings'] as Map<String, dynamic>? ?? {}),`<br>`stats: StoreStats.fromMap(data['stats'] as Map<String, dynamic>? ?? {}),` | Fragile serialization. Direct type casting (`as`) without `is` checks. If Firestore accidentally stores a String or List here, the parser crashes with a `TypeError`. | Use safe casting or utility parser: `data['settings'] is Map ? Map<String, dynamic>.from(data['settings']) : {}`. |
| `lib/providers/wallet_provider.dart` | 338 | `_wallets[index] = wallet.copyWith(balance: newBalance);` | Unsafe Mutability. Modifying the state list directly in-place breaks immutability guarantees. UI layers relying on reference equality to rebuild won't detect the list change. | Create a new list: `_wallets = List.from(_wallets)..[index] = wallet.copyWith(balance: newBalance);`. |
| `lib/data/models/debt_model.dart` | 56-61 | `if (totalAmount == 0.0 && debtStatus == DebtStatus.open) {`<br>`  AppErrorHandler.handle(`<br>`    'Debt document has zero totalAmount: ${doc.id}',`<br>`    operation: 'DebtModel.fromFirestore',`<br>`  );`<br>`}` | Side effects inside a domain model constructor. Calling global singletons (`AppErrorHandler`) breaks domain purity, and continuing execution with bad data is unsafe. | Throw a specific `DomainException` during parsing and let the repository or provider layer handle the logging and fallback. |
| `lib/data/models/transaction_model.dart` | 52-57 | `final transactionDate = (data['transactionDate'] as Timestamp?)?.toDate();`<br>`...`<br>`if (transactionDate == null || createdAt == null) {`<br>`  throw NotFoundException(...)`<br>`}` | Using `NotFoundException` (typically reserved for missing documents/collections) for a malformed payload. | Throw a `DomainException` or `FormatException` to indicate schema mismatch. |

---

### 🟢 QUICK WINS (Low Hanging Issues)

| File Path | Line(s) | Exact Code Snippet | Issue |
|----------|--------|-------------------|-------|
| `lib/providers/wallet_provider.dart` | 316-320 | `if (data['walletId'] == null \|\| data['amount'] == null \|\| data['type'] == null) {`<br>`  return;`<br>`}` | Silent failure in optimistic overlay data. If the native/overlay bridge passes malformed data, it fails silently, making debugging extremely difficult. |
| `lib/core/utils/fee_calculator.dart` | 59-60 | `if (amount <= 0) {`<br>`  throw DomainException('Amount must be positive; received: $amount');`<br>`}` | Logic duplication. `AmountValidator.ensurePositive` already handles this consistently and should be reused here instead of a custom string. |

---

Report 3 (Business Logic & Domain Integrity) Generation Complete. Awaiting the next audit directive.
