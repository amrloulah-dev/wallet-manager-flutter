# 🛡️ Report 5: Architectural Decisions & Edge Cases (ADR)

## 1. Core Architectural Decisions

### Separation of `daily_stats` vs `stats/summary`
In the initial architecture, all statistics (e.g., total transactions, commissions, daily limits) were likely stored in a single root-level `StoreStats` object on the `stores/{storeId}` document. 
*   **The Risk:** High-volume stores processing multiple transactions per minute would hit Firestore's strict 1 write/sec limit per document, causing write failures. Furthermore, fetching the store document for simple subscription checks would pull down massive, constantly mutating statistical data, increasing payload sizes and billing costs.
*   **The Solution:** The system was refactored to separate concerns. `StatsRepository` now manages two distinct entities:
    1.  `statsSummary`: A root-level summary for point-in-time aggregations (e.g., `openDebtsCount`, `totalOpenAmount`).
    2.  `daily_stats`: Time-bucketed documents (`daily_stats/{yyyy-MM-dd}`) capturing flow metrics. This allows historical range queries (via `getStatsByDateRange`) without touching the root store document, entirely bypassing the 1 write/sec bottleneck.

### Retiring & Purging Legacy Fields
*   **The Problem:** Legacy fields like `totalServiceFee`, `*Today` accumulators, and license keys were cluttering the primary `StoreModel`. 
*   **The Solution:** A deliberate architectural decision was made to retire these fields from the root. Instead of crashing when parsing old documents, `StoreModel.fromFirestore` safely bundles unrecognized legacy keys into a `legacyData` map. High-churn stats were moved to `StoreStats` or isolated in `daily_stats`, significantly reducing the primary payload size and simplifying the logic.

## 2. Handled Edge Cases & Complex Workarounds

### Transaction Creator Attribution
*   **The Problem:** When creating a transaction, the system needs to record who created it (`createdByName`, `creatorRole`) for auditing. However, the active `UserModel` from Firebase Auth might not contain the localized "Employee Name" or specific granular role if the user is a Store Owner versus a restricted Cashier.
*   **The Solution:** In `TransactionProvider.createTransaction()`, an explicit fallback logic is implemented. It first queries the `EmployeeProvider` using the active `userId`. If a match is found, it uses the explicit `employee.fullName` and `employee.role.name`. If it fails (which implies the user is the Store Owner whose data isn't in the employee list), it gracefully falls back to `user.fullName` and `user.role.name`, completely preventing "Unknown" or null attributions in the ledger.

### Employee Creation & Optimistic UI Risk
*   **The Problem:** The app heavily utilizes Optimistic UI (mutating RAM before Firestore confirms) for snappy interactions. However, doing this for *Employee Creation* introduces a severe risk: if an employee is injected into the local list with a fake/temporary ID (e.g., UUID), and the user instantly clicks "Edit" or "Deactivate" before Firestore responds, the system will attempt to mutate a non-existent document, causing a hard crash.
*   **The Solution:** Optimistic UI is explicitly *bypassed* in `EmployeeProvider.addEmployee()`. The method strictly `await`s the `_employeeRepository.addEmployee` and `_employeeRepository.provisionIdentity` calls. Only after Firestore returns the canonical, real document ID does the provider execute `_employees.insert(0, newEmployee)` and `safeNotify()`. This entirely mitigates the race condition.

## 3. Backward Compatibility Strategies

### Safe Serialization of Legacy Documents
*   **The Problem:** As the data model evolves (e.g., adding `serviceFee` or changing `commission` structures), querying older Firestore documents that lack these keys would typically throw a null assertion exception during `fromMap` serialization, crashing the app.
*   **The Solution:** Strict enforcement of fallback operators. In `TransactionModel.fromMap`, the system utilizes a custom `NumberParser.toDouble(data['amount'])` utility which guarantees a `0.0` return if the field is missing, null, or corrupted. Similarly, legacy statuses use `.fromString(data['...'] ?? 'paid')` to default safely, ensuring backward compatibility without requiring massive, risky database migrations.

## 4. Data Integrity & Validation Constraints

### Strict Boundaries in Employee Limits
*   **The Problem:** Subscription tiers strictly limit the number of employees (e.g., Free tier allows 1, Pro allows 999). A boundary condition regression could allow a user to add an employee right on the limit (e.g., adding a 2nd employee on the Free tier).
*   **The Solution:** In `EmployeeProvider.addEmployee()`, the boundary constraint is enforced aggressively before any network calls occur: `!_subscriptionProvider!.canAddEmployee(employeesCount)`. By relying on `canAddEmployee` (which strictly evaluates `activeEmployees.length < maxEmployees`), the system prevents off-by-one errors and guarantees data integrity against subscription limits.
