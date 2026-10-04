# 📱 Wallet Manager

<p align="center">
  <img src="assets/images/app_icon.png" width="110" height="110" alt="Wallet Manager Logo" style="border-radius: 20%;" />
</p>

<p align="center">
  <b>A Production-Grade, Offline-First Mobile FinTech Solution for Egyptian Merchants</b><br>
  <i>Automate e-wallet transactions via background SMS parsing, native floating overlays, quota tracking, customer debt ledgers, and atomic cloud synchronization.</i>
</p>

<p align="center">
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter" /></a>
  <a href="https://dart.dev"><img src="https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart" /></a>
  <a href="https://firebase.google.com"><img src="https://img.shields.io/badge/Firebase-Firestore-FFCA28?style=for-the-badge&logo=firebase&logoColor=black" alt="Firebase" /></a>
  <img src="https://img.shields.io/badge/Architecture-Clean%20Architecture-4CAF50?style=for-the-badge" alt="Clean Architecture" />
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20iOS-informational?style=for-the-badge" alt="Platforms" />
  <a href="https://github.com/amrloulah-dev/wallet-manager-flutter/releases"><img src="https://img.shields.io/badge/Download-APK%20Release-blueviolet?style=for-the-badge&logo=android" alt="Download APK" /></a>
</p>

---

> **💡 نبذة عن المشروع بالعربية:**
> تطبيق مالي احترافي متكامل مبني بفلاتر ومصمم خصيصاً لأصحاب المتاجر ومنافذ الدفع الإلكتروني في مصر لإدارة محافظ الكاش (فودافون كاش، إنستاباي، أورنج كاش، اتصالات كاش، وي باي). يدعم استخراج المعاملات تلقائياً من الرسائل النصية القصيرة (SMS) عبر **Background Isolate** وإظهار نافذة عائمة فورية (**Native Floating Overlay Window**) لتسجيل العمليات وتحديث الأرصدة بضغطة زر دون الحاجة لفتح التطبيق، بالإضافة لدفتر كامل لحسابات الديون، وحساب نسب العمولات، ونظام صلاحيات دقيق للموظفين.

---

## 📑 Table of Contents

- [✨ Key Highlights](#-key-highlights)
- [📸 App Screenshots](#-app-screenshots)
- [🏗️ System Architecture](#️-system-architecture)
- [⚡ Engineering Deep Dive](#-engineering-deep-dive)
  - [1. Background SMS Guardian & Native Floating Overlay](#1-background-sms-guardian--native-floating-overlay)
  - [2. Optimistic UI & RAM-First State Management](#2-optimistic-ui--ram-first-state-management)
  - [3. Egyptian FinTech Quota & Fee Engine](#3-egyptian-fintech-quota--fee-engine)
  - [4. Atomic Cloud Firestore Transactions](#4-atomic-cloud-firestore-transactions)
- [🚀 Core Features](#-core-features)
- [🛠️ Tech Stack & Dependencies](#️-tech-stack--dependencies)
- [💻 Getting Started & Installation](#-getting-started--installation)
- [🧪 Testing & Quality Assurance](#-testing--quality-assurance)
- [👨‍💻 Author & Connect](#-author--connect)

---

## ✨ Key Highlights

- **🤖 Automatic SMS Parsing & Floating Overlay**: Detects incoming transaction SMS notifications in background isolates and immediately triggers a lightweight native floating overlay for 1-tap merchant confirmation.
- **⚡ Optimistic UI with Safe Rollbacks**: Instant RAM mutations with `SafeChangeNotifier`, $O(1)$ lookup maps, and automatic rollback on network anomalies.
- **🛡️ Egyptian E-Wallet Rules Engine**: Specialized quota tracking (daily and monthly limits) and automated tiered commission calculations for Vodafone Cash, InstaPay, Orange Cash, Etisalat Cash, and WE Pay.
- **📒 Customer Debt Ledger (دفتر الديون)**: Track open balances, partial installments, customer contact history, and settlement receipts.
- **🔒 Granular Multi-Tenant Access Control**: Owner accounts with Google/Email sign-in, plus high-security Cashier/Employee PIN accounts with restricted permissions.
- **🌐 Localization & Theming**: Complete bidirectional support for Arabic (RTL with Unicode LTR phone-number safeguards) and English, supporting Light and Dark modes.

---

## 📸 App Screenshots

<table align="center">
  <tr>
    <td align="center" width="20%">
      <b>Dashboard</b><br><br>
      <img src="assets/screenshots/Dashboard.png" width="100%" alt="Dashboard Screen" style="border-radius: 12px; box-shadow: 0 4px 8px rgba(0,0,0,0.15);" />
    </td>
    <td align="center" width="20%">
      <b>Wallets & Limits</b><br><br>
      <img src="assets/screenshots/wallets.png" width="100%" alt="Wallets Screen" style="border-radius: 12px; box-shadow: 0 4px 8px rgba(0,0,0,0.15);" />
    </td>
    <td align="center" width="20%">
      <b>Transactions</b><br><br>
      <img src="assets/screenshots/transactions.png" width="100%" alt="Transactions Screen" style="border-radius: 12px; box-shadow: 0 4px 8px rgba(0,0,0,0.15);" />
    </td>
    <td align="center" width="20%">
      <b>Customer Debts</b><br><br>
      <img src="assets/screenshots/debts.png" width="100%" alt="Debts Screen" style="border-radius: 12px; box-shadow: 0 4px 8px rgba(0,0,0,0.15);" />
    </td>
    <td align="center" width="20%">
      <b>Analytics & Stats</b><br><br>
      <img src="assets/screenshots/stats.png" width="100%" alt="Statistics Screen" style="border-radius: 12px; box-shadow: 0 4px 8px rgba(0,0,0,0.15);" />
    </td>
  </tr>
  <tr>
    <td align="center"><i>Live liquidity & quick actions</i></td>
    <td align="center"><i>Quotas, balances & limits</i></td>
    <td align="center"><i>Send/Receive transaction log</i></td>
    <td align="center"><i>Debt tracking & installments</i></td>
    <td align="center"><i>Financial charts & commissions</i></td>
  </tr>
</table>

---

## 🏗️ System Architecture

Wallet Manager strictly enforces **Clean Architecture** principles to separate concerns, improve testability, and isolate platform-specific native hooks.

```mermaid
flowchart TD
    subgraph Presentation ["Presentation Layer (Flutter)"]
        UI["Widgets & Screens (RTL/LTR, Themed)"]
        OverlayUI["Floating Overlay Window (Isolated UI)"]
        Providers["SafeChangeNotifier Providers (RAM Source of Truth)"]
    end

    subgraph Domain ["Domain Layer (Business Logic)"]
        UC["UseCases (OverlayUseCase, ProcessTransactionUseCase, etc.)"]
        Entities["Core Entities & Value Objects"]
        Rules["Egyptian Wallet Quota & Fee Calculators"]
    end

    subgraph Data ["Data Layer (Repositories & Data Sources)"]
        Repos["Repository Implementations"]
        Models["Data Models & Firestore Serializers"]
        FirestoreSvc["Cloud Firestore Service (Atomic Batches & Transactions)"]
        LocalSvc["LocalStorageService (Encrypted Storage & SharedPreferences)"]
    end

    subgraph Native ["Background & Native Channels"]
        Guardian["Guardian Background Service (another_telephony)"]
        IPC["IsolateNameServer / Cross-Isolate IPC"]
        SMSParser["Regex NLP SMS Parsing Pipeline"]
    end

    UI --> Providers
    Providers --> UC
    OverlayUI --> UC
    UC --> Repos
    Repos --> FirestoreSvc
    Repos --> LocalSvc
    Guardian --> SMSParser
    SMSParser --> IPC
    IPC --> OverlayUI
```

### Folder Structure Overview

```text
lib/
├── core/               # Shared utilities, DI (GetIt), AppTheme, ErrorHandler, L10n helpers
├── domain/             # Pure Dart UseCases, Entities, Business Rules & Contracts
├── data/               # Models, Repository implementations, Data Sources & Local Storage
├── presentation/       # UI Screens, Reusable Widgets, Dialogs & Overlay UI Entrypoints
├── providers/          # State Management extending SafeChangeNotifier
└── routes/             # App navigation routing & navigation services
```

---

## ⚡ Engineering Deep Dive

### 1. Background SMS Guardian & Native Floating Overlay

Egyptian payment providers (Vodafone Cash, InstaPay, Orange Cash, etc.) notify merchants via SMS upon money transfers. Wallet Manager listens to these SMS events seamlessly:

1. **Independent Background Isolate (`Guardian Isolate`)**: Operates continuously using `flutter_background_service` and `another_telephony`.
2. **Robust Multi-lingual NLP Extraction**: Strict anchor-based regex extracts amounts (handling Arabic/Hindi digits `٠-٩` and fractional decimal normalization) and extracts counterparties (prefixed mobile numbers `01[0125]\d{8}` or IPN/Bank handles).
3. **Native Window Orchestration**: Boots `flutter_overlay_window` with `@pragma("vm:entry-point") overlayMain()`. The floating window renders on top of POS/payment apps, pre-populating fields and requesting instant focus so the cashier can assign the transaction in 1 tap.

```mermaid
sequenceDiagram
    autonumber
    participant Tel as Telephony SMS Event
    participant G as Guardian Isolate
    participant SSOT as LocalStorage / Cache
    participant O as Overlay Window UI
    participant FS as Cloud Firestore

    Tel->>G: Incoming SMS (Vodafone / InstaPay)
    G->>G: Normalize Arabic Text & Extract (Amount, Sender)
    G->>SSOT: Save to Single-Item Active Cache (SSOT)
    G->>O: FlutterOverlayWindow.showOverlay()
    O->>SSOT: Read current active SMS
    O->>O: Render floating dialog & preselect fields
    Note over O: Cashier taps "Confirm"
    O->>FS: Fire-and-forget atomic Firestore write
    O->>SSOT: Purge active SMS cache
    O->>O: Dismiss Overlay Window
```

### 2. Optimistic UI & RAM-First State Management

To deliver instantaneous UI response in unreliable network environments:
- **`SafeChangeNotifier` Base Class**: Microtask-debounced dispatching prevents "rebuild during build" Flutter crashes and tracks disposal state.
- **$O(1)$ Hash Maps**: Providers store entities in `Map<String, Model>` indexed by IDs instead of linear lists.
- **Atomic Rollbacks**: Every optimistic mutation stores pre-state snapshot. If a background Firestore commit fails, the provider automatically reverts RAM state, alerts the user, and triggers a safe re-render.
- **Fetch Shield**: Automatically suppresses background auto-sync for 5 seconds post-injection to prevent overwriting fresh local changes with stale server snapshots.

### 3. Egyptian FinTech Quota & Fee Engine

- **Provider-Aware Quota Monitoring**: Enforces strict daily and monthly transaction limits per Egyptian Central Bank guidelines for each registered line.
- **Automated Service Fee Calculus**: Dynamic fee logic calculates tier-based fees, percentage deductions, or flat operational costs automatically, ensuring RAM financial parity between `WalletProvider` and `StatisticsProvider`.

### 4. Atomic Cloud Firestore Transactions

All multi-document mutations (e.g., executing a transaction that modifies a wallet balance, updates store statistics, and increments customer debt) run inside `_firestore.runTransaction` blocks:
- **Read-Before-Write Compliance**: Strict adherence to Firestore transaction rules where all queries and document reads precede any mutation calls.
- **Atomic Aggregation Counters**: Daily and total financial metrics utilize `FieldValue.increment(delta)` to prevent race conditions during high-volume cashier usage.

---

## 🚀 Core Features

| Feature | Description |
| :--- | :--- |
| **👛 Multi-Wallet Hub** | Track Vodafone Cash, InstaPay, Orange Cash, Etisalat Cash, and WE Pay balances and limit quotas in real time. |
| **⚡ Instant Transactions** | Fast recording of Send / Receive transfers with automatic commission calculation and instant balance deduction. |
| **📖 Debt Ledger (دفتر الديون)** | Manage credit accounts for clients, register partial settlements, and monitor customer debts linked directly to transactions. |
| **👥 Dual-Tier Access Control** | Dedicated Store Owner login alongside PIN-protected Cashier profiles with granular permission toggles. |
| **📊 Advanced Financial Analytics** | Real-time statistics tracking net volume, daily profits, commission earnings, and historical date range filtering. |
| **🌐 Full Arabic & English Support** | Native RTL layouts with localized Arabic numerals and Unicode LTR guarding (`\u200E`) to eliminate reversed phone numbers. |
| **🌓 Dynamic Theming** | System-adaptive Light and Dark modes built with dynamic `AppColors` tokens. |

---

## 🛠️ Tech Stack & Dependencies

- **Core Framework:** [Flutter](https://flutter.dev) (Dart 3.x)
- **Backend & Cloud Services:**
  - Firebase Authentication (Google Sign-In, Email/Password)
  - Cloud Firestore (NoSQL, Atomic Transactions, Offline Persistence)
  - Firebase Analytics, Crashlytics & Performance Monitoring
- **State Management:** `provider` (Scoped `Selector`, `ChangeNotifierProxyProvider`, `SafeChangeNotifier`)
- **Native & Background Services:**
  - `flutter_background_service` (Persistent background isolation)
  - `flutter_overlay_window` (System alert floating UI)
  - `another_telephony` (SMS reception & incoming broadcast receiver)
- **Dependency Injection:** `get_it` (Service Locator with idempotency guards)
- **Local Persistence & Security:**
  - `flutter_secure_storage` (Biometric & PIN hardware-backed storage)
  - `shared_preferences` (Fast multi-isolate configuration cache)
  - `cryptography` & `bcrypt` (Secure PIN hashing)
- **Internationalization:** `flutter_localizations`, `intl` (AR/EN `.arb` translation architecture)

---

## 💻 Getting Started & Installation

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (`>= 3.0.0`)
- [Android Studio](https://developer.android.com/studio) or VS Code
- Android Device running Android 8.0+ (Required for testing SMS permissions & native overlay features)
- A configured [Firebase Project](https://console.firebase.google.com/)

### Local Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/amrloulah-dev/wallet-manager-flutter.git
   cd wallet-manager-flutter
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase:**
   - Place your `google-services.json` inside `android/app/`.
   - Place your `GoogleService-Info.plist` inside `ios/Runner/` (if targeting iOS).

4. **Generate localization files:**
   ```bash
   flutter gen-l10n
   ```

5. **Run the application:**
   ```bash
   flutter run
   ```

---

## 🧪 Testing & Quality Assurance

Wallet Manager includes unit tests, widget tests, and repository tests leveraging `mocktail` and `fake_cloud_firestore` to guarantee 100% financial calculation accuracy without requiring live Firebase emulators.

```bash
# Run the entire test suite
flutter test

# Run tests in non-interactive CI mode
CI=true flutter test

# Verify static analysis & code health
flutter analyze

# Format code
dart format .
```

---

## 👨‍💻 Author & Connect

**Amr Loulah**  
*Senior Flutter & Mobile Application Engineer*

<p align="left">
  <a href="https://github.com/amrloulah-dev">
    <img src="https://img.shields.io/badge/GitHub-amrloulah--dev-181717?style=for-the-badge&logo=github" alt="GitHub Profile" />
  </a>
  <a href="https://linkedin.com/in/amr-loulah">
    <img src="https://img.shields.io/badge/LinkedIn-Amr%20Loulah-0A66C2?style=for-the-badge&logo=linkedin" alt="LinkedIn Profile" />
  </a>
  <a href="mailto:amrloulah@gmail.com">
    <img src="https://img.shields.io/badge/Email-Contact%20Me-EA4335?style=for-the-badge&logo=gmail&logoColor=white" alt="Email Contact" />
  </a>
</p>

> 🤝 **Open to Opportunities & Collaborations:**  
> Feel free to explore the repository, open an issue, submit a pull request, or reach out for mobile engineering roles and FinTech consulting!

---

<p align="center">
  <sub>Built with ❤️ and Dart in Egypt. Licensed under the <a href="LICENSE">MIT License</a>.</sub>
</p>