# Feature Specification: WalletManager SaaS Migration (Phase 1 — Client App)

**Feature ID:** 001
**Branch:** `feature/001-saas-migration`
**Created:** 2026-04-09
**Status:** Draft
**Source Document:** [WalletManager SaaS.md](file:///c:/src/walletmanager/WalletManager%20SaaS.md)

---

## 1. Feature Overview

### Problem Statement

WalletManager currently operates under a legacy single-license key model. Store owners purchase a one-time license to unlock the application. This model prevents recurring revenue, limits the ability to tier features by customer value, and provides no mechanism for subscription lifecycle management (trials, downgrades, renewals, or upgrades). Additionally, the current system has no anti-fraud protection against trial abuse via device resets.

### Proposed Solution

Migrate the client application from a license-key activation model to a multi-tier cloud subscription (SaaS) system. The new model supports four plan tiers — **Trial**, **Free**, **Pro Yearly**, and **Lifetime** — each with gated feature limits. The store document becomes the single source of subscription truth, eliminating the legacy license system entirely. The migration introduces subscription request workflows, anti-fraud device tracking, downgrade freeze logic, and a suite of Arabic RTL paywall and status screens.

### Target Users

| User Role       | Description                                                                 |
| --------------- | --------------------------------------------------------------------------- |
| Store Owner     | Primary user who manages wallets, employees, and transactions               |
| Employee        | Secondary user granted limited access by the Store Owner                    |
| System Admin    | Backend operator who approves/rejects subscription upgrade requests         |

---

## Clarifications

### Session 2026-04-09
- Q: What is the exact trial period duration? → A: 14 days.
- Q: What are the exact feature limits per plan tier? → A: Free: 3 wallets, 1 employee, no SMS. Trial/Pro Yearly/Lifetime: 999 wallets, 999 employees, SMS enabled.
- Q: What happens on the client when an admin sets store status to "suspended"? → A: Full-screen block — user sees a dedicated Arabic message and cannot access any app features.
- Q: What default subscription state do existing licensed stores receive under the new model? → A: Grant Lifetime — existing paying customers are grandfathered permanently.

---

## 2. User Stories

### US-01: Trial Onboarding
**As a** new Store Owner signing up for the first time on a fresh device,
**I want to** receive a complimentary trial period with full feature access,
**So that** I can evaluate the application before committing to a paid plan.

**Acceptance Criteria:**
- On first registration from a never-before-seen device, the store is automatically created on the "trial" plan.
- The trial includes elevated feature limits (wallets, employees, SMS).
- The trial has a fixed duration of 14 days with a visible end date.
- Once the trial expires and no payment is pending, the store transitions locally to "free" tier behavior.

### US-02: Repeat-Device Fraud Prevention
**As the** system,
**I want to** detect when a device has previously been used for a trial registration,
**So that** trial abuse through factory resets is prevented.

**Acceptance Criteria:**
- On every sign-up, the device's unique hardware identifier is checked against a central device registry.
- If the device has a prior registration record, the new store is created directly on the "free" tier with the trial marked as consumed.
- The user is not shown an error — they simply begin on the free tier.

### US-03: Subscription Upgrade Request
**As a** Store Owner on the Free or Trial plan,
**I want to** request an upgrade to a paid plan (Pro Yearly or Lifetime),
**So that** I can unlock higher feature limits for my business.

**Acceptance Criteria:**
- The user selects the desired plan from a full-screen paywall.
- The user chooses a payment method (Vodafone Cash or InstaPay) and provides the payment reference.
- A subscription request record is created with "pending" status.
- The store's subscription is flagged as having a pending request.
- The user sees a persistent dashboard banner confirming the request is under review.
- Only one pending request may exist at a time per store.

### US-04: Subscription Approval Feedback
**As a** Store Owner whose upgrade request has been approved,
**I want to** see a success confirmation the next time I open the app,
**So that** I know my plan has been upgraded and new limits are active.

**Acceptance Criteria:**
- On the first app launch after the plan transitions from pending to an upgraded tier, a success modal is displayed.
- The modal shows the new plan name and updated feature limits.
- After dismissing the modal, the dashboard reflects the new plan.

### US-05: Subscription Rejection Feedback
**As a** Store Owner whose upgrade request has been rejected,
**I want to** see a clear error banner on my dashboard,
**So that** I understand my request was not approved and can take corrective action.

**Acceptance Criteria:**
- A prominent rejection banner is displayed on the dashboard.
- The banner communicates that the request was not approved.
- The user can dismiss the banner and submit a new request.

### US-06: Expired Plan with Pending Payment (Grace Period)
**As a** Store Owner whose plan has expired but who has a pending payment request,
**I want to** retain access to my current features for a limited grace period,
**So that** I am not penalized while my payment is being reviewed.

**Acceptance Criteria:**
- If the plan end date has passed AND a pending request exists, the system grants a 48-hour local grace period.
- A visible Arabic-language banner informs the user: "تم تمديد باقتك مؤقتاً لحين مراجعة الدفع".
- If the 48-hour window expires without approval, the store transitions locally to "free" tier behavior.

### US-07: Downgrade — Wallet Freezing
**As the** system,
**When** a Store Owner's plan downgrades to a tier with fewer allowed wallets,
**I want to** freeze (make read-only) the newest wallets exceeding the limit,
**So that** no financial data is deleted but feature gating is enforced.

**Acceptance Criteria:**
- Wallets are sorted by creation date (oldest first).
- The oldest wallets up to the new plan's limit remain fully operational.
- Wallets beyond the limit become read-only: viewable but not editable or usable for new transactions.
- No wallet data is ever deleted during a downgrade.

### US-08: Downgrade — Employee Suspension
**As the** system,
**When** a Store Owner's plan downgrades to a tier with fewer allowed employees,
**I want to** suspend the newest employees exceeding the limit while retaining the owner,
**So that** access control matches the plan without deleting any employee records.

**Acceptance Criteria:**
- The Store Owner is always retained regardless of the employee limit.
- Among remaining employees, the oldest (by creation date) are kept active up to the limit.
- Employees beyond the limit are suspended (cannot log in or perform actions).
- No employee data is deleted.

### US-09: Feature Gating — Hard Stop
**As the** system,
**When** a Store Owner attempts to exceed a feature limit (wallets, employees, or SMS),
**I want to** immediately redirect them to the full-screen paywall,
**So that** there is a clear, non-dismissable call-to-action to upgrade.

**Acceptance Criteria:**
- Attempting to create a wallet beyond the `maxWallets` limit triggers the paywall.
- Attempting to add an employee beyond the `maxEmployees` limit triggers the paywall.
- Attempting to use SMS when SMS is disabled on the current plan triggers the paywall.
- The paywall is a full-screen experience — no snackbar, toast, or bottom sheet alternatives.

### US-10: Lifetime Plan Scarcity
**As a** Store Owner viewing the paywall,
**I want to** see how many Lifetime plan seats remain,
**So that** I feel urgency to purchase before availability runs out.

**Acceptance Criteria:**
- The paywall displays the current sold count vs. the maximum limit for Lifetime seats.
- An Arabic-language "remaining seats" indicator is rendered dynamically (e.g., "باقي X مقعد فقط!").
- If the Lifetime plan is deactivated globally, the Lifetime card is hidden entirely from the paywall.

### US-11: Background SMS Subscription Enforcement
**As the** system,
**When** the SMS background parser is processing incoming messages,
**I want to** verify the store's subscription status before auto-creating transactions,
**So that** expired or free-tier stores do not benefit from premium SMS automation.

**Acceptance Criteria:**
- The background SMS processor reads subscription expiration data from local device storage.
- If the current time exceeds the stored expiration timestamp, SMS processing halts immediately.
- Lifetime subscriptions are recognized and never halted.
- The stored subscription data is kept in sync with the main application's subscription state in real-time.

### US-12: View My Subscription
**As a** Store Owner,
**I want to** view my current subscription details,
**So that** I can see my plan, remaining days, and how much of my feature limits I've consumed.

**Acceptance Criteria:**
- A dedicated subscription details screen shows the current plan name.
- Remaining days until expiration are displayed (or "Unlimited" for Lifetime).
- Visual progress bars show current usage vs. maximum for wallets and employees.
- The screen is accessible from the main navigation.

### US-13: Admin Suspension Block
**As a** Store Owner whose account has been manually suspended by an administrator,
**I want to** see a clear, dedicated block screen explaining that my account is suspended,
**So that** I understand I cannot access any app features until the suspension is lifted.

**Acceptance Criteria:**
- When `subscription.status == "suspended"`, a full-screen Arabic-language block message is displayed.
- The block screen prevents access to all app features — no navigation, no data access.
- The block screen is distinct from the paywall (no upgrade option shown).
- If the admin lifts the suspension (status returns to "active"), the block screen is removed on the next real-time update.

---

## 3. Functional Requirements

### FR-01: Store Data Model Transition
- The legacy license activation fields (license key, license key ID, license object) must be removed from the store data model.
- The legacy `maxEmployees` setting must be removed from settings.
- A new subscription object must be embedded in the store record containing: plan identifier, status, pending-request flag, start date, end date, trial-consumed flag, and a features sub-object with wallet limit, employee limit, and SMS enablement.
- Feature limits by plan tier:
  - **Free:** maxWallets = 3, maxEmployees = 1, isSmsEnabled = false.
  - **Trial:** maxWallets = 999, maxEmployees = 999, isSmsEnabled = true.
  - **Pro Yearly:** maxWallets = 999, maxEmployees = 999, isSmsEnabled = true.
  - **Lifetime:** maxWallets = 999, maxEmployees = 999, isSmsEnabled = true.

### FR-02: Subscription Request Lifecycle
- A new subscription request record type must support: unique ID, store reference, requested plan, payment method, payment reference string, amount, status (pending/approved/rejected), creation timestamp, processing timestamp, and processor identity.
- Creating a request must atomically set the store's pending-request flag to true.
- Only one active (pending) request may exist per store at any time.

### FR-03: System Configuration
- A global system configuration record must store: lifetime sold count, lifetime maximum limit, and lifetime active flag.
- The paywall must read these values to determine Lifetime card visibility and scarcity display.

### FR-04: Legacy License Key Preservation
- The existing license keys data must not be deleted.
- The license key system must be internally repurposed for future promotional code functionality.

### FR-05: Subscription Gatekeeper
- A central subscription authority must expose methods to check: whether a new wallet can be added (current count vs. limit), whether a new employee can be added (current count vs. limit), and whether SMS is enabled.
- Each gatekeeper check returning "no" must trigger a full-screen paywall redirect — never a dismissable notification.

### FR-06: Lazy Expiration (Client-Side)
- The client must never send a write request to expire an account.
- Expiration must be computed locally by comparing the subscription end date with a server-synchronized clock (NTP).
- If expired with a pending request: grant 48-hour grace, show Arabic banner.
- If expired without a pending request: treat locally as "free" tier.

### FR-07: Downgrade Freeze Logic (FIFO)
- On downgrade, data must never be deleted.
- Wallets beyond the new limit are frozen (read-only), preserving the oldest wallets as active, sorted by creation date.
- Employees beyond the new limit are suspended, preserving the owner plus the oldest employees.

### FR-08: Background SMS Subscription Sync
- Whenever subscription data changes, the expiration timestamp, lifetime status, and server time offset must be immediately persisted to local device storage.
- The background SMS parser must read these persisted values and halt processing if the subscription is expired.

### FR-09: Device-Based Anti-Fraud
- On every new user registration, the device's hardware identifier must be captured.
- The identifier must be checked against a device registration collection.
- Known devices (prior registration) must bypass trial and be placed directly on the free tier with the trial-consumed flag set.
- New devices receive the trial tier.### FR-10: Arabic Language, RTL & Strict MCP UI Fetching
- All user-facing text must be strictly in Arabic.
- All UI layouts must be rendered in Right-to-Left (RTL) directionality.
- Text alignment, padding, margins, and icon placement must respect RTL conventions.
- **CRITICAL MCP DIRECTIVE:** You must NEVER guess, invent, or hallucinate UI layouts. All screen designs must be sourced explicitly using the MCP tool `get_screen` from Google Stitch.
- **Master Project ID:** You must pass the Project ID `3771784857992882396` for all UI fetch operations.

### FR-11: Paywall Screen Implementation
- **MCP Fetch Requirement:** Before writing code, use the `get_screen` tool to fetch ID `a6677cb11d3841d0a060b8cefc26c027` (Subscription Paywall) and ID `4ae1fd63bbcf4a8cb6c6b963be0ca45e` (Founders Lifetime VIP Card).
- A full-screen paywall must display available upgrade plans and act as a hard-stop.
- The Lifetime plan card must show dynamic sold/remaining counts sourced from system configuration (e.g., translating to "باقي X مقعد فقط!").
- The Lifetime card must be hidden entirely from the UI when globally deactivated.
- The paywall must support navigation to the payment instructions flow.

### FR-12: Payment Instructions & Submission
- A payment screen must allow toggling between supported payment methods (Vodafone Cash, InstaPay).
- On submission, a pending subscription request record must be created.
- The store's pending-request flag must be set atomically with the request creation.

### FR-13: Dashboard Status Banners
- A pending-state banner must appear on the dashboard when a payment request is under review.
- A rejection-state banner must appear when a request has been denied.
- Banners must not interfere with normal dashboard functionality.

### FR-14: Subscription Details Screen
- A dedicated screen must display: current plan, remaining days (or "unlimited"), and usage progress bars for wallets and employees vs. their plan limits.

### FR-15: Payment Success Modal
- An asynchronous success modal must be triggered on the first app launch after a plan upgrade is detected (transition from pending to upgraded plan).

### FR-16: Admin Suspension Enforcement
- When the subscription status is "suspended", the client must immediately display a full-screen block screen with an Arabic-language message.
- The block screen must prevent access to all app functionality — no navigation, transactions, or data viewing.
- The block screen must not offer upgrade options (it is distinct from the paywall).
- The block must be lifted in real-time when the subscription status changes back to "active".
- Background SMS processing must also halt when the store is suspended.

### FR-17: Legacy Store Migration Default
- When the client detects a store record that lacks the new subscription object (legacy licensed store), it must treat the store as a **Lifetime** subscriber.
- The client must populate the subscription object with: planId = "lifetime", status = "active", endDate = null, trialConsumed = true, and full feature limits (999 wallets, 999 employees, SMS enabled).
- This ensures existing paying customers are grandfathered into the highest tier with no disruption.

---

## 4. User Scenarios & Testing

### Scenario 1: Fresh User Onboarding (Happy Path)
1. A new user installs the app on a brand-new device.
2. The user completes the sign-up flow.
3. The system checks the device registry — no prior record found.
4. The store is created on the "trial" plan with full features.
5. The user sees the dashboard with trial status and expiration date.

### Scenario 2: Repeat Device Onboarding (Fraud Prevention)
1. A user who previously used a trial registers again (same device, new account).
2. The system detects the device in the registry.
3. The store is created on the "free" plan with trial marked as consumed.
4. The user sees the dashboard with free-tier limits — no trial banner.

### Scenario 3: Upgrade Request Flow
1. A free-tier user taps "Upgrade" on the dashboard or hits a feature limit.
2. The paywall opens full-screen showing available plans.
3. The user selects "Pro Yearly" and chooses Vodafone Cash.
4. The user enters the payment reference and submits.
5. A pending request is created; the dashboard shows a pending banner.
6. An admin approves the request.
7. On next app launch, the success modal appears; the plan is now "pro_yearly".

### Scenario 4: Rejected Upgrade Request
1. A user submits an upgrade request.
2. The admin rejects the request.
3. On next visit, the dashboard shows a rejection error banner.
4. The user can dismiss and try again.

### Scenario 5: Expired Plan with Pending Payment
1. A user's Pro Yearly plan expires.
2. The user has a pending upgrade request (hasPendingRequest = true).
3. The system grants a 48-hour grace period.
4. The Arabic grace banner is displayed.
5. If 48 hours pass without approval, the local plan drops to "free".

### Scenario 6: Downgrade Freeze (Wallets)
1. A user with 10 wallets downgrades from Pro (999 max) to Free (3 max).
2. The 3 oldest wallets remain fully operational.
3. The 7 newest wallets become read-only (frozen).
4. No data is deleted.

### Scenario 7: Downgrade Freeze (Employees)
1. A store with 3 employees downgrades to Free (1 max employee + owner).
2. The owner is always retained.
3. The oldest employee is retained.
4. The remaining employee is suspended.

### Scenario 8: Lifetime Plan Sold Out
1. A user opens the paywall.
2. `is_lifetime_active` is false OR sold count equals max limit.
3. The Lifetime card is not visible on the paywall.

### Scenario 9: SMS Background Halt on Expiration
1. A user's plan expires.
2. Subscription data is written to local storage.
3. An SMS arrives triggering the background parser.
4. The parser reads stored expiration — finds the plan expired.
5. SMS processing halts; no auto-transaction is created.

### Scenario 10: Admin Suspension
1. An admin manually sets the store's subscription status to "suspended".
2. The real-time listener detects the change.
3. The app immediately shows a full-screen Arabic block message.
4. All navigation and data access is disabled.
5. The admin lifts the suspension (status → "active").
6. The block screen is removed; normal app access resumes.

### Scenario 11: Legacy Store Encounters New Client
1. An existing store with a legacy license key opens the app after the SaaS update.
2. The client detects the store record has no subscription object.
3. The client assigns Lifetime subscription defaults (999 wallets, 999 employees, SMS).
4. The store owner continues using the app with full access — no disruption.

---

## 5. Key Entities

| Entity                 | Description                                                                                      |
| ---------------------- | ------------------------------------------------------------------------------------------------ |
| Store                  | Core business entity containing the embedded subscription object and owner reference              |
| Subscription (embedded)| Embedded object within Store defining plan, status, dates, trial flag, and feature limits         |
| Subscription Request   | Standalone record tracking an upgrade payment request through its lifecycle                       |
| System Configuration   | Singleton global record controlling lifetime plan availability and scarcity counters              |
| Device Registration    | Record linking hardware identifiers to past registrations for anti-fraud checks                   |
| License Key (legacy)   | Preserved legacy records repurposed internally for future promotional codes                       |

---

## 6. Scope & Boundaries

### In Scope
- Client-side subscription model migration (store data model changes).
- Subscription gatekeeper logic (feature limit checks and paywall enforcement).
- Subscription request creation workflow (client-side only).
- Client-side lazy expiration with grace period.
- FIFO downgrade freeze logic (wallets and employees).
- Device-based anti-fraud on registration.
- Background SMS subscription enforcement via local storage sync.
- Full Arabic RTL paywall, payment, banner, subscription detail, and success modal screens.
- System configuration reads for lifetime plan scarcity.

### Out of Scope
- Admin dashboard for approving/rejecting requests (server-side tool).
- Server-side subscription expiration (Cloud Functions or scheduled jobs).
- Payment gateway integrations (manual verification assumed).
- Push notification delivery for approval/rejection.
- Analytics and reporting dashboards.
- Migration tooling for existing license-key users (server-side batch migration scripts — client-side default assignment via FR-17 IS in scope).

---

## 7. Dependencies & Assumptions

### Dependencies
- Existing Firestore infrastructure and authentication system.
- Existing store, wallet, employee, and transaction data models.
- Device information retrieval capability for hardware identifiers.
- NTP or server-time synchronization for expiration comparisons.
- Configured UI design system with pre-built screen components for paywall, payment, banners, subscription details, and success modal.

### Assumptions
- The admin approval/rejection workflow exists or will exist server-side and is not part of this specification.
- The 48-hour grace period for pending payments is sufficient for manual payment review.
- Only one pending subscription request per store at a time is acceptable.
- The FIFO (oldest-first) strategy for wallet/employee retention during downgrade is the correct business decision.
- Existing licensed stores are grandfathered as Lifetime subscribers — no re-purchase required.
- "Vodafone Cash" and "InstaPay" are the only two payment methods for launch.
- Lifetime plan seats are a finite, scarcity-driven offering controlled globally.
- The existing SMS background processing pipeline is functional and only needs subscription-aware gating added.
- All existing 7 Project Constitution principles (Optimistic UI, Surgical Reactivity, Zero-Waste Reads, Safe Rollbacks, O(1) Lookups, Fetch Shield, ValueKey Invalidation) remain in full force.

---

## 8. Success Criteria

| #  | Criterion                                                                                            | Metric                         |
| -- | ---------------------------------------------------------------------------------------------------- | ------------------------------ |
| 1  | Store owners can view and understand their subscription status at a glance                            | 100% of plan info visible      |
| 2  | Upgrade requests are submitted and confirmed within 2 minutes of user intent                         | < 2 min task completion        |
| 3  | Feature limit enforcement is immediate — no user can exceed plan boundaries                          | 0 limit violations observed    |
| 4  | Expired plans with pending payments receive a grace period without data loss                          | 100% grace accuracy            |
| 5  | Downgrade never deletes user data — only freezes/suspends excess resources                            | 0 records deleted on downgrade |
| 6  | Repeat-device trial abuse is blocked for 100% of known devices                                       | 0 duplicate trials granted     |
| 7  | SMS background processing halts within 1 second of detecting an expired subscription                  | < 1s halt latency              |
| 8  | All UI screens render correctly in Arabic with proper RTL directionality                              | 0 RTL layout defects           |
| 9  | Users perceive zero latency on subscription status checks (optimistic local reads)                    | < 100ms perceived response     |
| 10 | The paywall displays accurate lifetime seat scarcity from live system configuration                   | Real-time accuracy             |

---

## 9. Execution Strategy

> **CRITICAL: Bottom-Up, Phase-by-Phase Execution**

This feature MUST be implemented strictly bottom-up, in the following phase order:

1. **Phase 1 — Data Layer:** Define and migrate all data models (Store subscription object, SubscriptionRequest, SystemConfigs, DeviceRegistration). Remove legacy license fields.
2. **Phase 2 — Domain Layer:** Implement the SubscriptionProvider (gatekeeper), lazy expiration logic, downgrade freeze logic, anti-fraud registration checks, and background SMS sync.
3. **Phase 3 — Presentation Layer:** Build all UI screens (paywall, payment, banners, subscription details, success modal) using MCP-sourced designs adapted for Arabic RTL.

No phase may begin until its predecessor is fully complete and verified.
