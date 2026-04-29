# 🛠️ Execution Plan: Firestore Architecture & Billing Optimization

**Status:** APPROVED
**Story Context:** Our financial application is currently suffering from "silent bleeding." We have massive Firestore billing leaks due to unbounded queries fetching entire collections just to calculate sums or counts. Furthermore, we have hidden race conditions and non-atomic writes that risk corrupting our financial dashboard (desyncing stats from actual wallet states). 
Our mission in this plan is to lock down the data layer: we will replace expensive reads with $O(1)$ operations or native index counting, wrap multi-step financial updates in strict atomic transactions, and eradicate silent error swallowing that masks database failures.

---

## 🏗️ Step 1: Stopping the Billing Leaks (Query Optimization)

### 1.1 The Wallet Aggregation Leak (C-001, C-002)
* **The Problem:** Whenever the app needs to know the total balance or the number of wallets, it downloads *every single active wallet document*. If a store has 1,000 wallets, we pay for 1,000 reads just to show two numbers on the screen.
* **The Solution:** Stop querying the `wallets` collection for aggregation. Instead, fetch the pre-calculated stats from the single `stats/summary` document. This reduces the cost from $O(N)$ reads to exactly 1 read.
* **Implementation:**
  * **File:** `lib/data/repositories/wallet_repository.dart`
  * **Code:**
    ```dart
    // Replace unbounded .get() in getTotalBalance & getWalletsCount:
    final statsDoc = await _firestore.collection(FirebaseConstants.stores)
        .doc(storeId).collection('stats').doc('summary').get();
        
    // For getTotalBalance:
    return statsDoc.data()?['totalBalance'] ?? 0.0;
    
    // For getWalletsCount:
    return statsDoc.data()?['totalWallets'] ?? 0;
    ```

### 1.2 The Employee Count Leak (C-003)
* **The Problem:** Similar to wallets, we are downloading all employee user documents just to run `.length` on the array.
* **The Solution:** Use Firestore's native index-level counting. The `.count()` method calculates the length on the server side using indexes, costing 0 document reads (1 read per 1000 index hits).
* **Implementation:**
  * **File:** `lib/data/repositories/employee_repository.dart`
  * **Code:**
    ```dart
    final snapshot = await _usersCollection
        .where(FirebaseConstants.storeId, isEqualTo: storeId)
        .where(FirebaseConstants.role, isEqualTo: FirebaseConstants.employeeRole)
        .where(FirebaseConstants.isActive, isEqualTo: true)
        .count()
        .get();
    return snapshot.count ?? 0;
    ```

---

## 🔒 Step 2: Atomic Operations & Race Condition Prevention

### 2.1 The TOCTOU Registration Race (C-007)
* **The Problem:** In `verifyDevice`, we read a document, check if it exists, and then write. If two identical requests hit the server at the exact same millisecond, both read `exists == false`, and both write, overwriting the crucial `firstSeenAt` timestamp.
* **The Solution:** Wrap the logic inside a `runTransaction`. This locks the document, ensuring that if two requests arrive, they are queued sequentially.
* **Implementation:**
  * **File:** `lib/data/repositories/subscription_repository.dart`
  * **Code:**
    ```dart
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) {
        transaction.set(docRef, registrationModel.toFirestore()); // Safe creation
      } else {
        transaction.update(docRef, {
           'lastSeenAt': FieldValue.serverTimestamp(),
        });
      }
    });
    ```

### 2.2 The Stats Desync Nightmare (C-004, C-005)
* **The Problem:** Toggling a wallet's status and updating the store's stats are executed as separate `await` calls. If the internet drops between them, the wallet changes state but the dashboard stats don't, causing a permanent financial desync.
* **The Solution:** Combine the wallet update and the `stats/summary` update into a single atomic `runTransaction`. Also, completely remove the dual-write to the legacy root `stores/{id}.stats` field to save billing and prevent divergence.
* **Implementation:**
  * **Files:** `wallet_repository.dart`, `stats_repository.dart`
  * Modify `toggleWalletStatus` to use `_firestore.runTransaction`. Read the wallet state, toggle it, and apply the counter updates (`FieldValue.increment`) to the `stats/summary` document inside the same transaction block.

### 2.3 The 500-Limit Batch Crash (C-008)
* **The Problem:** Firestore has a hard limit of 500 operations per `WriteBatch`. If an admin tries to reset limits for a store with 600 wallets, the entire operation crashes with a `FirebaseException`.
* **The Solution:** Implement Array Chunking. We will slice the wallets list into safe chunks of 450 and commit them sequentially.
* **Implementation:**
  * **File:** `lib/data/repositories/wallet_repository.dart` (`resetLimitsForWallets`)
  * **Code:**
    ```dart
    final chunkSize = 450; 
    for (var i = 0; i < wallets.length; i += chunkSize) {
      final batch = _firestore.batch();
      final chunk = wallets.sublist(i, i + chunkSize > wallets.length ? wallets.length : i + chunkSize);
      for (final wallet in chunk) {
         batch.update(walletRef, updates);
      }
      await batch.commit();
    }
    ```

---

## 🧹 Step 3: Eradicating Tech Debt & Silent Failures

### 3.1 The Silent Fraud Bypass (M-003, M-006, M-009)
* **The Problem:** Several repositories use empty `catch` blocks or return defaults (`return 0` or `return true`) when Firestore fails. Most dangerously, if a database error occurs during device verification, it returns `true`, allowing unauthorized devices to bypass anti-fraud checks.
* **The Solution:** Remove these silent catches. For security/fraud checks, fail-closed (throw or return false). For data fetching, propagate the `DomainException` to the UI using `AppErrorHandler` so the user knows the action failed.

### 3.2 Time Travel and Magic Strings (M-002, M-008, M-004)
* **The Problem:** We rely on the client device's clock (`Timestamp.now()`), allowing users to spoof transaction times. We also use hardcoded collection strings which cause typos.
* **The Solution:** Standardize timestamps and string constants.
* **Implementation:**
  * Add missing constants (`'stats'`, `'daily_stats'`, etc.) to `FirebaseConstants`.
  * Replace ALL instances of `Timestamp.now()` with `FieldValue.serverTimestamp()` for write operations.
  * Fix the string interpolation bug in `wallet_repository.dart`: `throw ServerException('فشل تحديث المحفظة: $e');`

### 3.3 The Duplicate Stats Hazard (M-001)
* **The Problem:** The logic to update transaction stats exists in both `TransactionValidatorService` (secured in a transaction) and `StatsRepository` (standalone). This risks developers using the wrong, un-secured method.
* **The Solution:** Delete `updateStatsOnTransactionCreate` from `StatsRepository`. Force all callers to use the atomic logic baked into `TransactionValidatorService`.

### 3.4 Untestable Repositories (M-005)
* **The Problem:** `SystemConfigRepository` does not use Dependency Injection, hardcoding the Firestore instance, making it impossible to mock during tests.
* **The Solution:** Inject `FirebaseFirestore` via the constructor like all other repositories.