# Phase 1: Quickstart

## Implementing the Unified Validation Engine

**Validation Usage:**
Any screen (Manual entry or Overlay Background) MUST pass their transactions into `TransactionValidatorService` instead of directly calling Firestore.

```dart
final validator = TransactionValidatorService();

try {
  await validator.validateAndSave(
    walletId: selectedWallet.id,
    amount: transactionAmount,
    transactionType: type,
    fee: preCalculatedFee,
    network: destinationNetwork,
  );
  BotToast.showText(text: "Transaction saved successfully");
} catch (e) {
  // If in overlay:
  BotToast.showText(text: e.toString());
  
  // If in manual entry (foreground UI):
  AwesomeDialog(
    context: context,
    dialogType: DialogType.error,
    title: 'Validation Error',
    desc: e.toString(),
  ).show();
}
```

**State Clearing in Overlay:**
When the overlay is triggered via SMS, you MUST forcefully clear provider values:

```dart
// Within overlay_provider.dart or init logic
void _resetOverlayState() {
  currentCommission = null;
  currentAmount = null;
  // Calculate default using FeeCalculator based on incoming SMS details
  currentCommission = FeeCalculator.calculateFee(amount: detectedAmount, type: detectedType);
  notifyListeners();
}
```
