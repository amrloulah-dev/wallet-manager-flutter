# Implementation Plan: InstaPay Limit Force-Bypass

## Phase 1: Domain Layer — Custom Exception & Model Extension

- [x] c0603c0 Task: Create `InstaPayLimitWarningException` in app_exceptions.dart
    - [x] Write a unit test that asserts `InstaPayLimitWarningException` extends `AppException`, has default message `instapay_limit_warning`, and can be caught distinctly from `ValidationException`.
    - [x] Implement `InstaPayLimitWarningException` class extending `AppException` with default message `instapay_limit_warning`.
    - [x] Run tests and confirm they pass.

- [x] 5fb427a Task: Add `bypassedLimit` field to `TransactionModel`
    - [x] Write unit tests for `TransactionModel` verifying: (a) constructor defaults `bypassedLimit` to `false`, (b) `fromMap` parses `bypassedLimit` from Firestore data (true/false/absent), (c) `toFirestore()` includes `bypassedLimit` in output, (d) `copyWith` correctly copies/overrides `bypassedLimit`, (e) `==` and `hashCode` incorporate `bypassedLimit`.
    - [x] Add `final bool bypassedLimit` field to `TransactionModel` class with default `false`.
    - [x] Update `fromMap`, `toFirestore`, `copyWith`, `==`, and `hashCode` to include `bypassedLimit`.
    - [x] Run tests and confirm they pass.

- [ ] Task: Conductor - User Manual Verification 'Phase 1: Domain Layer' (Protocol in workflow.md)

## Phase 2: Provider Layer — Limit Interception Logic

- [ ] Task: Add `forceInstaPayBypass` parameter and soft-block logic to `createTransaction`
    - [ ] Write unit tests covering all 6 limit-check scenarios:
        - (a) Non-InstaPay wallet + Daily/Monthly limit exceeded → `ValidationException` thrown, returns `false`.
        - (b) InstaPay wallet + Daily/Monthly limit exceeded + `forceInstaPayBypass: false` → `InstaPayLimitWarningException` is re-thrown (propagates to caller).
        - (c) InstaPay wallet + Daily/Monthly limit exceeded + `forceInstaPayBypass: true` → limit check skipped, transaction succeeds, `bypassedLimit: true` on the created model.
        - (d) InstaPay wallet + Max Per Transaction exceeded → `ValidationException` thrown (hard block, no bypass allowed).
        - (e) InstaPay wallet + within all limits + `forceInstaPayBypass: false` → normal success, `bypassedLimit: false`.
        - (f) Non-InstaPay wallet + Max Per Transaction exceeded → `ValidationException` (existing behavior unchanged).
    - [ ] Add `bool forceInstaPayBypass = false` named parameter to `createTransaction`.
    - [ ] Inject InstaPay-specific conditional logic into the Daily and Monthly limit check blocks:
        - For each Daily/Monthly limit check: if exceeded AND `isInstaPay` AND `!forceInstaPayBypass` → throw `InstaPayLimitWarningException()`.
        - For each Daily/Monthly limit check: if exceeded AND `isInstaPay` AND `forceInstaPayBypass` → skip the throw (proceed).
        - Non-InstaPay limit checks remain unchanged.
    - [ ] Add a dedicated `on InstaPayLimitWarningException` catch block in the try-catch chain that performs NO rollback (exception fires pre-mutation) and RE-THROWS the exception so it propagates to the UI.
    - [ ] When `forceInstaPayBypass == true`, pass `bypassedLimit: true` to the `TransactionModel` constructor.
    - [ ] Run tests and confirm all 6 scenarios pass.

- [ ] Task: Conductor - User Manual Verification 'Phase 2: Provider Layer' (Protocol in workflow.md)

## Phase 3: UI Layer — Exception Handling & Warning Dialog

- [ ] Task: Add `InstaPayLimitWarningException` catch block and warning dialog to `_handleCreate`
    - [ ] Write a widget test for `CreateTransactionScreen` that simulates `createTransaction` throwing `InstaPayLimitWarningException` and verifies the warning dialog appears with the correct Arabic title/message and two buttons.
    - [ ] In `_handleCreate()`, add `on InstaPayLimitWarningException catch (e)` block BEFORE the existing generic `catch (e, stack)`.
    - [ ] Inside the catch block, show `AwesomeDialog` with:
        - `dialogType: DialogType.warning`
        - `title: 'تنبيه تجاوز الحدود'`
        - `desc: 'لقد تجاوزت حدود إنستاباي المسموحة. هل قمت بتنفيذ هذه العملية من تطبيق البنك البديلي وتريد تسجيلها'`
        - `btnCancelText: 'إلغاء'` → dismiss dialog
        - `btnOkText: 'تسجيل العملية'` → re-invoke `createTransaction` with `forceInstaPayBypass: true`
    - [ ] Ensure loading state is properly managed: reset on dialog dismiss, re-engaged on confirm-retry.
    - [ ] Run tests and confirm they pass.

- [ ] Task: Conductor - User Manual Verification 'Phase 3: UI Layer' (Protocol in workflow.md)
