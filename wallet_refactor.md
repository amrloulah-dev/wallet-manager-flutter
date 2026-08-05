Task: Implement Backward Compatibility Migration & Fix Destructive Limit Reset Bug

Role & Context:
You are an elite Flutter/Dart Engineer. We have a critical "Destructive Read Mutation" bug affecting legacy users in production. 
Currently, legacy Firestore wallet documents lack the new `walletStatus` field and the nested `sendLimits` / `receiveLimits` maps. 
When `WalletModel.fromMap` parses these old documents, it incorrectly defaults their status to 'new' (which slashes their transaction limits) and throws exceptions for missing nested limit maps. 
Furthermore, because missing reset timestamps default to null, `WalletProvider` immediately triggers a `resetLimitsForWallets` call to Firestore. This call currently overwrites the entire document, permanently saving the corrupted 'new' state and erasing their custom legacy limits.

Strict Architectural Constraints:
1. DO NOT change the UI. Focus entirely on `WalletModel` (Data Layer) and `WalletRepository` (Persistence Layer).
2. Follow Clean Architecture principles. Do not introduce breaking changes for newly created wallets.
3. Ensure strict null-safety and avoid throwing exceptions for missing legacy fields.

--------------------------------------------------------------------------------

Target 1: Safe Legacy Deserialization (Migration Factory)
File: `lib/data/models/wallet_model.dart` (and `WalletLimits` / `WalletStatus` if applicable)

Implementation Steps:
1. Update `walletStatus` parsing:
   - If `data['walletStatus']` is null or missing, it MUST fallback to `'old'` (or `WalletStatus.old`). Never default an undocumented legacy wallet to `'new'` or `'active'`.
2. Update `sendLimits` and `receiveLimits` parsing:
   - Remove the code that throws a `DomainException` if the `sendLimits` or `receiveLimits` maps are missing.
   - Implement a fallback mechanism: If the nested maps do not exist, reconstruct the `WalletLimits` object by safely reading legacy root-level fields (e.g., `data['dailyLimit']`, `data['monthlyLimit']`). 
   - If root-level fields are also missing, fallback to the standard market limits for 'old' wallets (Daily: 60000.0, Monthly: 200000.0) with `0.0` usage.
3. Update Timestamp Fallbacks:
   - Ensure `lastDailyReset` and `lastMonthlyReset` fallback to `DateTime.now()` (or `Timestamp.now()`) during deserialization if they are null, to prevent `WalletProvider` from triggering false-positive immediate resets on the very first load.

--------------------------------------------------------------------------------

Target 2: Secure the Database Mutation (Prevent Document Overwrite)
File: `lib/data/repositories/wallet_repository.dart` (Locate `resetLimitsForWallets` or equivalent method)

Implementation Steps:
1. Audit the Firestore `update` or `set` payload inside this method.
2. The method MUST NOT use `wallet.toMap()` or `wallet.copyWith()` to overwrite the entire document.
3. Refactor the mutation to use a highly specific, pinpoint `Map<String, dynamic>` payload that strictly resets usage counters and timestamps ONLY:
   ```dart
   final Map<String, dynamic> resetData = {
     'sendLimits.dailyUsed': 0.0,
     'sendLimits.monthlyUsed': 0.0, // If applicable for monthly reset
     'receiveLimits.dailyUsed': 0.0,
     'receiveLimits.monthlyUsed': 0.0, // If applicable for monthly reset
     'lastDailyReset': FieldValue.serverTimestamp(),
     // Include lastMonthlyReset if this function handles monthly resets
   };
   // Update document using this specific map
   await _firestore.collection('wallets').doc(wallet.walletId).update(resetData);