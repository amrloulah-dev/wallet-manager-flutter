# Data Model: Master Architecture Refactor (002)

**Feature:** 002-master-arch-refactor
**Date:** 2026-04-14

---

## Entity Changes

### 1. Employee Model (MODIFY)
**File:** `lib/data/models/employee_model.dart`

| Field            | Type      | Change  | Description                                                      |
| ---------------- | --------- | ------- | ---------------------------------------------------------------- |
| `firebaseUid`   | `String?` | **ADD** | UID from secondary Firebase Auth context. Nullable for migration. |

**Serialization:**
- `toFirestore()`: Include `firebaseUid` if non-null.
- `fromFirestore()`: Read `firebaseUid` from document, default `null`.

**Validation:**
- Must be non-empty string when present.
- Once set, should not be overwritten unless explicitly re-provisioned.

---

### 2. AppErrorEvent (NEW)
**File:** `lib/core/errors/app_error_event.dart`

| Field            | Type                | Description                                    |
| ---------------- | ------------------- | ---------------------------------------------- |
| `severity`       | `ErrorSeverity`     | Enum: `low`, `medium`, `critical`              |
| `message`        | `String`            | User-facing Arabic error message               |
| `operation`      | `String`            | Context: what the user was doing               |
| `error`          | `Object`            | Original error/exception                       |
| `stackTrace`     | `StackTrace?`       | Dart stack trace for diagnostics               |
| `timestamp`      | `DateTime`          | When the error occurred                        |

**Enum:** `ErrorSeverity`
```dart
enum ErrorSeverity { low, medium, critical }
```

---

### 3. Service Locator Registry (NEW)
**File:** `lib/core/di/service_locator.dart`

Not a data model per se, but a singleton registration map. Entities registered:

| Registration Key              | Implementation Class         | Lifecycle       |
| ----------------------------- | ---------------------------- | --------------- |
| `AuthRepository`             | `AuthRepository`             | Lazy Singleton  |
| `WalletRepository`           | `WalletRepository`           | Lazy Singleton  |
| `TransactionRepository`      | `TransactionRepository`      | Lazy Singleton  |
| `DebtRepository`             | `DebtRepository`             | Lazy Singleton  |
| `EmployeeRepository`         | `EmployeeRepository`         | Lazy Singleton  |
| `StoreRepository`            | `StoreRepository`            | Lazy Singleton  |
| `StatsRepository`            | `StatsRepository`            | Lazy Singleton  |
| `SubscriptionRepository`     | `SubscriptionRepository`     | Lazy Singleton  |
| `SystemConfigRepository`     | `SystemConfigRepository`     | Lazy Singleton  |
| `DeviceRepository`           | `DeviceRepository`           | Lazy Singleton  |
| `LicenseKeyRepository`       | `LicenseKeyRepository`       | Lazy Singleton  |
| `UserRepository`             | `UserRepository`             | Lazy Singleton  |

---

## Unchanged Entities

The following models are **not** modified by this refactor. They are listed for completeness:

- `WalletModel` — no field changes
- `TransactionModel` — no field changes
- `DebtModel` — no field changes
- `StoreModel` — no field changes
- `UserModel` — no field changes (already has `firebaseUid`)
- `StoreSubscription` — no field changes

---

## State Transitions

### Virtual Identity Provisioning State Machine

```
                ┌────────────────┐
                │  NO_IDENTITY   │  (firebaseUid == null)
                └───────┬────────┘
                        │ Employee Created
                        ▼
               ┌─────────────────┐
               │  PROVISIONING   │  (async Firebase Auth call)
               └────┬───────┬────┘
            Success │       │ Failure
                    ▼       ▼
        ┌───────────┐   ┌──────────────────┐
        │ PROVISIONED│   │ PROVISION_FAILED │  (firebaseUid still null)
        │ (uid set) │   │ (retry on login) │
        └───────────┘   └──────────────────┘
```

### Error Severity Routing

```
  Error Caught
       │
       ▼
  ┌─────────────────┐
  │ AppErrorHandler  │
  │   .handle()     │
  └──┬───┬───┬──────┘
     │   │   │
     ▼   ▼   ▼
   Low  Med  Critical
    │    │     │
    ▼    ▼     ▼
  Toast Banner Dialog
```
