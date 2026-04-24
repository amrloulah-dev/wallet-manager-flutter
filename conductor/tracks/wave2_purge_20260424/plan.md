# Implementation Plan: Wave 2: Presentation Layer & State Bloat Purge

## Global Constraints
- **ZERO ERROR SUPPRESSION:** Never add `# ignore` rules. Fix root causes (e.g., `if (!context.mounted) return;`).
- **STRICT CLEAN ARCHITECTURE:** `lib/presentation/` and `lib/providers/` MUST NEVER import `cloud_firestore` or `firebase_auth`.
- **MANDATORY DEPENDENCY INJECTION:** Never use `FirebaseAuth.instance` or similar. Use `sl<Type>()`.
- **NO HARDCODED STRINGS:** Return error codes (e.g., `'wallet_fetch_error'`) from logic, map to localized strings in UI.
- **LOCAL STATE OVER GLOBAL BLOAT:** Use `StatefulWidget` for minor ephemeral UI state.
- **DO NOT TOUCH UNRELATED FILES:** Execute surgically.

## Phase 1: Purging UI Firebase Leaks [checkpoint: 928e809]
- [x] Task: Refactor `lib/presentation/screens/auth/store_registration_screen.dart`
    - [x] Delete direct `FirebaseAuth.instance.currentUser` calls.
    - [x] Replace with `context.read<AuthProvider>().currentUser`.
    - [x] Remove `package:firebase_auth/firebase_auth.dart` imports.
- [x] Task: Conductor - User Manual Verification 'Purging UI Firebase Leaks' (Protocol in workflow.md)

## Phase 2: UI Logic Extraction [checkpoint: 3fb96b0]
- [x] Task: Extract Logic to Domain
    - [x] Create `lib/domain/usecases/transaction_fee_calculator.dart`.
    - [x] Move fee calculation and validations to `TransactionFeeCalculator`.
    - [x] Register `TransactionFeeCalculator` in `lib/core/di/service_locator.dart`.
- [x] Task: Refactor UI
    - [x] Refactor `lib/presentation/screens/transactions/create_transaction_screen.dart` to inject and use `TransactionFeeCalculator`.
    - [x] Ensure no raw math/fee logic remains in `onPressed` handlers or `build` methods.
- [x] Task: Conductor - User Manual Verification 'UI Logic Extraction' (Protocol in workflow.md)

## Phase 3: Widget Decomposition [checkpoint: bc3a236]
- [x] Task: Decompose Settings Screen [d9f7767]
    - [x] Create directory `lib/presentation/screens/settings/widgets/`.
    - [x] Extract logical sections from `lib/presentation/screens/settings/settings_screen.dart` into separate files in `widgets/` (using StatefulWidget for local state).
    - [x] Replace extracted code in `settings_screen.dart` with widget references.
    - [x] Verify `settings_screen.dart` is under 200 lines.
- [x] Task: Conductor - User Manual Verification 'Widget Decomposition' (Protocol in workflow.md) [bc3a236]

## Phase 4: Taming the Final God Class
- [x] Task: Extract Logic from WalletProvider [08a5ee0]
    - [x] Extract caching logic from `lib/providers/wallet_provider.dart` into `WalletCacheManager`.
    - [x] Extract formatting logic into `lib/core/utils/currency_formatter.dart` or `WalletModel` extension.
    - [x] Refactor `wallet_provider.dart` to only manage state and call repositories/usecases.
- [ ] Task: Conductor - User Manual Verification 'Taming the Final God Class' (Protocol in workflow.md)