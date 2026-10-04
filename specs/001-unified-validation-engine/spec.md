# Specification: Unified Validation Engine

## 1. Summary
The application currently suffers from data integrity issues because background processes (like the SMS Overlay) bypass core business rules and write directly to the database. Additionally, UI state leaks between transaction sessions, and the main dashboard does not react in real-time to background updates. The Unified Validation Engine feature centralizes all financial validation logic through a single gatekeeper, enforces strict atomic database operations to prevent negative balances, automatically calculates and pre-fills fee data based on wallet type and amount, and ensures the entire application stays reactive to data changes across all screens.

## Clarifications

### Session 2026-03-21
- Q: What should happen in the overlay UI if the background Firebase transaction fails due to a network error or connection timeout? → A: Option B - Show a temporary `bot_toast` error and allow the user to tap "Confirm" again to retry.

## 2. Actors & Target Audience
- **End Users**: Benefiting from real-time balance updates, accurate fee calculation in the overlay, and a bug-free experience (no state leakage).
- **System**: Background services that automatically process SMS limits without bypassing business rules.

## 3. User Scenarios & Testing
- **Scenario 1: Opening the SMS Overlay for a new transaction**
  - Given the user receives an SMS about a transaction and the overlay appears,
  - When the overlay opens,
  - Then all previous transaction states (like commission) are cleared, and the new commission is automatically calculated and pre-filled based on the detected wallet type and amount.

- **Scenario 2: Creating a transaction from within the main app**
  - Given the user is on the manual transaction entry screen,
  - When they click "Save",
  - Then the transaction is validated against the positive amount rule, wallet balance sufficiency, and wallet capacity limits before being saved.

- **Scenario 3: Exceeding capacity limits**
  - Given a user has an 'old' wallet with a 60,000 EGP single transaction limit,
  - When they attempt to receive or send 65,000 EGP,
  - Then the transaction is blocked, an error is returned by the validation engine, and the UI displays the appropriate warning.

- **Scenario 4: Real-time UI updates**
  - Given the user has the main app open on the Dashboard,
  - When a background SMS overlay successfully validates and saves a transaction,
  - Then the WalletCard balances and daily limits update immediately without manual refresh.

## 4. Functional Requirements
- **FR1: Centralized Gatekeeping** -- All transaction creation requests (from Manual Entry or SMS Overlay) must route through a centralized service. Direct database writes from UI files are prohibited.
- **FR2: Rule Enforcement** -- The validation service must enforce:
  - Positive Amount Rule (amount > 0).
  - Balance Sufficiency Rule (sender balance >= amount).
  - Wallet Capacity Limits for 'new', 'old', and 'registered_store' wallets.
  - Network-specific overrides (InstaPay, Telecom).
- **FR3: Atomic Transactions** -- The validation service must use atomic transactions for all financial records to ensure race conditions do not lead to negative balances.
- **FR4: Overlay State Management** -- The SMS Overlay must clear previous transaction variables upon opening and auto-inject the correct commission fee calculated based on the transaction attributes.
- **FR5: Reactive Main UI** -- The main dashboard component (specifically the WalletCard) must subscribe to real-time data streams to immediately reflect balance and limit changes executed by background processes.
- **FR6: Overlay Error Handling** -- If the `TransactionValidatorService` fails to save a transaction (e.g., due to network error or validation failure) originating from the SMS Overlay, the application must display a temporary error toast (`bot_toast`) and keep the overlay open for the user to quickly correct or retry via the "Confirm" button.

## 5. Success Criteria
- 100% of new transactions (manual or auto) pass through the centralized validation engine.
- 0 incidents of negative wallet balances due to race conditions.
- Commission field is always accurately pre-filled or reset to 0 in the overlay upon launch.
- Wallet balances visually update within 2 seconds of an overlay transaction completing.
- The UI contains no hardcoded financial limit values (they strictly interface with the centralized rules).

## 6. Key Entities
- **TransactionValidatorService**: New core service coordinating validation and saves.
- **FeeCalculator**: Existing utility used to generate default commission fees.
- **WalletCard**: UI component upgraded from one-time reads to streaming updates.
- **Transaction**: The domain entity validated against business rules.

## 7. Assumptions & Dependencies
- Assumes Firebase Firestore transaction capabilities are accessible from the background isolate (Overlay service).
- Assumes the existing FeeCalculator implementation produces the fees specified in the business rules document.
- Assumes the 'awesome_dialog' and 'bot_toast' configurations from the constitution are applied to validation failures.
