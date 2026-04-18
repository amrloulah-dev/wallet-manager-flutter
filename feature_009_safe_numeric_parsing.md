# 🛠️ Detailed Execution Plan: Centralized Numeric Parsing & Null-Safety (Feature 009)

**CRITICAL DIRECTIVES FOR DEVELOPER / AI AGENT:**
This document outlines the architectural refactoring to eliminate unsafe data casting (`as int`, `as num`) from Firestore maps. You will implement a centralized `NumberParser` utility and refactor all vulnerable models and providers.
1. Execution MUST be strictly sequential.
2. Do NOT proceed to the next phase without completing the Verification Gates.
3. NEVER use `as num`, `as int`, or `as double` directly on dynamic map values again.

---

## 🏗️ Phase 1: Create the Centralized `NumberParser` Utility

### 🔴 Problem Definition
Data coming from Firestore (NoSQL) is loosely typed. Numbers may arrive as `int`, `double`, or even `String`. Using strict Dart casting (`as int`) causes fatal `TypeError` crashes.

### 🟢 Architectural Solution
Create a robust, central utility class that safely parses any dynamic value into a guaranteed `double` or `int`, falling back to `0` or `0.0` if parsing fails.

### 📋 Implementation Tasks
- [ ] Create a new file: `lib/core/utils/number_parser.dart`.
- [ ] Implement the `NumberParser` class with a static `toDouble` method:
      ```dart
      class NumberParser {
        static double toDouble(dynamic value, [double defaultValue = 0.0]) {
          if (value == null) return defaultValue;
          if (value is num) return value.toDouble();
          if (value is String) return double.tryParse(value.replaceAll(',', '')) ?? defaultValue;
          return defaultValue;
        }

        static int toInt(dynamic value, [int defaultValue = 0]) {
          if (value == null) return defaultValue;
          if (value is int) return value;
          if (value is double) return value.toInt();
          if (value is String) return int.tryParse(value.replaceAll(',', '')) ?? defaultValue;
          return defaultValue;
        }
      }
      ```

### 🔍 Verification Gates (Phase 1)
- [ ] **Code Audit:** Verify `lib/core/utils/number_parser.dart` exists and contains both robust methods handling `num`, `String`, and `null` safely.

---

## 🔄 Phase 2: Refactor Data Models and Repositories

### 🔴 Problem Definition
Models and repositories are currently failing to build if Firestore returns a `double` when an `int` is expected (e.g., in Aggregation Queries).

### 🟢 Architectural Solution
Replace all explicit casts in `fromMap` factory constructors and repository logic with `NumberParser`.

### 📋 Implementation Tasks
- [ ] Navigate to `lib/data/models/daily_stats_model.dart`. Update `transactionCount` using `NumberParser.toInt(map['transactionCount'])`. Remove `as int`.
- [ ] Navigate to `lib/data/models/stats_summary_model.dart`. Update `totalWallets` (and any other numeric field) using `NumberParser.toInt` or `NumberParser.toDouble`.
- [ ] Navigate to `lib/data/models/sim_wallet_config.dart`. Update `simSlotIndex` using `NumberParser.toInt(map['simSlotIndex'])`.
- [ ] Navigate to `lib/data/repositories/device_repository.dart` and `subscription_repository.dart`. Replace `data['trialCount'] as int? ?? 0` with `NumberParser.toInt(data['trialCount'])`.
- [ ] Navigate to `lib/data/repositories/debt_repository.dart`. In `fetchDebtStatistics`, replace `(stats['openCount'] as int)` with `NumberParser.toInt(stats['openCount'])`.

### 🔍 Verification Gates (Phase 2)
- [ ] **Code Audit:** Inspect the specified files. There MUST be exactly 0 occurrences of `as int` or `as num` applied to map/JSON data.

---

## ⚡ Phase 3: Refactor Providers (Optimistic Updates)

### 🔴 Problem Definition
Providers like `WalletProvider` are reading raw map data and force-casting it to update the UI optimistically, which can freeze the UI if data types mismatch.

### 🟢 Architectural Solution
Use `NumberParser` to extract values safely before updating the state.

### 📋 Implementation Tasks
- [ ] Navigate to `lib/providers/wallet_provider.dart`. In `updateWalletOptimistically`, replace `final amount = (data['amount'] as num).toDouble();` with `final amount = NumberParser.toDouble(data['amount']);`.
- [ ] Navigate to `lib/providers/statistics_provider.dart`. In `addTransactionOptimistically`, replace `((txData['amount'] ?? 0.0) as num).toDouble();` with `NumberParser.toDouble(txData['amount']);`.
- [ ] Do the same for `commission` in `addTransactionOptimistically`.

### 🔍 Verification Gates (Phase 3)
- [ ] **Final Global Search:** Search the entire `lib/` folder for `.toDouble()`. Verify it is no longer being called directly on `( ... as num)` expressions.
- [ ] **Final Global Compile:** Run `flutter analyze`. The terminal MUST output `0 issues found`.