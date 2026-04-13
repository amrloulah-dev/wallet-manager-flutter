# 🚀 Master Specification: WalletManager SaaS Migration (Phase 1: Client App)

## 0. Overview & Global Rules
This document is the absolute source of truth for refactoring WalletManager from a single-license system to a multi-tier Cloud SaaS ERP.
* **Execution Rule:** Work strictly Bottom-Up. Do NOT guess UI layouts; you MUST fetch them using the configured Google Antigravity / Stitch MCP tools.
* **Language & RTL Constraint (CRITICAL):** The application is strictly in Arabic. All UI implementations fetched via MCP MUST be adapted for Right-To-Left (RTL) directionality. Ensure proper text alignment (`TextAlign.right` or `start` in RTL context), RTL padding/margins, and Arabic typography.

---

## 1. Data Layer: Dynamic Firestore Schema (Strict Enforcement)

### 1.1. `stores` Collection Refactoring
* **Remove:** Delete `activeLicenseKey`, `licenseKeyId`, and the entire legacy `license` object from the `StoreModel`. Remove `settings.maxEmployees`.
* **Implement `subscription` Object:** Embed the following object inside the `StoreModel`:
    ```json
    "subscription": {
      "planId": "trial", // 'trial', 'free', 'pro_yearly', 'lifetime'
      "status": "active", // 'active' (normal) or 'suspended' (admin manual block)
      "hasPendingRequest": false, // GLOBAL STATE for UI sync
      "startDate": Timestamp,
      "endDate": Timestamp, // null for 'free' and 'lifetime'
      "trialConsumed": true,
      "features": {
        "maxWallets": 10,
        "maxEmployees": 3,
        "isSmsEnabled": true
      }
    }
    ```

### 1.2. New & Repurposed Collections
* **`SubscriptionRequestModel` (`subscription_requests` col):**
    Fields: `id`, `storeId`, `requestedPlanId` ('pro_yearly', 'lifetime'), `paymentMethod` ('vodafone_cash', 'instapay'), `paymentReference` (String), `amount` (double), `status` ('pending', 'approved', 'rejected'), `createdAt`, `processedAt` (nullable), `processedBy` (nullable).
* **`SystemConfigsModel` (`system_configs/globals` doc):**
    Fields: `lifetime_sold_count` (int), `lifetime_max_limit` (int), `is_lifetime_active` (bool).
* **`license_keys` collection:** DO NOT DELETE. Repurpose this model internally to act as manual Promo Codes for future use.

---

## 2. Domain Layer: Business Logic & Anti-Fraud

### 2.1. `SubscriptionProvider` (The Gatekeeper)
* **Initialization:** Listens to the `store` document in real-time.
* **Getters:** `planId`, `endDate`, `hasPendingRequest`.
* **Gatekeeper Methods:**
    * `canAddWallet(int currentCount)`: returns `currentCount < features.maxWallets`.
    * `canAddEmployee(int currentCount)`: returns `currentCount < features.maxEmployees`.
    * `isSmsEnabled`: returns `features.isSmsEnabled`.
* **The "Hard Stop" Rule:** If any Gatekeeper method returns `false`, immediately route the user to the `FullScreenPaywallScreen`. Do NOT show a snackbar or bottom sheet.

### 2.2. Lazy Expiration & Grace Period Logic (UI Side)
* Do NOT send Firestore update requests from the client to expire an account.
* Compare `endDate` with Server Time (NTP).
* If expired AND `hasPendingRequest == true`: Grant a 48-hour local grace period and display an Arabic banner: "تم تمديد باقتك مؤقتاً لحين مراجعة الدفع".
* If expired AND `hasPendingRequest == false`: Treat locally as 'free' tier and apply freeze logic.

### 2.3. Downgrade Freeze Logic (FIFO)
* Never delete data on downgrade.
* **Wallets:** Only allow mutations on the oldest wallets (based on `createdAt` sorting) up to the new `maxWallets` limit. Others are Read-Only (Frozen).
* **Employees:** Keep the Owner + oldest employee up to `maxEmployees`. Suspend others.

### 2.4. Real-time Background Sync (SMS Protection)
* Whenever the `SubscriptionProvider` receives a Firestore update, it MUST immediately update `SharedPreferences`:
    `prefs.setInt('sub_end_date_ms', newEndDate.millisecondsSinceEpoch)`.
* Store `is_sub_lifetime` (bool) and `server_time_offset_ms` (int).
* The SMS Background Parser must read these prefs and strictly Halt if `RealTime > sub_end_date_ms`.

### 2.5. Hybrid Anti-Fraud (Registration)
* On `SignUp`: Fetch `androidId` using `device_info_plus`.
* Query `device_registrations` collection.
* If device exists (`trialCount > 0`), create the new `store` explicitly on the `free` tier with `trialConsumed: true`. Else, grant `trial`.

---

## 3. Presentation Layer: UI Implementation via MCP

> **⚠️ AGENT DIRECTIVE - MCP STITCH INTEGRATION:**
> Do NOT invent UI layouts. You must use the `get_screen` tool from the configured Stitch MCP server to fetch the exact UI components. Convert all fetched text strings to their appropriate Arabic translations and ensure RTL (`Directionality`) is applied perfectly.
> **Project ID for all calls:** `3771784857992882396`

### 3.1. Full Screen Paywall & Lifetime Offer
* **MCP Call:** Use `get_screen` with ID `a6677cb11d3841d0a060b8cefc26c027` (Subscription Paywall). For the VIP lifetime card, fetch ID `4ae1fd63bbcf4a8cb6c6b963be0ca45e` (Founders Lifetime VIP Card).
* **Logic:** Render `lifetime_sold_count` / `lifetime_max_limit` dynamically. Hide the Lifetime card if `is_lifetime_active == false`. Render "ONLY X SEATS LEFT" logic in Arabic.

### 3.2. Payment Instructions & Forms
* **MCP Call:** Use `get_screen` with ID `ec8b75188dad45ba88c4c0d3969b6e01` (Payment Instructions Segmented).
* **Logic:** Allow toggling between Vodafone Cash and InstaPay. On submit, create a `SubscriptionRequestModel` (`status: pending`) and trigger a batch write to set the store's `subscription.hasPendingRequest = true`.

### 3.3. Dashboard Banners (Pending & Error States)
* **MCP Call (Pending):** Use `get_screen` with ID `c9ed6340f6b94cfcb40e9bf883e382a3` (FinTech Dashboard Pending State). Show this if `hasPendingRequest == true`.
* **MCP Call (Rejected):** Use `get_screen` with ID `5dd15c1185ab4f3bb724cfb17b6081b3` (Dashboard Error State).

### 3.4. My Subscription Details
* **MCP Call:** Use `get_screen` with ID `94512b051efb4c2aa7ebd91de061fa0b` (My Subscription).
* **Logic:** Display current `planId`, remaining days (`endDate`), and calculate the visual progress bar based on current wallet/employee count vs `features.maxWallets`.

### 3.5. Payment Success Modal
* **MCP Call:** Use `get_screen` with ID `8ccdd3b851a049b8991cbcc9ad45e69d` (Payment Success Modal).
* **Logic:** Trigger this async success popup on the first app launch after the provider detects a transition from `hasPendingRequest == true` to an upgraded `planId`.