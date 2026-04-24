# Specification: Architectural Refactoring & Domain-Driven Design (Phase 1)

## Overview
This track executes Phase 1 of the Master Execution Plan for Architectural Refactoring & Domain-Driven Design. The goal is to eliminate code duplication (DRY) and centralize global state access by introducing a `BaseProvider` and refactoring all existing providers to use it. Additionally, core Firebase services will be registered for dependency injection.

## Functional Requirements
- **BaseProvider Creation:**
  - Create an abstract `BaseProvider` extending `ChangeNotifier` in `lib/providers/base_provider.dart`.
  - Implement a `_isDisposed` flag (overriding `dispose()` to set it true).
  - Implement a `safeNotify()` method that checks `!_isDisposed && hasListeners` before calling `notifyListeners()`.
  - Implement a `setError(String errorCode, [dynamic error, StackTrace? stack])` method for centralized error logging.
- **Global Provider Cleanup:**
  - Refactor all existing providers to extend `BaseProvider`.
  - Remove all localized `_safeNotify` and `_setError` methods from these providers.
- **Firebase DI Registration:**
  - Register `FirebaseFirestore.instance` and `FirebaseAuth.instance` as singletons via `GetIt` in `lib/core/di/service_locator.dart`.

## Non-Functional Requirements
- The refactor must not modify the presentation (UI) layer.
- All dependencies must flow inward toward the Domain layer.
- The solution must ensure zero SDK leakage in later layers.

## Acceptance Criteria
- `flutter analyze` returns zero errors.
- `BaseProvider` is implemented with `safeNotify` and `setError`.
- All existing providers in `lib/providers/` extend `BaseProvider` and use its centralized methods.
- There is only one definition of `safeNotify` across the entire project (`BaseProvider`).
- New unit tests are implemented specifically for `BaseProvider` and its global state management functionality.

## Out of Scope
- UI modifications.
- Implementing Domain Layer interfaces (Phase 2).
- Data Layer refactor for Firebase SDK decoupling (Phase 3).
- Logic decomposition of the God Class (Phase 4).