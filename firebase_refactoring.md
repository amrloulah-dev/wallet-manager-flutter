# 🛠️ Wallet Manager - Firebase & Firestore Refactoring Blueprint (Phase 4.1: Architecture Leaks)

## 📌 1. General Context & System Prompt
**To the AI Agent (Antigravity / Gemini CLI):**
You are working on "Wallet Manager", a Flutter-based financial operations app for Egyptian store owners. 
**Core Constraints:**
1. **$0 Budget (Spark Plan):** No Cloud Functions. Minimal Firestore reads.
2. **100% Financial Atomicity:** No partial failures are allowed in financial operations.
3. **GLOBAL SEARCH & DESTROY INSTRUCTION:** For every issue listed below, do NOT just fix the explicitly mentioned file. You MUST scan the ENTIRE codebase for the exact same anti-pattern and apply the fix globally.

Your task is to fix critical atomicity leaks, unbounded queries, and error handling oversights, ensuring these fixes are applied project-wide.

---

## 📌 2. Global Issue: Data Integrity & Atomicity Leaks

### The Anti-Pattern
Running a Firestore `runTransaction`, waiting for it to complete, and then sequentially running another repository function to update stats (e.g., calling `_statsRepository.updateStatsOnWalletChange` after a wallet debit transaction completes). This causes data desync if the app crashes between the two operations.

### The Fix (Apply Project-Wide)
All related mutations MUST happen inside a single `runTransaction` block. 
1. **In `WalletRepository` (`creditWallet`, `debitWallet`):** Modify the logic so the stats update happens *inside* the main wallet transaction. You may need to update the method signature of `_statsRepository.updateStatsOnWalletChange` to accept a `Transaction` parameter (e.g., `Transaction tx`), or move the stats mutation logic directly into the wallet's `runTransaction` block.
2. **In `TransactionRepository` (`createTransaction`):** Move the call to `_statsRepository.incrementOpenDebtStats` (and any similar stats calls) entirely inside the `TransactionValidatorService.validateAndSave(transaction)` transaction block.
3. **Global Audit:** Scan ALL repositories. If you find any database write or stats update occurring sequentially *after* a `runTransaction` or `WriteBatch` has concluded, refactor it to be included INSIDE the atomic block.

---

## 📌 3. Global Issue: Billing Explosions & Unbounded Queries (Memory Leaks)

### The Anti-Pattern
Calling `.get()` on collections (like `wallets`, `debts`, `transactions`) without a `.limit()` clause or pagination, pulling massive datasets into memory at once.

### The Fix (Apply Project-Wide)
1. **In `MigrationService` (`recalculateStoreStats`):** Refactor the unbounded `.get()` queries. Use Firestore Aggregate Queries (`count()`, `sum()`) where possible to calculate stats directly on the server without downloading documents. If document processing is strictly required, implement cursor-based pagination (chunking) with a `.limit(500)`.
2. **Global Audit:** Scan ALL services and repositories (especially utility/migration scripts). Add `.limit()` or use aggregate queries for any unbounded `.get()` list operations found.

---

## 📌 4. Global Issue: Incomplete Error Handling (FirebaseExceptions)

### The Anti-Pattern
Executing Firebase operations in background services or migration scripts without explicit `try/catch` blocks targeting `FirebaseException`, allowing raw exceptions to bypass the global error handler.

### The Fix (Apply Project-Wide)
1. **In `MigrationService`:** Wrap the entire logic of `recalculateStoreStats` (and similar methods) in a robust `try/catch` block.
2. Catch `FirebaseException` explicitly, map it to the domain's `ServerException`, and pass it to the `AppErrorHandler` for standardized logging and UI feedback.
3. **Global Audit:** Scan all `services/` (like background processors or sync services). Ensure all Firebase interactions are securely wrapped and mapped to `AppErrorHandler`.