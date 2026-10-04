enum TransactionType {
  credit, // Deposit/Receive
  debit, // Transfer/Send
}

class ParsedSmsDto {
  final double amount;
  final TransactionType type;
  final String? counterpartyNumber; // Nullable for Bank/IPN messages
  final String serviceProvider; // e.g., 'Vodafone Cash', 'IPN'
  final String originalBody;

  const ParsedSmsDto({
    required this.amount,
    required this.type,
    this.counterpartyNumber,
    required this.serviceProvider,
    required this.originalBody,
  });

  @override
  String toString() {
    return 'ParsedSmsDto(amount: $amount, type: $type, counterparty: $counterpartyNumber, provider: $serviceProvider)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ParsedSmsDto &&
        other.amount == amount &&
        other.type == type &&
        other.counterpartyNumber == counterpartyNumber &&
        other.serviceProvider == serviceProvider &&
        other.originalBody == originalBody;
  }

  @override
  int get hashCode {
    return amount.hashCode ^
        type.hashCode ^
        counterpartyNumber.hashCode ^
        serviceProvider.hashCode ^
        originalBody.hashCode;
  }
}
