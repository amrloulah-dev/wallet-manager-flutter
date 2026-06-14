# 🚀 Report 8: Product Specification, Limits & Roadmap (PRD)

## 1. Current Feature Matrix & Access Control

The Wallet Manager application provides a comprehensive suite of tools tailored for Egyptian store owners to manage their mobile financial operations. The overarching capabilities of the system include:

*   **Wallet Management:** Creation, tracking, and balance management of various mobile wallets (Vodafone Cash, Orange Cash, Etisalat Cash, WE Pay) and bank transfers (InstaPay).
*   **Transaction Logging:** Detailed logging of incoming and outgoing transactions, including transfers, cash deposits, and withdrawals, with support for identifying sender/receiver numbers.
*   **Debt Tracking:** Integrated management of customer debts, linking owed amounts to specific profiles and tracking repayments over time.
*   **Automated SMS Processing:** A background service (Guardian Isolate) that monitors incoming SMS messages from telecom providers to automatically parse and log transactions in real-time, optionally triggering an interactive overlay.
*   **Offline-First Capabilities:** Local caching and optimistic UI updates allow the app to function and register changes quickly without a continuous internet connection, syncing with Firebase Firestore in the background.

### Access Control Matrix

The system enforces strict Role-Based Access Control (RBAC) to ensure security and proper delegation between Store Owners and their Employees.

| Feature / Capability | Store Owner | Employee |
| :--- | :---: | :---: |
| **Create/Edit Wallets** | ✅ | ❌ |
| **Delete Wallets** | ✅ | ❌ |
| **Create Transactions** | ✅ | ✅ |
| **Edit/Delete Transactions** | ✅ | ❌ |
| **Manage Debts** | ✅ | ✅ |
| **View Aggregate Dashboard Stats** | ✅ | ❌ (Limited to own shifts/wallets) |
| **Manage Subscriptions & Billing** | ✅ | ❌ |
| **Manage Store Settings & Employees** | ✅ | ❌ |

---

## 2. Business Limits & Operational Quotas

The application operates within two distinct sets of boundaries: the internal SaaS limits defined by the user's subscription, and the external operational limits dictated by the Egyptian mobile money market.

### Subscription Limits (SaaS)

The platform employs a freemium model to encourage onboarding while monetizing power users and larger stores.

*   **Free Plan:**
    *   Maximum Wallets: 3
    *   Maximum Employees: 1
    *   Suitable for small kiosks or individual merchants.
*   **Pro / Lifetime Plan:**
    *   Maximum Wallets: 999 (Effectively unlimited)
    *   Maximum Employees: 999 (Effectively unlimited)
    *   Unlocks advanced analytics, full SMS automation customization, and priority support.

### Egyptian Market Wallet Limits (Operational)

To prevent blocked transactions and account freezes, the system actively monitors and alerts users based on the physical limits of the Egyptian mobile money ecosystem.

*   **Standard Telecom Wallets (Vodafone Cash, Orange Cash, Etisalat Cash, WE Pay):**
    *   **Daily Limit:** 60,000 EGP
    *   **Monthly Limit:** 200,000 EGP
*   **Bank/InstaPay Transfers:**
    *   **Daily Limit:** 120,000 EGP
    *   **Monthly Limit:** 400,000 EGP

**Tracking with the `WalletLimits` Model:**
The application utilizes a `WalletLimits` data model associated with each wallet. This model aggregates the `totalIncoming` and `totalOutgoing` transaction values for the current day and month. Before a new transaction is committed, the system calculates the projected totals and validates them against the hardcoded market limits above. If a limit is approaching (e.g., >90%) or exceeded, the app surfaces a warning UI to prevent the user from attempting a transaction that the network will reject.

---

## 3. Platform Limitations & Technical Constraints

Certain constraints are dictated by the underlying mobile operating systems (Android and iOS) which define what the application technically cannot do.

### iOS Ecosystem Constraints

*   **No Automated SMS Interception:** Due to Apple's strict sandboxing rules and privacy guidelines, it is technically impossible to automatically read incoming SMS messages in the background on iOS. The "Guardian Isolate" background SMS processing and overlay features are exclusively available on Android. iOS users must enter transactions manually or rely on alternative workflows (like reading notifications manually).

### Android Battery & Doze Mode

*   **Aggressive OEM Optimizations:** Android manufacturers (particularly Xiaomi, Oppo, Vivo, and Huawei) implement aggressive, non-standard battery optimization features. These system-level task killers frequently terminate background services, including our Guardian Isolate responsible for SMS monitoring.
*   **Required Mitigation:** To ensure reliable automated SMS processing, users on these devices must explicitly whitelist the Wallet Manager app in their device settings (e.g., disabling MIUI battery saver, enabling "Autostart", and locking the app in memory). The app must guide users through this complex configuration process via in-app prompts.

---

## 4. Missing Features & Future Roadmap

Based on the requirements of typical Enterprise Financial systems and merchant feedback, the following features are identified as missing and form the core of the future development roadmap:

### Data Exporting & Reporting
*   **Current State:** Users can view statistics in the dashboard but cannot export the raw data.
*   **Roadmap:** Implement PDF and Excel (CSV) generation for daily closing reports, shift handovers, and client transaction receipts. This will facilitate accounting and auditing for store owners.

### Hardware Integration
*   **Current State:** No support for external hardware.
*   **Roadmap:** Introduce Bluetooth thermal printer integration. This will allow merchants to print physical paper receipts for customers upon completing a deposit, withdrawal, or debt payment, which is a common requirement in the Egyptian retail market.

### Push Notifications
*   **Current State:** The app relies on local state changes and background sync, but lacks proactive remote alerting.
*   **Roadmap:** Implement cloud-based FCM (Firebase Cloud Messaging) push notifications. This will enable real-time alerts to Store Owners when specific events occur, such as an employee processing an unusually large transaction, or a wallet nearing its daily limit.

### Trash Bin / Soft-Delete Restoration
*   **Current State:** The database schema supports soft-deletion (using an `isDeleted` flag on transaction documents), but the UI permanently hides these records.
*   **Roadmap:** Develop a dedicated "Trash Bin" or "Archive" UI screen. This will allow Store Owners to review accidentally deleted records, audit employee deletions, and restore soft-deleted transactions back into the active ledger to correct mistakes.
