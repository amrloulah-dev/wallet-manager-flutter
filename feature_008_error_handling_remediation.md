# 🛠️ Detailed Execution Plan: Context-Aware Error Handling (Feature 008)

**CRITICAL DIRECTIVES FOR DEVELOPER / AI AGENT:**
This document outlines the remediation for the "Silent Error Swallowing" anti-pattern found across the codebase. You will replace blind `try-catch` blocks with context-aware, resilient logic.
1. Execution MUST be strictly sequential.
2. Do NOT proceed to the next phase without completing the Verification Gates.
3. NEVER leave an empty `catch` block in the codebase.

---

## 📱 Phase 1: SMS Parser Resilience (Financial Data Protection)

### 🔴 Problem Definition
In `vodafone_cash_strategy.dart` and `generic_bank_strategy.dart`, the code uses `double.parse(amountStr)` wrapped in an empty catch. If the SMS format changes slightly (e.g., "1,000" instead of "1000"), the parsing fails silently, and the transaction is permanently lost.

### 🟢 Architectural Solution
Replace strict parsing with safe parsing (`double.tryParse`) combined with string sanitization. Log unparsed messages internally instead of ignoring them.

### 📋 Implementation Tasks
- [ ] Navigate to `lib/core/sms_automation/strategies/vodafone_cash_strategy.dart` and `generic_bank_strategy.dart`.
- [ ] Locate the `parse` methods where `double.parse(amountStr)` is used.
- [ ] Remove the `try { ... } catch (_) {}` blocks completely.
- [ ] Implement sanitization: `final sanitizedAmountStr = amountStr.replaceAll(',', '').replaceAll(' ', '');`
- [ ] Use safe parsing: `final amount = double.tryParse(sanitizedAmountStr);`
- [ ] Add a conditional check: 
      ```dart
      if (amount == null) {
        // Pass to AppErrorHandler or logging service for developer review
        AppErrorHandler.logSilentError('SMS Parse Failure', 'Failed to parse amount: $amountStr from SMS');
        return null; // Skip this transaction gracefully
      }
      ```
- [ ] Repeat this logic for both the 'Send' and 'Receive' blocks in both strategy files.

### 🔍 Verification Gates (Phase 1)
- [ ] **Code Audit:** Search both strategy files. There MUST be exactly 0 occurrences of `double.parse(` and exactly 0 occurrences of `catch (_)`.

---

## ⚙️ Phase 2: SIM Configuration Safe Access

### 🔴 Problem Definition
In `lib/presentation/screens/settings/settings_screen.dart`, the code uses `mappings.firstWhere(...)` inside an empty catch to find SIM slots. If a slot is missing, it silently fails, leaving variables null and potentially causing downstream UI bugs.

### 🟢 Architectural Solution
Replace exception-driven logic with null-safe iterative lookup (`firstWhere` with `orElse` or `collection` package's `firstOrNull`).

### 📋 Implementation Tasks
- [ ] Navigate to `lib/presentation/screens/settings/settings_screen.dart` and locate the `_loadState` method.
- [ ] Remove the `try { ... } catch (_) {}` blocks around the `sim1` and `sim2` assignments.
- [ ] Replace with null-safe logic:
      ```dart
      sim1 = mappings.where((m) => m.simSlotIndex == 0).firstOrNull; // Requires Dart 3+ or collection package
      // OR fallback:
      // sim1 = mappings.cast<SimWalletConfig?>().firstWhere((m) => m?.simSlotIndex == 0, orElse: () => null);
      ```
- [ ] Ensure the UI layer explicitly handles the `null` state by showing a message like "No SIM card detected in this slot" instead of rendering a broken layout.

### 🔍 Verification Gates (Phase 2)
- [ ] **Code Audit:** Verify `firstWhere` without `orElse` is NO LONGER used for SIM mapping. Verify the `catch` blocks are deleted.

---

## 🧩 Phase 3: Dashboard Dependency Injection Validation

### 🔴 Problem Definition
In `lib/presentation/screens/home/main_dashboard_screen.dart`, `_checkPaymentSuccessModal` attempts to read `SubscriptionProvider` inside an empty catch. Missing a provider is a critical developer error that should never be silenced.

### 🟢 Architectural Solution
Remove the empty catch block. If the provider is structurally missing, the app *should* throw an exception during development so it can be fixed.

### 📋 Implementation Tasks
- [ ] Navigate to `lib/presentation/screens/home/main_dashboard_screen.dart` and locate `_checkPaymentSuccessModal`.
- [ ] Remove the `try { ... } catch (_) { ... }` wrapper entirely.
- [ ] Leave the invocation: `final subProvider = context.read<SubscriptionProvider>();` 
- [ ] *Note: If this provider is intentionally optional, it must be declared as nullable `context.read<SubscriptionProvider?>()` instead of swallowing the exception.*

### 🔍 Verification Gates (Phase 3)
- [ ] **Code Audit:** Inspect `_checkPaymentSuccessModal`. Verify the empty `catch` block is completely removed.
- [ ] **Final Global Compile:** Run `flutter analyze`. The terminal MUST output `0 issues found`.