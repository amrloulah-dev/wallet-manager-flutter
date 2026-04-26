🌊 Phase 3: Business Logic & Domain Integrity Execution Plan
Architectural Role: Senior System Architect

Objective: Remediate financial validation deficits, silent stream failures, and domain model fragility as identified in the Phase 3 Audit.

📜 General Instructions
This phase focuses on fortifying the application's core logic against negative monetary values and inconsistent data states. We will transform "silent" data channels (Streams) into reactive, error-aware pipelines. Furthermore, all "Magic Strings" will be purged and replaced with type-safe Enums to ensure long-term stability.
Note: Per Lead Developer decision, SHA-256 PIN hashing will remain as-is; security will be compensated via strict Firestore Security Rules.

Phase 1: Financial Fortification & Guard Implementation
🎯 The Problem (The "Why")
The application lacks proper input guards on monetary fields. Debt payments and statistics updates currently accept negative amounts. Using FieldValue.increment() with negative values causes silent balance corruption. Additionally, over-payments on debts result in negative amountDue values.

📜 Execution Steps (The "How")
Create Amount Validator: Implement lib/core/utils/amount_validator.dart.

Define a static method ensurePositive(double value) that throws a DomainException if the value is <= 0.

Inject Guard Logic: Add AmountValidator.ensurePositive() as the first line of execution in repository methods such as processPayment, addExpense, or any balance-modifying action.

Atomic Ceiling Checks: Refactor DebtRepository.processPayment to use FirebaseFirestore.instance.runTransaction.

The transaction must read the current debt, verify that paymentAmount <= amountDue, and throw an InvalidAmountException if the check fails.

Counter Integrity: For statistics counters (e.g., employee count), implement logic to ensure the counter never decrements below zero.

Phase 2: Stream Reliability & Cost Optimization
🎯 The Problem (The "Why")
Four critical streams currently "swallow" network or permission errors by returning empty lists [] or executing empty handleError blocks. This misleads users into seeing empty states instead of connectivity warnings. Additionally, unbounded employee watches threaten Firestore quotas as they lack pagination or limits.

📜 Execution Steps (The "How")
Error Propagation: In UserRepository, StoreRepository, and EmployeeRepository:

Replace empty .handleError((e) {}) blocks with .handleError((e) => AppErrorHandler.handle(e)).

Ensure the stream re-emits the error using Stream.error(e) so that UI listeners can react.

Cost Capping: Add .limit(100) to all employee-related snapshots in EmployeeRepository and UserRepository to prevent unbounded reads.

Listener Safety: Update SystemConfigProvider and all other .listen() callers to include an explicit onError parameter.

Phase 3: Domain Purity & Enum Migration
🎯 The Problem (The "Why")
The codebase relies on "Magic Strings" such as 'open', 'paid', and 'vodafone_cash' for business logic. Typos in these strings bypass conditions silently. Moreover, models default to Timestamp.now() when data is missing, which corrupts historical audit trails.

📜 Execution Steps (The "How")
Enhanced Enums: Create lib/core/enums/ files for:

DebtStatus { open, paid, partiallyPaid }

WalletType { vodafoneCash, bank, instapay, etc }

SubscriptionStatus { active, expired, pending }

Model Refactoring: Update WalletModel, DebtModel, and TransactionModel to use these Enums instead of raw Strings.

Safe Serialization: In fromFirestore methods:

Return null (or handle as optional) for missing timestamps instead of fabricating Timestamp.now().

Replace hard casts (e.g., as String) with data['field'] as String? ?? '' to prevent TypeError crashes.

Phase 4: UX Responsiveness & Precision Handling
🎯 The Problem (The "Why")
The UI often fails to show immediate loading states, and stale error messages persist even after successful retries. Furthermore, double precision drift can cause tiny, non-intuitive decimal artifacts in the UI.

📜 Execution Steps (The "How")
Immediate Feedback: Ensure all Provider actions call setLoading(true) or safeNotify() immediately upon execution.

State Cleansing: Explicitly reset _errorMessage = null; at the beginning of every action method before starting async work.

UI Rounding: Implement .toStringAsFixed(2) across the presentation layer to prevent floating-point drift artifacts from appearing to the user.