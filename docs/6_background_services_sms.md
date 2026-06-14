# ⚙️ Report 6: Background Services & SMS Automation

## 1. Background Engine & Native Packages

The background processing architecture strictly separates UI concerns from SMS interception by utilizing an independent "Guardian Isolate". 

**Core Packages Used:**
- `flutter_background_service`: Manages the persistent lifecycle of the Guardian Isolate. It runs as a `ForegroundService` with `foregroundServiceType="dataSync"`.
- `another_telephony`: Binds to the native Android `BROADCAST_SMS` intent, parsing incoming texts and firing Dart callbacks.
- `flutter_overlay_window`: Renders a system-level alert window (floating UI) over other applications to allow instant transaction logging.
- `flutter_local_notifications`: Used specifically to send high-priority intents to wake the device screen from sleep.

**Guardian Isolate Instantiation & Independence:**
The Guardian Isolate is launched via `initializeBackgroundService()` in `main.dart`. Once started, it operates in a completely independent memory space from the main Flutter UI thread. It re-initializes Firebase, Dependency Injection (`GetIt`), and `LocalStorageService` to be entirely self-sufficient. It communicates with the UI solely through `SharedPreferences` (the "Vault") and `FlutterOverlayWindow.shareData`, completely eliminating the need for complex Isolate ports.

## 2. OS Permissions & Device Constraints

**Required Native Permissions (`AndroidManifest.xml`):**
- `RECEIVE_SMS` / `READ_SMS`: Core interception.
- `SYSTEM_ALERT_WINDOW`: Required by `flutter_overlay_window`.
- `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_DATA_SYNC`: Keeps the process alive.
- `WAKE_LOCK` / `USE_FULL_SCREEN_INTENT`: Crucial for forcing the device screen on.
- `RECEIVE_BOOT_COMPLETED`: Restarts the service upon device reboot.

**Handling OS Constraints (Doze Mode & OEM Restrictions):**
- **Battery Optimization Bypass:** The `SmsService` aggressively prompts the user via `Permission.ignoreBatteryOptimizations` to whitelist the app from Android Doze mode.
- **Strict UI Thread Enforcement:** The system strictly enforces `_guardIsolate()` to ensure permission dialogs are *only* launched from the main UI thread. Attempting to trigger dialogs from the background crashes the isolate.
- **OEM SIM Restrictions (Smart Fallback):** Restrictive OEMs (Huawei, Xiaomi) often block dynamic access to the SIM slot (`NOT_ACCESSIBLE_ON_THIS_OS_PLATFORM`). If `another_telephony` fails to read the SIM index, the system runs a "Smart Fallback": if the user only has one unique wallet ID mapped to SIMs, it auto-selects that wallet regardless of which slot received the SMS.

## 3. SMS Automation Triggers & Lifecycle

**Business Events Triggering Automation:**
SMS automation is gated by several strict business rules:
1. The user must have toggled "SMS Automation" ON.
2. The subscription must not be suspended.
3. The subscription tier must have `smsEnabled == true`.
4. The subscription must not be expired.
5. **Staleness Check:** If the app hasn't synced subscription data with Firebase in >24 hours, the automation blocks parsing and instead fires a `Stale Sync Notification` prompting the user to open the app.

**Lifecycle of a Message:**
1. **Interception:** `another_telephony` catches the broadcast intent.
2. **Parsing:** Passed to `SmsParserEngine`, normalized, and delegated to the Strategy pattern (`VodafoneCashStrategy`, `GenericBankStrategy`).
3. **Data Extraction:** RegEx extracts amount, type (credit/debit), and counterparty number.
4. **Vault Storage:** The `ParsedSmsDto` is written immediately to `SharedPreferences` to persist it in case of an overlay crash.
5. **Screen Wake:** `_showWakeUpNotification` fires a `Priority.max` alarm category notification to force the lock screen to illuminate.
6. **Overlay Render:** `FlutterOverlayWindow.showOverlay` or `shareData` is invoked, presenting the "New Transaction" popup.

**Regex Templates Used:**
- **Vodafone Cash (Credit):** 
  - Arabic: `(استلام|ارسال|تحويل|ايداع).*?(مبلغ)?\s*(?<amount>[\d\.,]+)\s*(جنيه|ج\.م)?.*?(من\s*رقم)\s*(?<number>01[0125]\d{8})`
  - English: `(received).*?(?<amount>[\d\.,]+)\s*(egp|le).*?(from)\s*(?<number>01[0125]\d{8})`
- **Vodafone Cash (Debit):**
  - Arabic: `(ارسال|تحويل|دفع).*?(مبلغ)?\s*(?<amount>[\d\.,]+)\s*(جنيه|ج\.م)?.*?(الي|الى|ل|لرقم)\s*(رقم)?\s*(?<number>01[0125]\d{8})`
- **Generic Bank/IPN:**
  - Pattern: `transfer (received|sent).*?amount of egp\s*(?<amount>[\d\.,]+)`

## 4. Error Handling & Reliability Logic

**Cold-Start Resiliency:**
If the application is fully killed by the OS, `another_telephony` spins up a temporary cold-start isolate via `backgroundSmsCallback`. This function meticulously wraps `Firebase.initializeApp()` in a `try-catch` block. Because `Crashlytics` requires a valid Firebase instance, if initialization fails at this fundamental level, the system falls back to `AppErrorHandler.logSilentError` without bringing down the OS broadcast pipeline.

**Format Resiliency:**
To prevent malformed numbers from crashing the parser (e.g., `1,000.50`), the logic executes `sanitizedAmountStr.replaceAll(',', '').trim()` before executing `double.tryParse`.

**Isolate Hardening:**
The entire pipeline inside `handleIncomingSms` and `backgroundSmsCallback` is wrapped in a top-level `try-catch` that intentionally swallows errors after logging them. Background isolates in Flutter *must never crash*, as crashing can cause the OS to permanently blacklist the application's background execution privileges.
