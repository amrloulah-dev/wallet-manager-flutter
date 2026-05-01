# Product Requirements Document (PRD)
## Wallet Manager - Flutter Mobile Application

---

## 1. Product Overview

### 1.1 Purpose
Wallet Manager is a Flutter-based mobile application designed to help store owners and businesses in Egypt manage financial digital wallets, transactions, debts, and employee access through a centralized platform.

### 1.2 Problem It Solves
- **Manual tracking errors**: Store owners currently track multiple mobile wallet balances manually, leading to calculation mistakes
- **Limit compliance**: Difficulty enforcing and tracking provider transaction limits (daily/monthly)
- **Employee oversight**: Lack of granular permissions and audit trails for employee actions
- **Cash flow visibility**: No unified view of financial performance across all wallet providers

### 1.3 Target Users
- **Primary**: Store owners in Egypt who manage physical retail businesses
- **Secondary**: Employees who perform transactions on behalf of the owner
- **Platform**: Android and iOS (mobile-first)

---

## 2. User Personas

### 2.1 Owner
| Attribute | Description |
|----------|-------------|
| Role | Full administrative access to store |
| Authentication | Email/Password or Google Sign-In |
| Responsibilities | Manage store, employees, wallets, view all statistics |
| Permissions | Complete (no restrictions) |
| Access to Payment | Requires paid subscription (Free/Trial/Pro/Lifetime) |

### 2.2 Employee
| Attribute | Description |
|----------|-------------|
| Role | Restricted access based on assigned permissions |
| Authentication | Store email + PIN |
| Responsibilities | Perform transactions, view assigned data |
| Permissions | Granular (configurable by owner) |
| Limitations | May be restricted by wallet access, transaction types, debt creation |

### 2.3 System (Implied)
| Attribute | Description |
|----------|-------------|
| Subscription Management | Trial/Premium license validation |
| Device Tracking | Device registration for license enforcement |
| Background Service | SMS monitoring when app is minimized/killed |

---

## 3. Features

### Feature 1: Authentication & Authorization

#### 3.1.1 Owner Login
- **Description**: Secure login for store owners using email/password or Google Sign-In
- **Goal**: Authenticate legitimate store owners
- **Target User**: Store owners
- **User Flow**:
  1. User opens app
  2. Selects login method (Email or Google)
  3. Enters credentials
  4. System validates against Firebase Auth + Firestore users collection
  5. On success, load store data and navigate to dashboard
- **Inputs**: Email, password, or Google token
- **Outputs**: Authenticated session, store data
- **Edge Cases**:
  - Invalid credentials → Show error
  - Subscription expired → Redirect to paywall
  - Store suspended → Show admin block screen

#### 3.1.2 Employee Login
- **Description**: Simplified PIN-based login for employees
- **Goal**: Quick access for employees without full credentials
- **Target User**: Employees
- **User Flow**:
  1. Employee opens app
  2. Enters store email
  3. Enters 4-digit PIN
  4. System validates against Firestore users collection
  5. On success, load employee-restricted data
- **Inputs**: Store email, PIN (hashed)
- **Outputs**: Employee session with scoped permissions
- **Edge Cases**:
  - Wrong PIN → Show error (max attempts unclear)
  - Employee deactivated → Deny access

#### 3.1.3 Store Registration
- **Description**: New store owner registration
- **Goal**: Create new store account
- **Target User**: New store owners
- **User Flow**:
  1. User selects "Create Store"
  2. Enters store name, owner name, email, password
  3. System creates Firebase Auth user + Firestore store document
  4. Activates trial subscription
- **Inputs**: Store name, owner name, email, password
- **Outputs**: New store, user, and activated trial

---

### Feature 2: Wallet Management

#### 3.2.1 Wallet CRUD
- **Description**: Create, read, update, delete wallet configurations
- **Goal**: Allow owners to add and manage multiple wallet providers
- **Target User**: Store owners
- **Supported Providers** (Confirmed from code):
  - Vodafone Cash
  - InstaPay
  - Orange Cash
  - Etisalat Cash
  - WE Pay
  - Other (generic)
- **User Flow**:
  1. Navigate to Wallets screen
  2. Click "Add Wallet"
  3. Select provider type
  4. Enter phone number, initial balance
  5. System enforces provider-specific transaction limits
  6. Wallet created
- **Inputs**: Phone number, wallet type, initial balance
- **Outputs**: New wallet in Firestore
- **Edge Cases**:
  - Duplicate phone number → Validation error
  - Subscription limit reached (max wallets) → Block creation
  - Invalid phone format → Validation error

#### 3.2.2 Limit Enforcement
- **Description**: Automatic daily/monthly transaction limit validation
- **Goal**: Prevent transactions exceeding provider limits
- **Mechanism**: WalletModel tracks sendLimits and receiveLimits with daily/monthly caps
- **Limit Types** (Confirmed from `AppConstants`):
  - Daily limit (resets at midnight)
  - Monthly limit (resets on 1st of month)
- **User Flow**:
  1. User attempts transaction
  2. System checks wallet remaining limits
  3. If insufficient → Block with error message
- **Edge Cases**:
  - Limit reset timing → Server time vs device time (requires clarification)

#### 3.2.3 Balance Tracking
- **Description**: Real-time wallet balance display
- **Goal**: Show current balance for each wallet
- **Mechanism**: balance field updated on each transaction
- **Edge Cases**:
  - Balance sync errors → Rollback mechanism needed

---

### Feature 3: Transaction Handling

#### 3.3.1 Create Transaction
- **Description**: Record send (debit) or receive (credit) transactions
- **Goal**: Log financial transactions tied to specific wallets
- **Target User**: Owners and permitted employees
- **Transaction Types**:
  - Debit (Send/Transfer)
  - Credit (Receive/Deposit)
  - Deposit (Balance top-up)
- **User Flow**:
  1. Select wallet
  2. Choose transaction type
  3. Enter customer phone, name (optional), amount
  4. System calculates commission and fees
  5. Confirm transaction
  6. System updates wallet balance + stats
- **Inputs**: Amount, customer phone, customer name, notes, payment status
- **Outputs**: Transaction record, updated wallet balance, updated stats
- **Edge Cases**:
  - Insufficient wallet balance → Block transaction
  - Limit exceeded → Block transaction
  - Network fee calculation → Service fee field

#### 3.3.2 Fee Calculation
- **Description**: Automatic commission calculation based on provider rules
- **Goal**: Accurate fee tracking
- **Mechanism**: TransactionFeeCalculator (confirmed in `domain/usecases/`)
- **Fee Types**:
  - Commission (store earnings)
  - Service Fee (network/provider charge)
- **Edge Cases**:
  - Fee rate changes → Requires update mechanism

#### 3.3.3 Transaction History
- **Description**: View past transactions with filtering
- **Goal**: Audit trail and history review
- **User Flow**:
  1. Navigate to transactions screen
  2. View today's transactions
  3. Filter by date, type, wallet
- **Edge Cases**:
  - Pagination for large datasets
  - Deleted transactions handling (soft delete confirmed)

---

### Feature 4: Debt Management

#### 3.4.1 Create Debt
- **Description**: Record unpaid transactions or store sales
- **Goal**: Track money owed to the store
- **Debt Types**:
  - Transaction Debt (unpaid transfer)
  - Store Sale Debt (direct sale)
- **User Flow**:
  1. Select "Create Debt"
  2. Enter customer name, phone, amount
  3. Choose debt type
  4. Add notes (optional)
  5. Save debt as "Open"
- **Edge Cases**:
  - Duplicate customer → Track separately

#### 3.4.2 Debt Status Management
- **Description**: Mark debts as paid or track partial payments
- **Goal**: Track payment progress
- **Status Types**:
  - Open
  - Paid
- **User Flow**:
  1. Select debt
  2. Option to mark fully paid or record partial payment
  3. Update debt status/amountDue

---

### Feature 5: Employee Management

#### 3.5.1 Add Employee
- **Description**: Create employee accounts
- **Goal**: Allow owner to delegate tasks
- **User Flow**:
  1. Navigate to employees screen
  2. Click "Add Employee"
  3. Enter name, phone
  4. System generates PIN
  5. Assign permissions
  6. Save employee
- **Permissions** (Confirmed from `UserPermissions`):
  - createTransaction
  - viewTransactions
  - createDebt
  - viewDebts
  - manageWallets
  - viewStatistics
- **Edge Cases**:
  - Employee limit reached → Block creation

#### 3.5.2 Employee Permissions
- **Description**: Granular permission configuration
- **Goal**: Restrict employee capabilities
- **Mechanism**: Permissions stored in employee document

---

### Feature 6: Subscription & Licensing

#### 3.6.1 Subscription Plans
- **Plans** (Confirmed from code):
  - Free (limited)
  - Trial (temporary)
  - Pro Yearly (paid)
  - Lifetime (paid)
- **Limits by Plan**:
  - maxWallets (e.g., 3 for free)
  - maxEmployees (e.g., 1 for free)
  - smsEnabled flag

#### 3.6.2 Subscription Validation
- **Description**: Check subscription status on login
- **Goal**: Enforce paid access
- **User Flow**:
  1. User attempts login
  2. System checks subscription endDate
  3. If expired → Redirect to paywall
  4. If suspended → Show admin block
- **Grace Period**: 48-hour grace after expiry (requires clarification on exact behavior)

#### 3.6.3 Payment Integration
- **Description**: Process subscription payments
- **Goal**: Monetization
- **Mechanism**: Payment modal + success detection
- **Implied**: External payment provider (not detailed in code)

---

### Feature 7: SMS Automation (Background Service)

#### 3.7.1 SMS Monitoring
- **Description**: Background service monitoring incoming SMS
- **Goal**: Automatically detect transaction notifications
- **Target User**: Store owners who enable this feature
- **Mechanism**:
  - `flutter_background_service` + `another_telephony`
  - Parses SMS from known wallet providers
  - Triggers overlay on new transaction
- **User Flow**:
  1. User enables SMS automation in settings
  2. Grant SMS and overlay permissions
  3. Background service runs even when app is killed
  4. On incoming transaction SMS:
     - Parse amount, sender, type
     - Show overlay window
     - Optionally log as transaction
- **Edge Cases**:
  - SMS parsing failures → Silent fail or notification
  - Permission revoked → Service stops

#### 3.7.2 Overlay Window
- **Description**: Quick transaction review overlay
- **Goal**: Quick transaction confirmation without opening app
- **Mechanism**: `flutter_overlay_window` with overlayMain entry point

---

### Feature 8: Statistics & Analytics

#### 3.8.1 Dashboard Overview
- **Description**: Real-time business summary
- **Goal**: Quick performance view
- **Metrics**:
  - Total balance across wallets
  - Today's transactions count
  - Today's commission earnings
  - Today's service fee earnings
  - Active debts count
- **User Flow**:
  1. Open app → Dashboard loads
  2. Display real-time stats

#### 3.8.2 Detailed Statistics
- **Description**: Filterable reports
- **Goal**: Business analysis
- **Features**:
  - Date range filtering
  - Transaction type breakdown
  - Wallet-specific stats

---

### Feature 9: Settings & Customization

#### 3.9.1 Localization
- **Languages**:
  - Arabic (ar) - Primary
  - English (en) - Secondary
- **Implementation**: `flutter_localizations` + `.arb` files
- **Direction**: RTL support for Arabic

#### 3.9.2 Theming
- **Modes**:
  - Light
  - Dark
  - System (device default)
- **Implementation**: ThemeProvider with `themeMode`

#### 3.9.3 Settings Options
- SMS automation toggle
- App information
- Logout

---

## 4. User Flows

### 4.1 Primary Owner Flow
```
[App Launch] → [Auth Check] → [Dashboard] → 
[Wallets/Transactions/Debts/Employees/Settings]
```

### 4.2 Transaction Creation Flow
```
[Select Wallet] → [Choose Type] → [Enter Details] → 
[Calculate Fees] → [Confirm] → [Update Balance] → [Show Success]
```

### 4.3 Employee Transaction Flow
```
[PIN Login] → [Filter by Permissions] → 
[Limited Actions Available] → [Audit Trail]
```

### 4.4 SMS Automation Flow
```
[Enable in Settings] → [Grant Permissions] → 
[Background Running] → [Incoming SMS] → 
[Parse] → [Show Overlay] → [Log Transaction]
```

---

## 5. Functional Requirements

### 5.1 Authentication
- [R01] The system must authenticate owners via email/password or Google Sign-In
- [R02] The system must authenticate employees via store email and PIN
- [R03] The system must validate subscription status on every login
- [R04] The system must block access when subscription is expired (non-lifetime)
- [R05] The system must show paywall for expired subscription

### 5.2 Wallet Management
- [R06] The system must support at least 6 wallet provider types
- [R07] The system must enforce daily transaction limits per wallet
- [R08] The system must enforce monthly transaction limits per wallet
- [R09] The system must prevent transactions exceeding wallet balance
- [R10] The system must track wallet balance in real-time

### 5.3 Transactions
- [R11] The system must record send (debit) transactions
- [R12] The system must record receive (credit) transactions
- [R13] The system must calculate commission based on amount and provider
- [R14] The system must calculate service fees
- [R15] The system must allow marking transactions as "debt" (unpaid)
- [R16] The system must provide transaction history with filtering

### 5.4 Debt Management
- [R17] The system must create debts from transactions or store sales
- [R18] The system must track debt status (open/paid)
- [R19] The system must allow partial payments

### 5.5 Employee Management
- [R20] The system must create employee accounts with PIN
- [R21] The system must allow granular permission configuration
- [R22] The system must enforce permissions on all actions

### 5.6 Statistics
- [R23] The system must display today's transaction count
- [R24] The system must display today's commission earnings
- [R25] The system must display today's service fee earnings
- [R26] The system must display active debts count

### 5.7 Subscription
- [R27] The system must enforce wallet limits based on subscription plan
- [R28] The system must enforce employee limits based on subscription plan
- [R29] The system must support trial, free, yearly, and lifetime plans

### 5.8 Background Service
- [R30] The system must monitor SMS when app is in background
- [R31] The system must monitor SMS when app is killed
- [R32] The system must show overlay on incoming transaction SMS
- [R33] The system must parse SMS from supported wallet providers

---

## 6. Non-Functional Requirements

### 6.1 Performance
- [N01] App should launch within 3 seconds (cold start)
- [N02] Transaction creation should complete within 2 seconds
- [N03] Statistics should load within 2 seconds

### 6.2 Reliability
- [N04] Wallet balance updates must be atomic (via Firestore transactions)
- [N05] Failed background writes must trigger rollback
- [N06] Optimistic UI must have rollback on failure

### 6.3 Security
- [N07] PINs must be hashed before storage
- [N08] passwords must be hashed
- [N09] Firestore rules must enforce owner/employee access per storeId
- [N10] Sensitive data access requires authentication

### 6.4 Scalability
- [N11] Support up to 999 wallets per store (lifetime plan)
- [N12] Support up to 999 employees per store (lifetime plan)
- [N13] Transaction history should support pagination

### 6.5 Platform
- [N14] Primary target: Android
- [N15] Secondary target: iOS
- [N16] Localization: Arabic (RTL) and English

---

## 7. Data Model

### 7.1 Core Entities

| Entity | Description | Key Fields |
|--------|-------------|------------|
| StoreModel | Business/store entity | storeId, storeName, ownerId, subscription, settings, stats |
| UserModel | Owner or employee | userId, storeId, role, fullName, pin, permissions, stats |
| WalletModel | Wallet configuration | walletId, storeId, phoneNumber, walletType, balance, sendLimits, receiveLimits, stats |
| TransactionModel | Financial transaction | transactionId, storeId, walletId, transactionType, amount, commission, serviceFee, paymentStatus, debtId |
| DebtModel | Customer debt | debtId, storeId, customerName, customerPhone, debtType, amountDue, totalAmount, debtStatus |
| StoreSubscription | License details | planId, status, endDate, trialConsumed, maxWallets, maxEmployees, smsEnabled |
| UserPermissions | Employee permissions | createTransaction, viewTransactions, createDebt, viewDebts, manageWallets, viewStatistics |

### 7.2 Firestore Collections
- `stores/` - Store documents
- `users/` - Owner and employee users
- `wallets/` - Wallet configurations
- `transactions/` - Transaction records
- `debts/` - Debt records
- `daily_stats/` - Daily aggregations
- `device_registrations/` - Device tracking
- `license_keys/` - License management
- `subscription_requests/` - Payment requests

### 7.3 Data Relationships
```
StoreModel (1) → (N) UserModel
StoreModel (1) → (N) WalletModel
StoreModel (1) → (N) TransactionModel
StoreModel (1) → (N) DebtModel
WalletModel (1) → (N) TransactionModel
TransactionModel (1) → (0/1) DebtModel
```

---

## 8. Assumptions & Unknowns

### 8.1 Assumptions (Based on Code)
- [A01] Transaction limits are reset based on calendar day/month (not rolling)
- [A02] Commission rates are hardcoded per provider type
- [A03] Payment processing is handled externally (not in codebase)
- [A04] SMS parsing supports major Egyptian wallet providers
- [A05] Date/time handling uses Africa/Cairo timezone

### 8.2 Unknowns (Not Clear from Code)
- [U01] Exact commission rates per provider (need documentation)
- [U02] Exact fee structure (service fees)
- [U03] Payment provider integration details
- [U04] Maximum failed login attempts before lockout
- [U05] Exact behavior of 48-hour grace period
- [U06] SMS parsing success rate expectations
- [U07] Data retention policy
- [U08] Multi-store support (future feature?)
- [U09] Export capabilities (CSV/PDF)
- [U10] Push notifications integration

---

## 9. Open Questions (REQUIRED BEFORE FINAL)

### 9.1 Business Logic
- Q1: What are the exact commission rates for each wallet provider?
- Q2: How are service fees calculated for each transaction type?
- Q3: What happens when a transaction limit is reached mid-transaction?

### 9.2 Subscription & Payments
- Q4: What payment providers are supported?
- Q5: How is the 48-hour grace period triggered and managed?
- Q6: What happens during trial period? Are all features available?

### 9.3 SMS Automation
- Q7: Which SMS formats are supported for parsing?
- Q8: What is the expected accuracy of SMS parsing?
- Q9: How does the user confirm parsed transactions?

### 9.4 Security
- Q10: Maximum failed login attempts before account lockout?
- Q11: Session timeout duration?
- Q12: PIN change policy (forced reset?)

### 9.5 Limits & Constraints
- Q13: Maximum transaction amount per type?
- Q14: Data retention period for transactions?
- Q15: Maximum debt record count?

### 9.6 User Experience
- Q16: Is there a walkthrough/onboarding for new users?
- Q17: What is the offline functionality scope?
- Q18: Are there customer-facing interfaces?

---

## 10. Final Summary

### 10.1 Product Summary
Wallet Manager is a production-ready Flutter mobile application for Egyptian store owners to manage digital wallets, transactions, debts, and employees. It provides real-time financial tracking, automatic limit enforcement, background SMS monitoring, and subscription-based access control.

### 10.2 Key Differentiators
- Multi-wallet provider support (6+ providers)
- Automatic transaction limit enforcement
- Background SMS monitoring and overlay
- Employee permission system
- Subscription licensing with trial

### 10.3 Technical Stack
- **Frontend**: Flutter (Dart)
- **Backend**: Firebase (Auth, Firestore, Analytics)
- **State Management**: Provider with SafeChangeNotifier
- **Architecture**: Clean Architecture
- **Background**: flutter_background_service + another_telephony

### 10.4 Gaps Identified
1. **Payment Integration**: Payment flow exists (UI) but provider not clear
2. **SMS Parsing**: No documented success rate or supported formats
3. **Commission Rates**: Not externalized (hardcoded?)
4. **Data Export**: No export capabilities found
5. **Multi-store**: Not supported in current version
6. **Offline Mode**: Limited (requires connectivity)

### 10.5Recommended Next Steps
1. Document all commission rates externally
2. Clarify payment provider integration
3. Add data export features
4. Consider multi-store support for future

---

*PRD Generated: May 2026*
*Source: Codebase Analysis*