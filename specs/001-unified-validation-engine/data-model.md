# Phase 1: Data Model

## Entities

### Transaction
No schema changes, but strict invariants must be maintained before save:
- `amount` > 0
- `fee` is correctly pre-calculated based on limits and network rules
- `type`: Must be one of the known enums (e.g., Transfer)

### Wallet
- `balance`: `double` (must remain >= 0 if sending)
- `capacity limits`: Enforced dynamically in the `TransactionValidatorService` based on wallet status ('new', 'old', 'registered_store') and type (InstaPay vs Telecom).

## State Transitions
1. `Pending` (Overlay opens): Prior data cleared, new validation and fee logic is executed.
2. `Validating` (User clicks Confirm): Transaction routed to `TransactionValidatorService` for full lifecycle execution.
3. `Committed`: Valid transaction persists to Firestore using Atomic `runTransaction`.
4. `Broadcasted`: `WalletProvider` updates the `WalletCard` immediately via its real-time stream subscription to the Firestore document.
