# Business Logic & Domain Integrity — Correction Plan

> **Source:** `AUDIT_REPORT_3_BUSINESS_LOGIC_DOMAIN_INTEGRITY.md` (Report A — 36 issues) and `Business_Logic_Audit_Report.md` (Report B — 7 issues)
> **Total Unique Issues:** 43 (after deduplication — see mapping table)

---

## Consolidated Issue Inventory

### Deduplication Notes

Several issues appear in **both** reports. The canonical ID used below is from Report A, with the Report B row noted:

| Report A | Report B Row | Overlap |
|----------|-------------|---------|
| C-003 | B-CRIT-4 (line 10) | `canSendAmount` missing balance + daily-remaining check |
| C-004 | B-CRIT-2 (line 8) | Commission vs serviceFee accounting divergence |
| C-009 | — | Wallet balance update unguarded (Report A only) |
| — | B-CRIT-1 (line 7) | Deposit early-return skips `tx.set` — **NEW, unique to Report B** |
| — | B-CRIT-3 (line 9) | `ensurePositive` crashes paid debts (`amountDue == 0`) — **NEW** |
| — | B-CRIT-5 (line 11) | Debt auto-merge by phone corrupts history — **NEW** |
| — | B-MED-1 (line 19) | StoreModel fragile `as` cast — **NEW** |
| — | B-MED-2 (line 20) | Wallet list in-place mutation — **NEW** |
| — | B-MED-3 (line 21) | Side effects in DebtModel constructor — **NEW** |
| — | B-MED-4 (line 22) | Wrong exception type in TransactionModel — **NEW** |
| — | B-QW-1 (line 30) | Silent overlay data failure — **NEW** |
| — | B-QW-2 (line 31) | Fee calculator duplicated validation — **NEW** |

**New unique IDs assigned:** B-CRIT-1, B-CRIT-3, B-CRIT-5, B-MED-1 through B-MED-4, B-QW-1, B-QW-2.

---

## 🧱 Phase 1: Critical Stabilization

**Goal:** Eliminate all active revenue leakage, balance-integrity violations, data-corruption paths, and audit-trail gaps that can cause direct financial damage in production.

**Issues Covered:** C-001, C-004, C-006, C-007, C-008, C-009, B-CRIT-1, C-003, B-CRIT-3, C-005, C-002, C-010, C-011, B-CRIT-5, M-014

**Why First:** Every transaction processed while these remain unfixed can lose revenue, corrupt balances, or create unrecoverable accounting divergences. The blast radius is **every financial operation**.

**Risks If Skipped:** Active revenue leakage (C-001/C-006), negative balances (C-008/C-009), invisible deposit transactions (B-CRIT-1), user lockout from debt history (B-CRIT-3), and accounting reconciliation failure (C-004/C-007).

---

### Step 1.1 — Fee Calculation Pipeline Hardening

**Issues:** C-001, C-006, C-007, Q-010
**Files:** `transaction_fee_calculator.dart`, `fee_calculator.dart`

**Execution Strategy:**

1. **`transaction_fee_calculator.dart`** — Make `transactionType` parameter **non-nullable** (`required TransactionType transactionType`). Add a guard at method entry that throws `DomainException` if null is somehow passed via dynamic code. Add `AmountValidator.ensurePositive(amount)` at entry (Q-010).

2. **`fee_calculator.dart`** — Replace the `default` case (line 91-94) that returns `0.0` with a `throw DomainException('Unknown wallet type: $sourceWalletType')`. This converts silent revenue leakage into a visible, catchable failure.

3. **`transaction_fee_calculator.dart`** — Fix `totalAmount` calculation at line 51: change `amount + commission` to `amount + commission + fee`. The `TransactionCalculationResult.totalAmount` must reflect the **full user-facing cost**.

**Dependency:** None. This is a leaf-node fix. All callers already handle exceptions from this code path.

**Verification:** Unit test with null type → expects exception. Unit test with unknown wallet type → expects exception. Unit test verifying `totalAmount == amount + commission + serviceFee`.

---

### Step 1.2 — Balance Precision & Negative-Balance Prevention

**Issues:** C-008, C-009, M-014
**Files:** `transaction_validator_service.dart`, `wallet_repository.dart`

**Execution Strategy:**

1. **`transaction_validator_service.dart` line 120** — Fix epsilon direction. Change `balance < (totalDeduction - _epsilonEGP)` to `balance < totalDeduction`. For a financial system dealing in EGP (minimum unit 0.01), use **strict comparison without epsilon tolerance** on the deduction side. If floating-point tolerance is required, the check should be `balance + _epsilonEGP < totalDeduction` (tolerance benefits the *system*, not the user).

2. **`wallet_repository.dart`** — Split `updateWalletBalance` into two semantic methods:
   - `creditWallet(String walletId, double amount)` — validates `amount > 0`, increments balance.
   - `debitWallet(String walletId, double amount)` — validates `amount > 0`, reads current balance, asserts `balance >= amount`, then decrements.
   - Mark original `updateWalletBalance` as `@Deprecated` and route calls through the new methods.
   - Both methods must validate resulting balance stays `>= 0`.

3. **Add a shared constant** `static const double financialEpsilon = 0.01;` in a new or existing constants file (addresses M-009 simultaneously).

**Dependency:** Must be done **after** Step 1.1 (fee calculation must be correct before balance checks are tightened).

**Verification:** Unit test: balance=100, deduction=100.005 → must throw. Unit test: `debitWallet` with amount > balance → must throw.

---

### Step 1.3 — Deposit Audit Trail Gap

**Issue:** B-CRIT-1
**File:** `transaction_validator_service.dart` (lines 56-60)

**Execution Strategy:**

1. The early `return` at line 59 bypasses `tx.set(txRef, transaction.toFirestore())` which writes the transaction document. Remove the early return.
2. Restructure: move the `tx.set(txRef, ...)` call to execute **before** the early return, or refactor so the deposit path still writes the transaction document and then returns (skipping limit checks which are not relevant to deposits).
3. The deposit path should: (a) write the transaction document, (b) update wallet balance, (c) update stats counters, then return.

**Dependency:** Independent. Can be done in parallel with 1.1/1.2.

**Verification:** Integration test: create a deposit transaction → verify Firestore `transactions` collection contains the document.

---

### Step 1.4 — Commission/ServiceFee Accounting Unification

**Issues:** C-004, B-CRIT-2 (duplicate)
**File:** `transaction_validator_service.dart` (lines 36-38, 199-204)

**Execution Strategy:**

1. **Define the accounting rule explicitly** (requires product decision — flag for user review):
   - For **SEND**: User pays `amount + serviceFee`. The `serviceFee` is the network cost. The `commission` is the store markup. Both must be tracked in stats.
   - For **RECEIVE**: The store receives `amount` digitally. The `commission` is cash collected from the customer. It should **NOT** be added to the digital wallet balance (this is Report B's B-CRIT-2 finding — the receive balance formula `amount + commission` artificially inflates digital balance).

2. **Fix balance formula** (line 36-38): Change receive case from `amount + commission` to just `amount`. Commission is cash — it never enters the e-wallet.

3. **Fix stats tracking** (lines 199-204): Add a `totalServiceFee` field to wallet stats and store stats. Increment it with `transaction.serviceFee` for send transactions. Keep `totalCommission` incrementing with `transaction.commission`.

4. Add the `totalServiceFee` field to `WalletStats` model, `StoreStats` model, and the stats summary document writes.

**Dependency:** Must be done **after** Step 1.2 (balance logic must be correct first). This changes the balance formula.

> [!IMPORTANT]
> **User Review Required:** The receive balance formula change (`amount + commission` → `amount`) is a **behavioral change**. Confirm that commission on receive transactions is indeed cash-only and should not be added to digital balance. If some stores do add commission to digital balance intentionally, this needs a configuration flag.

**Verification:** Unit test: send 1000 with serviceFee=10, commission=5 → balance decreases by 1010, stats show both fee types. Receive 1000 with commission=5 → balance increases by 1000 only.

---

### Step 1.5 — Debt Model Critical Fixes

**Issues:** B-CRIT-3, C-005, B-CRIT-5
**Files:** `debt_model.dart`, `debt_provider.dart`, `debt_repository.dart`

**Execution Strategy:**

1. **B-CRIT-3 — Paid debt parsing crash:** In `debt_model.dart` line 74, change `AmountValidator.ensurePositive(amountDue)` to `AmountValidator.ensurePositiveOrZero(amountDue)`. Paid debts legitimately have `amountDue == 0.0`. `totalAmount` should remain `ensurePositive` (original debt amount must always be > 0).

2. **C-005 — amountDue ≤ totalAmount invariant:** After the positive checks, add: `if (amountDue > totalAmount) { throw DomainException('Debt $docId: amountDue ($amountDue) exceeds totalAmount ($totalAmount)'); }`.

3. **B-CRIT-5 — Debt auto-merge by phone:** In `debt_provider.dart` lines 232-236, the `createDebt` method auto-merges into any existing debt found by phone. Change logic to:
   - Only merge if the existing debt is **open** (`existingDebtByPhone.isOpen`).
   - If the existing debt is **paid**, create a new independent debt.
   - Add a `debtStatus` filter to `getDebtByCustomerPhone` query: only return open debts.

**Dependency:** B-CRIT-3 must be fixed before any code that loads paid debts is exercised. C-005 depends on B-CRIT-3 (both touch the same validation block).

**Verification:** Unit test: load paid debt with amountDue=0 → no crash. Unit test: debt with amountDue=60, totalAmount=50 → throws. Integration test: create debt for phone with existing paid debt → creates new debt, does not merge.

---

### Step 1.6 — Limit Validation Corrections

**Issues:** C-003, B-CRIT-4 (Report B's enhanced finding)
**File:** `wallet_model.dart` (lines 371-384)

**Execution Strategy:**

1. **`canSendAmount`:** Replace `amount <= limits.dailyLimit` with `amount <= limits.dailyRemaining`. Add balance check: `balance >= amount`. Full corrected logic:
   ```
   dailyRemaining >= amount && monthlyRemaining >= amount && balance >= amount
   ```

2. **`canReceiveAmount`:** Same daily-remaining fix: `amount <= limits.dailyRemaining` instead of `amount <= limits.dailyLimit`. No balance check needed for receive.

**Dependency:** Must be done **after** Step 1.2 (balance semantics must be settled first).

**Verification:** Unit test: wallet with dailyLimit=100, dailyUsed=90, call canSendAmount(20) → false. Unit test: wallet with balance=0, call canSendAmount(10) → false.

---

### Step 1.7 — Wallet Timestamp Logical Validation

**Issue:** C-002
**File:** `wallet_model.dart` (lines 194-203)

**Execution Strategy:**

1. After the null checks (line 199-203), add logical consistency validation:
   - `if (createdAt.isAfter(DateTime.now().add(Duration(minutes: 5))))` → throw (future creation date with tolerance for clock skew).
   - `if (lastDailyReset.isBefore(createdAt.subtract(Duration(days: 1))))` → throw (reset date unreasonably before creation).
   - `if (lastMonthlyReset.isBefore(createdAt.subtract(Duration(days: 31))))` → throw (same principle).

2. Log warnings (via `AppErrorHandler.logSilentError`) for near-boundary cases rather than throwing, to avoid breaking existing data that may have minor clock inconsistencies.

**Dependency:** Independent.

**Verification:** Unit test with `createdAt` in future → throws. Unit test with `lastDailyReset` far in past → throws.

---

### Step 1.8 — Subscription Migration Safety

**Issue:** C-010
**File:** `store_model.dart` (lines 77-79, 90-93)

**Execution Strategy:**

1. Replace `_withMigrationWarning()` with a method that throws `DomainException('Store document missing subscription field. Data migration required.')`.
2. Alternatively, if backwards compatibility requires loading legacy stores: create a `StoreSubscription.legacyFallback()` that creates a **suspended** (not active-lifetime) subscription, forcing the user through a re-activation flow. Log via `AppErrorHandler.handle()` at `ErrorSeverity.critical`.
3. Never silently grant lifetime access.

> [!WARNING]
> **Breaking Change:** Stores with missing subscription data will fail to load. A one-time Firestore migration script should be run to backfill subscription data for all legacy stores before deploying this fix.

**Dependency:** Requires a data migration plan. Do not deploy without first running the migration script.

**Verification:** Unit test: store document without subscription field → throws or returns suspended subscription. Manual verification: query Firestore for stores with null subscription field → should be zero after migration.

---

### Step 1.9 — SMS Pipeline Null Wallet Guard

**Issue:** C-011
**File:** `sms_processing_pipeline.dart` (lines 191-233)

**Execution Strategy:**

1. After all matching strategies complete (after line 189), add an explicit guard:
   ```
   if (matchedWalletId == null) {
     AppErrorHandler.logSilentError('All wallet matching strategies failed', 'SmsProcessingPipeline');
     // Still show overlay but with explicit "unknown wallet" flag
     overlayArgs['walletMatchFailed'] = true;
   }
   ```
2. The overlay UI must handle `walletMatchFailed == true` by requiring the user to manually select a wallet before submitting. The overlay should **never** submit a transaction with a null walletId.
3. Add structured logging for which matching strategy succeeded (addresses M-013 partially).

**Dependency:** Requires corresponding overlay UI change to handle the `walletMatchFailed` flag.

**Verification:** Manual test: trigger SMS with no SIM mappings → overlay shows wallet selection prompt, does not auto-submit.

---

## 🏗 Phase 2: Structural Corrections

**Goal:** Eliminate tech debt that creates fragile logic, silent data corruption paths, and domain purity violations.

**Issues Covered:** M-001 through M-015, B-MED-1 through B-MED-4

**Dependencies:** Phase 1 must be complete. Many of these issues interact with the same files modified in Phase 1.

---

### Step 2.1 — Domain Model Hardening

**Issues:** M-001, M-003, M-004, M-005, M-015, B-MED-3, B-MED-4

| Issue | File | Action |
|-------|------|--------|
| M-001 | `wallet_model.dart` | Guard `dailyRemaining`/`monthlyRemaining` with `max(0.0, ...)` |
| M-003 | `wallet_usecase.dart` | Replace magic `DateTime(1970)` with named constant `kSentinelDate` with doc comment |
| M-004 | `user_model.dart` | Make `lastLogin` nullable; initialize to `createdAt` if missing |
| M-005 | `debt_model.dart` | Add `AppErrorHandler.logSilentError` when `debtStatus` or `debtType` is null before defaulting |
| M-015 | `store_model.dart` | Add null guard for `createdAt` before any comparison usage |
| B-MED-3 | `debt_model.dart` | Remove `AppErrorHandler.handle` call from constructor; throw `DomainException` instead, let repository handle logging |
| B-MED-4 | `transaction_model.dart` | Replace `NotFoundException` with `FormatException` for malformed payload |

**Execution Strategy:** Apply each fix independently within its file. These are isolated domain model changes with no cross-file dependencies.

---

### Step 2.2 — Validation & Parsing Consistency

**Issues:** M-002, M-006, M-010, B-MED-1

| Issue | File | Action |
|-------|------|--------|
| M-002 | `transaction_repository.dart` | Move post-deserialization validation into `TransactionModel.fromMap()` |
| M-006 | `number_parser.dart` | Add check: if sanitized string contains more than one `.`, return `defaultValue` (or throw) |
| M-010 | `license_key_model.dart` | Extract `??` exception into explicit guard clause before construction |
| B-MED-1 | `store_model.dart` | Replace `as Map<String, dynamic>` casts with safe `is Map` checks |

---

### Step 2.3 — Error Handling & Observability

**Issues:** M-008, M-011, M-012, M-013

| Issue | File | Action |
|-------|------|--------|
| M-008 | `database_sync_service.dart` | Replace `.name` string comparison with enum comparison |
| M-011 | `app_error_handler.dart` | Add file-based or local analytics logging in debug mode |
| M-012 | `amount_validator.dart` | Replace hardcoded Arabic messages with localization keys; throw error codes |
| M-013 | `sms_processing_pipeline.dart` | Add structured logging showing which matching strategy succeeded |

---

### Step 2.4 — Configuration Externalization

**Issues:** M-007, M-009

| Issue | File | Action |
|-------|------|--------|
| M-007 | `transaction_validator_service.dart` | Move hardcoded limits (70000, 60000) to `AppConstants` |
| M-009 | `debt_repository.dart` | Use shared `financialEpsilon` constant (created in Phase 1, Step 1.2) |

---

### Step 2.5 — State Immutability Fix

**Issue:** B-MED-2
**File:** `wallet_provider.dart` (line 338)

**Execution Strategy:** Replace in-place list mutation `_wallets[index] = ...` with `_wallets = List.from(_wallets)..[index] = wallet.copyWith(balance: newBalance)`. This ensures UI layers detect the list change via reference inequality.

---

## 🧼 Phase 3: Optimization & Hardening

**Goal:** Clean up quick wins, improve developer experience, and eliminate remaining code smells.

**Issues Covered:** Q-001 through Q-010, B-QW-1, B-QW-2

---

### Step 3.1 — Exception Type Corrections

**Issues:** Q-003, Q-004, Q-006

Replace generic `Exception` with `NotFoundException` in:
- `user_model.dart` line 76
- `store_model.dart` line 53
- `debt_model.dart` line 60

---

### Step 3.2 — Silent Fallback Elimination

**Issues:** Q-002, Q-005

- `wallet_enums.dart` line 72: Add `AppErrorHandler.logSilentError` before defaulting to `active`.
- `transaction_enums.dart` line 69: Add `AppErrorHandler.logSilentError` before defaulting to `pending`.

---

### Step 3.3 — Code Quality Polish

**Issues:** Q-001, Q-007, Q-008, Q-009, Q-010, B-QW-1, B-QW-2

| Issue | File | Action |
|-------|------|--------|
| Q-001 | `transaction_model.dart` | Fix misleading comment about totalAmount composition |
| Q-007 | `transaction_validator_service.dart` | Redact PII from debugPrint (mask phone numbers, truncate IDs) |
| Q-008 | `database_sync_service.dart` | Make retry delay configurable or use exponential backoff |
| Q-009 | `debt_repository.dart` | Log errors in `getDebtsCount`/`getDebtsTotalAmount` instead of silent return 0 |
| Q-010 | `transaction_fee_calculator.dart` | Add `AmountValidator.ensurePositive(amount)` (partially covered in Phase 1) |
| B-QW-1 | `wallet_provider.dart` | Add logging when overlay data is malformed instead of silent return |
| B-QW-2 | `fee_calculator.dart` | Replace inline validation with `AmountValidator.ensurePositive(amount)` |

---

## 🔗 Issue-to-Plan Mapping

| Issue | Phase | Step | Reason |
|-------|-------|------|--------|
| C-001 | 1 | 1.1 | Revenue leakage — null type bypasses fees |
| C-002 | 1 | 1.7 | State corruption — timestamp invariants |
| C-003 | 1 | 1.6 | Balance/limit check incomplete |
| C-004 | 1 | 1.4 | Accounting divergence — commission vs fee |
| C-005 | 1 | 1.5 | Debt invariant violation |
| C-006 | 1 | 1.1 | Revenue leakage — unknown wallet type |
| C-007 | 1 | 1.1 | Fee excluded from total |
| C-008 | 1 | 1.2 | Negative balance via epsilon error |
| C-009 | 1 | 1.2 | Unguarded balance update |
| C-010 | 1 | 1.8 | License enforcement bypass |
| C-011 | 1 | 1.9 | Null wallet routing |
| B-CRIT-1 | 1 | 1.3 | Deposit audit trail missing |
| B-CRIT-2 | 1 | 1.4 | Duplicate of C-004 |
| B-CRIT-3 | 1 | 1.5 | Paid debt crash |
| B-CRIT-4 | 1 | 1.6 | Duplicate of C-003 (enhanced) |
| B-CRIT-5 | 1 | 1.5 | Debt merge corruption |
| M-001 | 2 | 2.1 | Negative remaining values |
| M-002 | 2 | 2.2 | Validation timing |
| M-003 | 2 | 2.1 | Magic date sentinel |
| M-004 | 2 | 2.1 | Nullable lastLogin |
| M-005 | 2 | 2.1 | Silent enum fallback |
| M-006 | 2 | 2.2 | Multi-dot parsing |
| M-007 | 2 | 2.4 | Hardcoded limits |
| M-008 | 2 | 2.3 | String vs enum comparison |
| M-009 | 2 | 2.4 | Hardcoded epsilon |
| M-010 | 2 | 2.2 | Exception in factory |
| M-011 | 2 | 2.3 | Debug mode logging |
| M-012 | 2 | 2.3 | Hardcoded Arabic messages |
| M-013 | 2 | 2.3 | SMS matching logging |
| M-014 | 1 | 1.2 | Wallet credit/debit split |
| M-015 | 2 | 2.1 | Null createdAt guard |
| B-MED-1 | 2 | 2.2 | Fragile type casting |
| B-MED-2 | 2 | 2.5 | In-place list mutation |
| B-MED-3 | 2 | 2.1 | Side effects in constructor |
| B-MED-4 | 2 | 2.1 | Wrong exception type |
| Q-001 | 3 | 3.3 | Misleading comment |
| Q-002 | 3 | 3.2 | Silent enum fallback |
| Q-003 | 3 | 3.1 | Generic exception |
| Q-004 | 3 | 3.1 | Generic exception |
| Q-005 | 3 | 3.2 | Silent enum fallback |
| Q-006 | 3 | 3.1 | Generic exception |
| Q-007 | 3 | 3.3 | PII in debug logs |
| Q-008 | 3 | 3.3 | Hardcoded retry |
| Q-009 | 3 | 3.3 | Silent error return |
| Q-010 | 3 | 3.3 | Missing amount validation |
| B-QW-1 | 3 | 3.3 | Silent overlay failure |
| B-QW-2 | 3 | 3.3 | Duplicated validation |

---

## ⚠️ Risk Management Strategy

### Potential Breakpoints

| Change | Risk | Mitigation |
|--------|------|------------|
| Step 1.1: Unknown wallet type now throws | Transactions with typo'd wallet types will fail loudly | Add monitoring/alerting for `DomainException` in fee calculator before deploy. Audit Firestore for non-standard walletType values. |
| Step 1.4: Receive balance formula change | Existing stores may rely on commission being added to digital balance | **Requires product confirmation.** Deploy behind feature flag if uncertain. |
| Step 1.5: Paid debt amountDue=0 fix | If any paid debt in Firestore has amountDue as negative (legacy corruption), `ensurePositiveOrZero` will still throw | Run Firestore query for debts with `amountDue < 0` before deploying. |
| Step 1.8: Subscription migration | Stores missing subscription field will break | **Must run data migration script first.** |
| Step 1.2: Epsilon removal / strictening | Edge-case transactions at exact balance boundary may start failing | This is the **correct** behavior. Document the change. |

### Data Safety Precautions

1. **Before Phase 1:** Take a Firestore export/backup of `wallets`, `transactions`, `debts`, and `stores` collections.
2. **Before Step 1.4:** Snapshot current `totalCommission` stats across all wallets for reconciliation after fix.
3. **Before Step 1.8:** Run a Firestore query to identify all stores with `subscription == null` and backfill them.
4. **Before Step 1.5:** Run a Firestore query for debts where `amountDue > totalAmount` and fix the data.

### Rollback Considerations

- Each step should be a **separate, atomic commit** so individual steps can be reverted.
- Steps 1.1-1.3 are safe to roll back independently.
- Step 1.4 (balance formula change) is **not safely rollable** once new transactions are created with the corrected formula — plan for forward-fix only.
- Step 1.8 rollback would re-expose the silent lifetime migration — acceptable only if data migration hasn't been run yet.

---

## 🚀 Final Evaluation

### Expected System Stability After Fix

| Dimension | Before | After |
|-----------|--------|-------|
| **Revenue Integrity** | 🔴 Active leakage on 3 paths | 🟢 All fee paths validated or throw |
| **Balance Accuracy** | 🔴 Negative balance possible | 🟢 Strict non-negative enforcement |
| **Audit Trail** | 🔴 Deposits invisible | 🟢 All transactions documented |
| **Accounting Parity** | 🔴 Commission ≠ ServiceFee tracking | 🟢 Both tracked independently |
| **Debt Integrity** | 🔴 Paid debts crash, invariants broken | 🟢 Full lifecycle validation |
| **License Enforcement** | 🔴 Silent lifetime upgrade | 🟢 Explicit migration required |
| **SMS Routing** | 🟠 Null wallet silently accepted | 🟢 User prompted on match failure |
| **Domain Purity** | 🟠 Side effects in models | 🟢 Clean separation |

### Remaining Risks After All 3 Phases

1. **Concurrent transaction race conditions** — The Firestore transaction in `validateAndSave` provides atomicity per-wallet, but cross-wallet operations (if any) remain unprotected. This is an architectural concern beyond the scope of these reports.
2. **Floating-point arithmetic** — EGP amounts are stored as `double`. For absolute precision, migration to integer-based piasters (1 EGP = 100 piasters) would be ideal but is a major refactor outside this scope.
3. **SMS parser false positives** — The SMS parsing engine itself was not audited. Incorrectly parsed amounts would still propagate through the now-hardened pipeline.

---

Correction Planning Phase Complete. Awaiting Execution Directive.
