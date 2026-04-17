# Specification: Firestore Cost Optimization & Architecture Refactor (Feature 007)

## Overview
This architectural shift resolves severe Firestore billing explosions and Out-Of-Memory (OOM) crashes by moving from a "Client-Side Aggregation" pattern to a "Pre-aggregated Single Source of Truth" pattern. It also implements cursor-based pagination for unbounded queries across the application.

## Functional Requirements
1. **Eradicate Client-Side Aggregation:**
   - Delete `getTransactionAggregates` in `transaction_repository.dart`.
   - Delete `reconcileStatsFromWallets` and `reconcileStatsFromDebts` in `stats_repository.dart`.
   - Delete `getDebtAggregates` in `debt_repository.dart`.
   - Remove these methods entirely; no commenting out or grace period.
2. **Cursor-Based Pagination:**
   - Enforce a hard `.limit(20)` on lists (Transactions, Wallets, Debts).
   - Implement `startAfterDocument` for infinite scrolling.
   - Display a Standard Spinner at the bottom of the list when fetching the next batch.
   - If the `lastDocument` (cursor) is missing/deleted, show an error message and stop pagination.
3. **Single Source of Truth Subscription:**
   - The Dashboard UI must rely entirely on two pre-aggregated streams: `summary` and `daily_stats/{date}`.
   - Bind Total Balance, Total Commission, and Sent/Received counts to these DocumentSnapshot streams.
4. **Atomic Writes Enforcement:**
   - Ensure `TransactionValidatorService` and similar core services use `FieldValue.increment()` for all `summary` and `daily_stats` updates inside `WriteBatch` or `Transaction`. No manual arithmetic.

## Non-Functional Requirements
- **Performance:** Drastically reduce Firestore Document Reads.
- **Stability:** Prevent RAM crashes by fetching data in chunks of 20 instead of entire collections.
- **Code Quality:** Ensure `flutter analyze` passes with 0 issues after refactoring.

## Acceptance Criteria
- [ ] Code search yields 0 occurrences of `getTransactionAggregates`, `reconcileStatsFromWallets`, `reconcileStatsFromDebts`, and `getDebtAggregates`.
- [ ] Unbounded `.collection(...).get()` queries for Transactions, Wallets, and Debts are replaced with `.limit(20)` and `.startAfterDocument()`.
- [ ] Dashboard statistics accurately display without fetching entire transaction or debt collections.
- [ ] All database write operations for aggregations use `FieldValue.increment`.
- [ ] `flutter analyze` returns 0 issues.

## Out of Scope
- Implementing aggregations for entities other than stores (e.g., individual user lifetime performance).
- UI redesigns beyond adding the standard loading spinner for pagination or error messages for missing cursors.
