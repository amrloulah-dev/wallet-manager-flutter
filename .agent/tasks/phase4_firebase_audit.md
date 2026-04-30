# Phase 4: Firebase & Firestore Audit Report

## 1. Unbounded Queries (Billing Explosion Risks)
The following queries lack a `.limit()` clause, which can lead to excessive document reads if the collections grow over time. This will directly impact Firebase billing and memory usage.

### Findings:
- **`UserRepository.getUsersByStoreId`**:
  ```dart
  final querySnapshot = await _usersCollection
      .where(FirebaseConstants.storeId, isEqualTo: storeId)
      .where(FirebaseConstants.isActive, isEqualTo: true)
      .get(); // <-- Missing .limit()
  ```
- **`UserRepository.getEmployeesByStoreId`**:
  ```dart
  final querySnapshot = await _usersCollection
      .where(FirebaseConstants.storeId, isEqualTo: storeId)
      .where(FirebaseConstants.role, isEqualTo: FirebaseConstants.employeeRole)
      .where(FirebaseConstants.isActive, isEqualTo: true)
      .orderBy(FirebaseConstants.fullName)
      .get(); // <-- Missing .limit()
  ```

**Recommendation:**
Introduce pagination for these queries, or apply a sensible hard limit (e.g., `.limit(100)` for active employees/users) to guarantee bounded reads.

## 2. Security Rules Validation
The `firestore.rules` structure appears robust in restricting access to store-specific paths based on the user's `storeId`.

However, the `users` collection rules:
```javascript
match /users/{userId} {
  allow read: if isOwner(resource.data.storeId) || isEmployee(resource.data.storeId);
  // ...
}
```
If a query attempts to read `users` without a `storeId` filter, it will fail due to rules, but the client code correctly filters by `storeId` in `UserRepository`.

## 3. Transaction Atomicity and Dart Math Risk
While reviewing transactions, a potential race condition pattern was observed when calculations are done in Dart code instead of using `FieldValue.increment()`.

### Finding: `WalletRepository.debitWallet`
```dart
await _firestore.runTransaction((transaction) async {
  // ...
  final currentBalance = NumberParser.toDouble(data?['balance']);
  
  // Dart-side math
  transaction.update(walletRef, {
    'balance': currentBalance - amount,
  });
});
```
**Status: Safe (but fragile).** Since this occurs *inside* a `runTransaction` block after a `.get()`, Firestore's optimistic concurrency control protects against race conditions. If another process updates the wallet concurrently, the transaction retries.

However, in `WalletRepository.creditWallet`:
```dart
transaction.update(walletRef, {
  'balance': FieldValue.increment(amount),
});
```
**Recommendation:** Refactor `debitWallet` to use `FieldValue.increment(-amount)` to avoid the explicit read and manual calculation. This aligns with `creditWallet` and provides stronger guarantees without relying on transaction retries for simple decrements. (Note: The read is still necessary to validate that `currentBalance >= amount`, but the write should use `increment`).

## 4. Cache Eviction & Stale Data
In `TransactionRepository` and `DebtRepository`, cache keys are hardcoded to page 0:
```dart
_cacheManager.clearWhere((key) => key.startsWith('transactions_page_0_'));
```
**Risk:** When a new transaction is created, it clears `page_0`. If a user has scrolled to `page_1` or `page_2`, those cached queries are NOT invalidated. This leads to pagination drift and stale data on subsequent pages.

**Recommendation:**
Clear ALL paginated keys for that collection when a mutation occurs, e.g., `_cacheManager.clearWhere((key) => key.startsWith('transactions_page_'));`.

## 5. Indexing Review
All complex queries requiring composite indexes are present and correct, particularly in `TransactionRepository` where `storeId`, `isDeleted`, and `transactionDate` are queried together. The `firestore.indexes.json` file appropriately covers these access patterns.

## Summary of Action Items
1. [ ] Add `.limit()` to all list-based reads in `UserRepository`.
2. [ ] Fix cache invalidation regex/starts-with logic to clear all paginated pages, not just `page_0_`.
3. [ ] (Optional) Standardize `debitWallet` to use `FieldValue.increment(-amount)`.
