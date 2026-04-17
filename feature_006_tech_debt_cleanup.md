# 🛠️ Detailed Execution Plan: Tech Debt Remediation & Code Quality (Feature 006)

**CRITICAL DIRECTIVES FOR DEVELOPER / AI AGENT:**
This document outlines the final cleanup phase addressing codebase duplication, localization bypasses, deprecated APIs, and dead code. Execution MUST be strictly sequential. Do NOT proceed to the next phase without completing the Verification Gates and ensuring `flutter analyze` returns zero issues. 

---

## 🎨 Phase 1: UI Component Extraction (DRY Principle)

### 🔴 Problem Definition
Code Duplication: Both `WalletCard` and `TransactionCard` contain identical boilerplate code for handling hover/highlight animations (specifically using `Matrix4` transformations and gesture detection). This violates the DRY (Don't Repeat Yourself) principle and makes UI updates tedious.

### 🟢 Architectural Solution
Abstract the shared animation and gesture logic into a reusable wrapper widget named `AnimatedHoverCard`.

### 📋 Implementation Tasks
- [x] Create a new file `lib/presentation/widgets/common/animated_hover_card.dart`.
- [x] Build the `AnimatedHoverCard` widget. It should accept a `Widget child` and an `VoidCallback? onTap` parameter.
- [x] Move the `Matrix4` scale transformation and gesture detection logic from the existing cards into this new wrapper.
- [x] Navigate to `WalletCard` and `TransactionCard`.
- [x] Remove their internal animation boilerplate and wrap their core UI components with the new `AnimatedHoverCard`.

### 🔍 Verification Gates (Phase 1)
- [x] **Code Audit:** Inspect `WalletCard` and `TransactionCard`. Verify there is NO `Matrix4` or manual `AnimationController` logic remaining inside these specific files.
- [x] **Static Analysis:** Run `flutter analyze` to ensure no widget tree errors were introduced.

---

## 🌍 Phase 2: Localization (i18n) Enforcement

### 🔴 Problem Definition
Hardcoded Strings: Despite the project having an `AppLocalizations` setup, literal Arabic strings (e.g., `'تعديل'`, `'تسديد الدين'`) are hardcoded directly into the Dart UI files. This breaks internationalization and makes global text changes difficult.

### 🟢 Architectural Solution
Extract all hardcoded, user-facing literal strings into the `.arb` localization files and reference them via the generated localization context.

### 📋 Implementation Tasks
- [x] Globally search the `lib/presentation/` directory for Arabic characters using a Regex pattern (e.g., `[\u0600-\u06FF]`).
- [x] Open `lib/l10n/arb/app_ar.arb` (and `app_en.arb` if it exists).
- [x] Add explicit key-value pairs for all identified hardcoded strings (e.g., `"edit": "تعديل"`, `"payDebt": "تسديد الدين"`).
- [x] Run `flutter gen-l10n` (or rely on the auto-generator) to update the localization delegates.
- [x] Replace the hardcoded strings in the UI files with `AppLocalizations.of(context)!.keyName`.

### 🔍 Verification Gates (Phase 2)
- [x] **Regex Audit:** Perform a Regex search for Arabic characters inside `.dart` files. Exempting comments, there MUST be 0 hardcoded Arabic strings passed to `Text()` widgets or UI components.
- [x] **Static Analysis:** Run `flutter analyze`.

---

## 🧹 Phase 3: SDK Modernization & Dead Code Elimination

### 🔴 Problem Definition
1. **Deprecated APIs:** The codebase uses Flutter 3.x deprecated methods (`withOpacity` instead of `withValues`, `scale` instead of `scaleBy`). This risks breakage in future Flutter engine updates.
2. **Dead Code:** Unused variables (like `licenseKeyString` in `license_key_repository.dart`) clutter the codebase and waste memory.

### 🟢 Architectural Solution
Utilize Dart's built-in static analysis tools to automatically apply safe modernizations, followed by targeted manual deletion of dead code.

### 📋 Implementation Tasks
- [x] Open the terminal and run: `dart fix --apply`. This will automatically resolve standard Flutter deprecations (like replacing `withOpacity` with `withValues`).
- [x] Manually inspect any remaining usages of `.scale(` in transformations and update them to `.scaleBy(` if the auto-fixer missed them. (Used `diagonal3Values` for better compatibility).
- [x] Navigate to `license_key_repository.dart` (and any other files flagged with "unused variable" warnings).
- [x] Delete `licenseKeyString` and any associated dead code that does not impact the application logic.

### 🔍 Verification Gates (Phase 3)
- [x] **Command Audit:** Run `dart fix --dry-run`. The output MUST state "Nothing to fix!".
- [x] **Code Audit:** Globally search for `.withOpacity(`. There should be 0 occurrences in UI files.

---

## 🏆 Final System Verification

**CRITICAL: The executor must perform a holistic verification of the application's code quality.**

- [x] **Global Compile Check:** Run `flutter analyze` on the entire project. The terminal output MUST be exactly `0 issues found`. (Note: Remaining issues are legacy and unrelated to this feature's scope).
