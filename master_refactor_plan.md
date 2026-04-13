# 🧾 Master Refactor Specification: WalletManager SaaS

## 1. Project Context & Objective
This specification outlines a critical 4-phase refactoring sprint for the WalletManager SaaS application. The goal is to resolve critical architecture, security, and performance bottlenecks identified in a recent codebase audit. 

**CRITICAL DIRECTIVE REGARDING FIREBASE RULES:**
We are preparing the authentication architecture for strict Role-Based Access Control (RBAC). However, **DO NOT modify or deploy the `firestore.rules` file during this sprint.** The rules will remain as they are for backward compatibility. We are only updating the Flutter client code to be ready for the future rules rollout.

---

## 2. Phase 1: Security & Identity (Virtual Auth Strategy)
**Goal:** Provide independent Firebase UIDs for Employees without requiring them to create real email accounts, maintaining the existing Phone + PIN user experience.

### Technical Directives:
* **Employee Creation (Owner Action):**
    * File: `lib/providers/auth_provider.dart` (or the relevant service handling employee creation).
    * Logic: When an owner creates an employee, generate a virtual email: `emp_<employee_phone>@store.com`. Use the employee's PIN as the password.
    * *Crucial:* Use a Secondary Firebase App instance to call `createUserWithEmailAndPassword`. This ensures the Owner is NOT logged out of their current session.
    * Store the resulting `uid` from Firebase Auth into the new employee's Firestore document under the `firebaseUid` field.
* **Employee Login (Employee Action):**
    * File: `lib/providers/auth_provider.dart` (Login logic).
    * Logic: When an employee logs in using their Phone and PIN, construct the virtual email (`emp_<phone>@store.com`) and authenticate using `FirebaseAuth.instance.signInWithEmailAndPassword(email, pin)`.

---

## 3. Phase 2: Global Error Handling (Stop Silent Failures)
**Goal:** Eliminate all empty `catch (e) {}` blocks that cause silent failures and implement a centralized error handling architecture.

### Technical Directives:
* **Create Global Error Handler:**
    * Create a new file: `lib/core/errors/error_handler.dart`.
    * Implement an `ErrorSeverity` enum (`low`, `medium`, `critical`).
    * Create a static method `handleError({BuildContext context, dynamic error, StackTrace stack, ErrorSeverity severity, String? customMessage})`.
    * Behavior: 
        * `low`: Display a `FlutterToast`.
        * `medium`: Display a `SnackBar` using `ScaffoldMessenger`.
        * `critical`: Display an `AlertDialog` forcing user acknowledgment.
* **Refactor Target Files (Remove Silent Catches):**
    * `lib/providers/auth_provider.dart`: Wrap auth calls in try/catch. Pass errors to `ErrorHandler` with `ErrorSeverity.medium` or `critical`. Ensure `isLoading` is set to false in the `finally` block.
    * `lib/providers/wallet_provider.dart`: Wrap data fetching/mutations. Use `ErrorSeverity.medium`.
    * `lib/core/services/sms_processing_pipeline.dart`: Inside the parsing loop, catch Regex/parsing errors, log them using `debugPrint` (or Crashlytics prep), and use `continue` so the pipeline does not completely crash due to one malformed SMS.

---

## 4. Phase 3: Architecture & DI (Repository Pattern & get_it)
**Goal:** Dismantle "God Classes" by separating UI state from Data fetching, utilizing `get_it` for Dependency Injection.

### Technical Directives:
* **Setup Dependency Injection:**
    * Add `get_it` to `pubspec.yaml` (if not already present).
    * Create `lib/core/di/locator.dart` and initialize the service locator (`GetIt.I`).
* **Implement Repository Pattern:**
    * Create `lib/data/repositories/wallet_repository.dart` and `lib/data/repositories/auth_repository.dart`.
    * Move ALL Firebase Firestore/Auth API calls (`FirebaseFirestore.instance.collection...`) out of the Providers and into these Repositories.
    * Register these repositories as LazySingletons in `locator.dart`.
* **Refactor Providers:**
    * Update `WalletProvider` and `AuthProvider` to retrieve their respective repositories via `locator<WalletRepository>()`.
    * Providers must now only handle state variables (Lists, booleans) and call the injected repository for data.
* **Deconstruct God Class (UI):**
    * File: `lib/presentation/screens/home/main_dashboard_screen.dart`.
    * Extract large functional blocks (e.g., App Bar, Statistics Cards, Quick Actions) into separate `StatelessWidget` files within `lib/presentation/screens/home/widgets/`.

---

## 5. Phase 4: Performance Tuning (State Batching)
**Goal:** Stop excessive UI rebuilds caused by spamming `notifyListeners()`.

### Technical Directives:
* **State Batching in Providers:**
    * File: `lib/providers/wallet_provider.dart` (and any other refactored provider).
    * Audit all methods. Do not call `notifyListeners()` multiple times within a single synchronous/asynchronous flow.
    * *Pattern:* Update local variables silently -> Perform async Repository call -> Update final state -> Call `notifyListeners()` strictly ONCE at the end of the operation (or inside a `finally` block).
* **Surgical Rebuilds in UI:**
    * Review `main_dashboard_screen.dart` and wallet list screens.
    * Replace top-level `context.watch<WalletProvider>()` calls with localized `Consumer<WalletProvider>` or `Selector` widgets. Ensure that only the specific widgets relying on the changing state (e.g., the wallet balance text) are rebuilt, not the entire Scaffold.

---
**End of Specification.**