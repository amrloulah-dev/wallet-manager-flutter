Act as a Senior Flutter Developer and Product Engineer. We are entering the "Monetization & Business Logic" phase of the app. I will provide you with a detailed architectural blueprint for 6 critical modifications. 

**DO NOT WRITE THE FULL CODE YET.** Your task is to read this blueprint, understand the business logic, acknowledge each point, and tell me which files you will open to implement them. Once we agree on the files, I will command you to execute.

### 🌐 General Context of the Plan
The application has stabilized its authentication and core architecture. We must now strictly enforce subscription logic, refine the upgrade user experience (UX), correct pricing and marketing copy, and ensure accurate data presentation. Security and business protection are top priorities.

---

### 🛡️ Task 1: Protect Business Logic (SMS Automation)
**Specific Context:** SMS Automation is a premium feature. It is currently accessible to everyone. We must lock it behind an active subscription while keeping it visible for marketing purposes.
**Execution Details:**
- Locate the Settings Screen where the SMS Automation toggle resides.
- Check the user's active subscription status (Trial, Annual, or Lifetime) and whether it is expired.
- If the subscription is active (e.g., Trial is still within 14 days, or Annual/Lifetime is active), the toggle works normally.
- If the subscription is expired (Trial ended, Annual expired), the toggle must be visually disabled (grayed out or locked).
- If a user interacts with the locked toggle, display a toast or dialog stating "هذه الميزة تتطلب ترقية الحساب" (This feature requires account upgrade) and route them to the Paywall/Upgrade Screen.

### ✍️ Task 2: Paywall Pricing & Copywriting
**Specific Context:** The current Paywall screen displays incorrect prices, wrong remaining seats for the lifetime plan, and lacks attractive marketing copy.
**Execution Details:**
- Locate the Paywall/Upgrade Screen.
- **Annual Pro Plan:** Update price to 1200 EGP / year. Update the features list exactly to:
  1. قراءة المعاملات تلقائيا
  2. إدارة مرنة حتى 50 محفظة
  3. بناء فريق عمل حتى 20 موظف
  4. دعم فني مخصص
- **Lifetime Plan:** Update price to 2500 EGP. Change the "seats remaining" badge to 50. Update the features list exactly to:
  1. قراءة المعاملات تلقائيا
  2. عدد لا نهائي من المحافظ
  3. عدد لا نهائي من الموظفين
  4. أولوية الدعم الفني VIP

### 💳 Task 3: Payment Details Update
**Specific Context:** The manual payment instructions (Vodafone Cash and InstaPay) have outdated numbers and confusing input fields.
**Execution Details:**
- Locate the Payment Details/Checkout UI.
- Update the target transfer number for BOTH Vodafone Cash and InstaPay to: `01091264053`.
- Locate the `TextField` where the user inputs the transaction receipt number. Change its Hint Text / Label from "رقم الإيصال / رقم العملية" to "رقم الهاتف الذي تم التحويل منه" to improve UX.

### 📊 Task 4: Fix Zero Active Wallets/Employees Bug
**Specific Context:** The Subscription Details screen shows '0' for active wallets and employees because it reads from a static, uninitialized `StoreStats` object.
**Execution Details:**
- Locate the Subscription Details Screen.
- Instead of reading from `store.stats`, inject the `WalletProvider` and `EmployeeProvider` (or their respective repositories/lists).
- Display the actual real-time `.length` of the active wallets list and the employees list so the counters are always accurate.

### ⏳ Task 5: Dashboard Expiry Banner
**Specific Context:** Users lack visibility on their remaining subscription days, causing abrupt lockouts. We need a persistent, elegant warning banner at the top of the Owner Dashboard.
**Execution Details:**
- Locate the `OwnerDashboard` screen. Inject a visually distinct Banner (e.g., inside a Column above the main body or as a SliverAppBar extension).
- **Logic:**
  - If Plan == Trial: ALWAYS show the banner displaying: "متبقي [X] أيام على انتهاء الفترة التجريبية. قم بالترقية الآن!"
  - If Plan == Annual AND remaining days <= 14: Show a warning banner displaying: "اشتراكك السنوي ينتهي خلال [X] أيام. جدد الآن!"
  - If Plan == Lifetime (or Annual with > 14 days): Hide the banner completely.

### ⚙️ Task 6: Settings Screen Reorganization
**Specific Context:** The "License" section in settings is too narrow. It should be a general "Subscriptions" hub allowing users to view details or upgrade.
**Execution Details:**
- Locate the Settings Screen.
- Rename the section header from "الترخيص" to "الاشتراكات".
- Keep the existing item "اشتراكي" (My Subscription) which routes to the Subscription Details screen.
- Add a NEW item directly below it titled "باقات الاشتراك" (Subscription Plans) with a star or premium icon, which routes directly to the Paywall/Upgrade screen.

---
**Agent Action Required:** Acknowledge this blueprint. List the exact file paths you intend to edit for each of the 6 tasks. Await my "GO" command before writing the code.