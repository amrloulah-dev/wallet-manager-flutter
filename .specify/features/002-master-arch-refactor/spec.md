# Feature Specification: Master Architecture Refactor

**Feature ID:** 002
**Branch:** `feature/002-master-arch-refactor`
**Created:** 2026-04-14
**Status:** Draft
**Source Document:** [master_refactor_plan.md](file:///c:/src/walletmanager/master_refactor_plan.md)

---

## 1. Feature Overview

### Problem Statement

A recent codebase audit of the WalletManager application has uncovered critical security, reliability, maintainability, and performance bottlenecks that threaten the product's stability and future scalability:

1. **Employee Identity Gap:** Employees currently do not possess independent authenticated identities. They share the store owner's authentication session, which prevents per-user audit trails, blocks future Role-Based Access Control (RBAC), and creates a single point of failure for accountability in a financial application.

2. **Silent Failure Epidemic:** Error conditions throughout the application are silently swallowed, meaning users receive no feedback when operations fail. Transactions may appear to succeed when they haven't, leading to data inconsistencies and eroded user trust in a money-management tool.

3. **Monolithic Provider Architecture:** Core business logic classes have grown into "God Classes" that simultaneously manage UI state, data access, and business rules. This tight coupling makes the codebase fragile, difficult to test, and costly to extend with new features. The main dashboard screen is similarly bloated, creating a maintenance bottleneck.

4. **Excessive UI Rebuilds:** State change notifications trigger full-screen redraws instead of targeted component updates. On the mid-range Android devices used by store owners, this produces visible frame drops (jank), particularly on data-heavy screens like the wallet list and main dashboard.

### Proposed Solution

Execute a 4-phase refactoring sprint — **Security & Identity**, **Global Error Handling**, **Architecture & Dependency Injection**, and **Performance Tuning** — to systematically resolve each bottleneck. Each phase builds on the previous, producing a codebase that is secure, transparent, modular, and performant.

### Target Users

| User Role    | Description                                                                |
| ------------ | -------------------------------------------------------------------------- |
| Store Owner  | Primary user managing wallets, employees, and transactions                 |
| Employee     | Secondary user with limited access, granted by the Store Owner             |

---

## Clarifications

### Session 2026-04-14
- Q: How is cross-store uniqueness guaranteed for virtual employee identities when the same phone number exists at different stores? → A: Use store-scoped format `emp_<phone>_<storeId>@store.com` to guarantee uniqueness.
- Q: What happens to the virtual identity when an employee's PIN is changed? → A: The virtual identity's credential must be automatically updated to match the new PIN.
- Q: Phase 3 scope — repositories already exist in the codebase. What is the actual remaining work? → A: Introduce a DI registry for existing repositories and eliminate the few residual direct data calls still in providers.
- Q: What happens to the virtual identity when an employee is deleted? → A: The virtual identity must be deleted (best-effort). If cleanup fails, log the failure — do not block the employee deletion.
- Q: Should errors be logged for debugging beyond user-facing feedback? → A: Yes — structured local diagnostic logging (severity, context, stack trace) alongside user feedback. Remote crash reporting deferred to a future sprint.

---

## 2. User Stories

### US-01: Independent Employee Identity
**As a** Store Owner creating a new employee,
**I want** the system to automatically provision the employee with their own independent authenticated identity behind the scenes,
**So that** each employee has a unique, trackable session and the store is prepared for future per-user access control.

**Acceptance Criteria:**
- Creating an employee automatically generates a unique identity for that employee using their phone number and PIN — no additional setup required from the owner.
- The owner's own session is never interrupted or logged out during employee creation.
- The generated identity is stored as part of the employee's record and linked to their profile.
- The process is invisible to the Store Owner — no new screens, prompts, or confirmation steps beyond the existing employee creation flow.

### US-02: Employee Login with Own Identity
**As an** Employee logging into the app,
**I want** my phone number and PIN to authenticate me under my own identity,
**So that** my actions are trackable to me individually and I have a distinct session from other employees and the owner.

**Acceptance Criteria:**
- An employee logs in using their existing phone number and PIN — the experience is unchanged from today.
- Behind the scenes, the login resolves to the employee's own independent identity (not the owner's).
- The employee sees the same screens and functionality as before — no visible changes.
- Failed login attempts display a clear error message (not a silent failure).

### US-03: Visible Error Feedback on Failures
**As a** Store Owner or Employee performing any action (creating a wallet, adding a transaction, logging in, etc.),
**I want** the system to immediately inform me if something goes wrong,
**So that** I know my action failed and can take corrective steps instead of assuming success.

**Acceptance Criteria:**
- **Minor issues** (e.g., a recoverable network hiccup during a non-critical operation) display a brief, non-blocking notification message.
- **Moderate issues** (e.g., a failed transaction save, data sync error) display a prominent in-app banner that the user can acknowledge.
- **Critical issues** (e.g., authentication failure, complete data save failure) display a blocking dialog requiring the user to acknowledge before continuing.
- All error messages are in Arabic, following existing app language conventions.
- No operation silently fails — every error produces user-visible feedback appropriate to its severity.

### US-04: SMS Processing Resilience
**As the** system processing incoming SMS messages in the background,
**I want** a single malformed or unexpected SMS to be skipped gracefully without crashing the entire processing pipeline,
**So that** valid transactions from other SMS messages are still captured.

**Acceptance Criteria:**
- If one SMS cannot be parsed, the system logs the failure reason and continues processing the next SMS.
- Successfully parseable SMS messages before and after the malformed one are processed normally.
- No SMS processing halt occurs due to a single bad message.

### US-05: Modular, Testable Business Logic
**As a** developer (or AI agent) working on the codebase,
**I want** data access to be separated from UI state management,
**So that** I can test business rules independently, extend features without side effects, and understand the codebase quickly.

**Acceptance Criteria:**
- Data access operations are isolated from UI state classes.
- A centralized dependency registry provides access to shared services application-wide.
- No UI state class directly performs data storage or retrieval operations.
- The main dashboard screen is broken into focused, reusable visual components rather than a single monolithic file.

### US-06: Jank-Free Dashboard & Wallet Browsing
**As a** Store Owner scrolling through my wallets or viewing the dashboard,
**I want** the interface to remain smooth and responsive with no visible stuttering,
**So that** I can work efficiently without frustration on my device.

**Acceptance Criteria:**
- State changes (e.g., a balance update) only redraw the specific component that changed, not the entire screen.
- A single user action produces at most one state notification cycle — no redundant intermediate redraws.
- The dashboard and wallet list screens scroll at 60fps on a mid-range Android device with 30+ wallets loaded.
- Loading states are managed correctly — no flash of stale data followed by a jump to new data.

---

## 3. Functional Requirements

### FR-01: Virtual Employee Identity Provisioning
- When a Store Owner creates an employee, the system must automatically generate a unique virtual identity for that employee derived from their phone number, the store's unique identifier, and their PIN (format: `emp_<phone>_<storeId>@store.com` with PIN as credential).
- The identity generation must use an isolated authentication context so that the currently signed-in owner is never signed out or interrupted.
- The resulting unique identifier must be saved to the employee's record.
- If identity provisioning fails, the employee creation must still succeed with the failure logged, and the identity can be retried on the employee's first login.
- When an employee's PIN is changed, the system must automatically update the virtual identity's credential to match the new PIN. If the credential update fails, the PIN change must still succeed locally, and the credential sync must be retried on the employee's next login attempt.
- When an employee is deleted, the system must attempt to delete the corresponding virtual identity from the authentication system. If the identity deletion fails, the failure must be logged but must not block the employee record deletion.

### FR-02: Employee Authentication via Own Identity
- When an employee logs in with their phone number and PIN, the system must authenticate them against their own provisioned virtual identity — not the owner's credentials.
- The system must construct the identity lookup from the employee's phone number and the store's unique identifier automatically (format: `emp_<phone>_<storeId>@store.com`).
- Authentication failures must produce user-visible error messages (FR-04).

### FR-03: RBAC Preparedness (No Rules Deployment)
- All client-side identity changes must prepare the application for future Role-Based Access Control.
- The existing server-side security rules must NOT be modified or redeployed during this sprint — backward compatibility must be maintained.
- The unique identity stored on employee records must be compatible with future server-side ownership and permission checks.

### FR-04: Centralized Error Handling with Severity Tiers
- The application must implement a single, centralized error handling mechanism with three severity tiers:
  - **Low severity:** Brief, non-blocking toast notification.
  - **Medium severity:** Prominent in-app banner/bar notification that the user sees without dismissal required.
  - **Critical severity:** Blocking dialog that the user must acknowledge before proceeding.
- All error messages must be in Arabic.
- Every existing silent error catch (`catch` blocks that discard the error) must be replaced with a call to this centralized handler at the appropriate severity level.
- In addition to user-facing feedback, the centralized error handler must perform structured local diagnostic logging for every error: severity level, operation context (what the user was doing), error message, and stack trace. This prepares the codebase for future remote crash reporting integration without adding an external service dependency in this sprint.

### FR-05: Loading State Consistency
- All operations that involve backend communication must properly manage their loading state indicators.
- If an operation fails mid-way, the loading indicator must be cleared regardless of the error outcome — no stuck loading spinners.

### FR-06: SMS Pipeline Error Isolation
- The background SMS processing pipeline must handle parsing errors on individual messages without halting the entire pipeline.
- When a single SMS fails to parse, the system must log the error with diagnostic information and continue processing subsequent messages.
- Pipeline-level errors (e.g., the entire pipeline cannot start) must still be surfaced and halt processing.

### FR-07: Dependency Injection Registry & Residual Data Call Elimination
- All existing data access classes (repositories) must be registered in a centralized dependency injection registry instead of being directly instantiated at call sites.
- Consuming classes must receive their repository dependencies via the registry — no `new Repository()` or direct constructor calls.
- The few residual direct data storage/retrieval calls that still exist inside UI state management classes must be migrated to the appropriate existing repository.
- After this phase, no UI state class may directly perform any data storage or retrieval operation.

### FR-08: Dashboard Component Decomposition
- The main dashboard screen must be decomposed into smaller, focused visual components.
- Each component (e.g., app bar area, statistics section, quick actions area) must be an independent, reusable unit.
- The dashboard's main file must serve as a composition root that assembles these components.

### FR-09: State Notification Batching
- UI state management classes must call their notification mechanism at most once per user-triggered operation.
- Multiple state field updates within a single operation must be batched — update all fields first, then notify once.
- The notification call must occur after all state mutations are complete, including in error/cleanup paths.

### FR-10: Targeted UI Rebuilds
- Screens displaying dynamic data (dashboard, wallet list) must subscribe only to the specific data fields they display — not the entire state object.
- When a single data field changes (e.g., one wallet's balance), only the visual component displaying that field must rebuild — not the parent screen or sibling components.
- Top-level, screen-wide state subscriptions must be replaced with field-specific, component-scoped subscriptions.

---

## 4. User Scenarios & Testing

### Scenario 1: Employee Creation with Identity (Happy Path)
1. Store Owner navigates to Employee Management and taps "Add Employee."
2. Owner enters the employee's name, phone number, and PIN.
3. Owner submits the form.
4. The system creates the employee record **and** provisions a virtual identity in the background.
5. Owner sees the employee appear in the list immediately — no extra steps.
6. The employee record now contains a unique identity field.

### Scenario 2: Employee Creation — Identity Provisioning Fails
1. Store Owner creates an employee while the device has intermittent connectivity.
2. The employee record is created successfully (optimistic local update per Constitution Principle 1).
3. The virtual identity provisioning call fails due to network error.
4. The failure is logged; the employee record is saved without a unique identity field.
5. On the employee's first login attempt, the system retries provisioning.

### Scenario 3: Employee Login with Virtual Identity
1. Employee opens the app and enters their phone number and PIN.
2. The system constructs the virtual identity from the phone number.
3. Authentication succeeds against the employee's own identity.
4. The employee sees their authorized dashboard view.

### Scenario 4: Operation Failure with Error Feedback
1. Store Owner attempts to add a new wallet.
2. The wallet appears immediately in the UI (optimistic update).
3. The backend save fails due to a network error.
4. The optimistic update is rolled back (Constitution Principle 4).
5. A medium-severity Arabic error banner appears informing the owner the wallet could not be saved.
6. The owner can retry the operation.

### Scenario 5: Critical Authentication Error
1. Store Owner attempts to log in.
2. Authentication fails (wrong credentials or server error).
3. A critical-severity blocking dialog appears with an Arabic error message.
4. The owner must acknowledge the dialog before trying again.

### Scenario 6: Malformed SMS in Background Pipeline
1. Three SMS messages arrive while the app is processing in the background.
2. The first SMS parses correctly — a transaction is created.
3. The second SMS has an unexpected format — parsing fails.
4. The system logs the parsing failure for the second SMS and continues.
5. The third SMS parses correctly — another transaction is created.
6. Result: 2 of 3 transactions are captured; no pipeline crash.

### Scenario 7: Dashboard Partial Rebuild
1. Store Owner is viewing the main dashboard with statistics, quick actions, and wallet summary.
2. A wallet balance updates in the background (via SMS or sync).
3. Only the wallet balance component redraws — the statistics section, quick actions, and app bar do not rebuild.
4. The screen remains smooth with no visible stutter.

### Scenario 8: Employee PIN Change Syncs Virtual Identity
1. Store Owner changes an employee's PIN from "1234" to "5678".
2. The PIN is updated locally and in the employee record immediately.
3. The system automatically updates the virtual identity's credential to "5678" in the background.
4. The employee can now log in with the new PIN.
5. If the credential update fails (e.g., network error), the PIN change is still saved locally. On the employee's next login with "5678", the system detects the mismatch and re-syncs the credential.

### Scenario 9: Employee Deletion Cleans Up Virtual Identity
1. Store Owner deletes an employee from the employee management screen.
2. The employee record is removed immediately from the UI (optimistic update).
3. The system deletes the employee's virtual identity from the authentication system in the background.
4. If the identity deletion fails (e.g., network error), the failure is logged but the employee record deletion proceeds.
5. The deleted employee can no longer log in.

### Scenario 10: Bulk State Update Without Jank
1. Store Owner performs a pull-to-refresh on the wallet list.
2. The system fetches updated data for 30 wallets.
3. All 30 wallet objects are updated in memory.
4. A single state notification fires after all updates are committed.
5. The wallet list redraws once — not 30 times.

---

## 5. Key Entities

| Entity                | Description                                                                                  |
| --------------------- | -------------------------------------------------------------------------------------------- |
| Employee              | Extended with a unique virtual identity field for independent authentication                  |
| Error Event           | Classified by severity (low, medium, critical) and routed to the appropriate feedback channel |
| Data Access Service   | Isolated unit responsible for storage/retrieval of a single domain's data                    |
| Dependency Registry   | Centralized service locator providing application-wide access to shared services              |
| Dashboard Component   | Focused, reusable visual unit extracted from the monolithic dashboard screen                  |

---

## 6. Scope & Boundaries

### In Scope
- Phase 1: Virtual identity provisioning for employees (client-side only) using isolated authentication contexts.
- Phase 1: Employee login resolution via virtual identities.
- Phase 2: Centralized error handling with 3 severity tiers replacing all silent error catches.
- Phase 2: SMS pipeline error isolation for individual message failures.
- Phase 2: Loading state consistency across all async operations.
- Phase 3: Introduction of a centralized dependency injection registry for existing repositories.
- Phase 3: Elimination of residual direct data calls in UI state classes.
- Phase 3: Dashboard screen decomposition into reusable components.
- Phase 4: State notification batching (single notify per operation).
- Phase 4: Targeted UI rebuild migration (field-specific subscriptions on dashboard and wallet screens).

### Out of Scope
- Server-side security rules modification or deployment (explicitly excluded per project directive).
- Full RBAC implementation — this sprint only prepares the identity foundation.
- Server-side error monitoring or crash reporting infrastructure.
- Refactoring screens other than the main dashboard (can be addressed in future sprints).
- Performance profiling tooling or benchmarking infrastructure.
- Migration of the SMS overlay isolate's internal architecture (only its error handling is in scope).

---

## 7. Dependencies & Assumptions

### Dependencies
- Existing employee creation and login flows.
- Existing authentication infrastructure supporting isolated/secondary authentication contexts.
- Existing SMS background processing pipeline.
- Existing provider-based state management architecture.
- All 7 Project Constitution principles remain in full force and inform every implementation decision.

### Assumptions
- Employees will continue using phone number + PIN as their only credentials — no new credential types are introduced.
- The virtual identity format (`emp_<phone>_<storeId>@store.com`) guarantees uniqueness across stores by incorporating the store's unique identifier. Each employee phone number is unique within a store, and the store-scoped namespace eliminates cross-store collisions.
- The secondary authentication context capability exists and can create identities without logging out the current user.
- Silent catch blocks are the primary source of unreported errors — no other systemic error-suppression mechanisms exist.
- The existing SMS pipeline processes messages sequentially, so isolating individual failures with a `continue` pattern is sufficient.
- Dashboard decomposition targets the main dashboard screen only — other screens will be addressed in future refactoring sprints.
- The codebase currently uses a provider-based state management pattern that will be retained; only the data access layer is restructured.
- State notification batching and targeted rebuilds can be achieved without changing the state management framework.

---

## 8. Success Criteria

| #  | Criterion                                                                                             | Metric                              |
| -- | ----------------------------------------------------------------------------------------------------- | ----------------------------------- |
| 1  | Every employee created after the refactor has an independent, unique identity on record                | 100% of new employees               |
| 2  | Employee login authenticates via the employee's own identity, not the owner's session                  | 100% of employee logins             |
| 3  | Owner session is never interrupted during employee creation                                            | 0 owner logouts during provisioning |
| 4  | Zero silent error catches remain in the codebase                                                       | 0 silent catch blocks               |
| 5  | All user-facing errors display Arabic-language feedback appropriate to their severity                   | 100% of error paths tested          |
| 6  | A single malformed SMS does not halt processing of subsequent valid messages                            | 0 pipeline crashes from bad SMS     |
| 7  | No UI state class directly performs data storage or retrieval calls                                     | 0 direct data calls in state classes|
| 8  | The main dashboard file delegates to focused component files instead of a single monolithic build       | Dashboard decomposed into ≥ 4 components |
| 9  | Each state-changing operation fires at most 1 state notification                                       | Max 1 notification per operation    |
| 10 | Dashboard and wallet list achieve 60fps scrolling on a mid-range Android device with 30+ wallets       | 60fps, 0 visible jank               |

---

## 9. Execution Strategy

> **CRITICAL: Sequential 4-Phase Execution**

This refactor MUST be implemented strictly in phase order. Each phase addresses a different architectural layer, and later phases depend on the stability guarantees of earlier ones.

1. **Phase 1 — Security & Identity:** Implement virtual employee identities. This establishes the authentication foundation that all future RBAC and auditing will depend on.
2. **Phase 2 — Error Handling:** Implement centralized error handling and eliminate silent catches. This ensures that issues in subsequent phases (data access refactoring, performance tuning) are immediately visible rather than silently hidden.
3. **Phase 3 — Architecture & Dependency Injection:** Extract data access into dedicated services, set up dependency injection, and decompose the dashboard. This phase restructures the codebase for testability and modularity.
4. **Phase 4 — Performance Tuning:** Batch state notifications and implement targeted UI rebuilds. This final phase optimizes the now-modular, well-structured codebase for maximum rendering performance.

No phase may begin until its predecessor is fully complete and verified.
