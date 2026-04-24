# Specification: Wave 2: Presentation Layer & State Bloat Purge

## Overview
This track executes Wave 2 of the architectural refactoring to purge business logic from the UI layer and decompose remaining God Classes. This covers Micro-Missions 5 through 8.

## Global Constraints
- **ZERO ERROR SUPPRESSION:** Never add `# ignore` rules. Fix root causes (e.g., `if (!context.mounted) return;`).
- **STRICT CLEAN ARCHITECTURE:** `lib/presentation/` and `lib/providers/` MUST NEVER import `cloud_firestore` or `firebase_auth`.
- **MANDATORY DEPENDENCY INJECTION:** Never use `FirebaseAuth.instance` or similar. Use `sl<Type>()`.
- **NO HARDCODED STRINGS:** Return error codes (e.g., `'wallet_fetch_error'`) from logic, map to localized strings in UI.
- **LOCAL STATE OVER GLOBAL BLOAT:** Use `StatefulWidget` for minor ephemeral UI state.
- **DO NOT TOUCH UNRELATED FILES:** Execute surgically.

## Functional Requirements
- **Mission 5: store_registration_screen.dart**
  - Delete direct `FirebaseAuth.instance.currentUser` calls.
  - Replace with `AuthProvider` state access.
  - Remove `package:firebase_auth/firebase_auth.dart` imports.
- **Mission 6: create_transaction_screen.dart**
  - Extract fee calculations and validations into a Domain Use Case `TransactionFeeCalculator` registered via GetIt.
  - Remove raw logic from `onPressed` handlers or `build` methods.
- **Mission 7: settings_screen.dart**
  - Decompose into smaller stateful widgets managing minor local UI states (e.g., `profile_section.dart`, `theme_settings_section.dart`).
  - Move widgets to `lib/presentation/screens/settings/widgets/`.
  - Reduce `settings_screen.dart` to < 200 lines.
- **Mission 8: wallet_provider.dart**
  - Extract caching logic into a dedicated Cache Manager / Local Storage extension.
  - Extract formatting to a utility or model extension.
  - Ensure `WalletProvider` strictly handles state (`_wallets`, `_isLoading`, etc.).

## Non-Functional Requirements
- The refactor must not modify unrelated files.
- No `# ignore` rules should be introduced.
- Maintain existing tests and ensure no regressions.

## Acceptance Criteria
- `store_registration_screen.dart` has no Firebase Auth imports.
- `TransactionFeeCalculator` handles all transaction fee logic.
- `settings_screen.dart` is under 200 lines.
- `wallet_provider.dart` delegates caching and formatting.
- `flutter analyze` returns zero errors.

## Out of Scope
- Adding new features.
- Major UI redesigns.