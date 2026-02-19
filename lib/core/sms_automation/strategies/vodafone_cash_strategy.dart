import '../models/parsed_sms_dto.dart';
import 'sms_parser_strategy.dart';

class VodafoneCashStrategy extends SmsParserStrategy {
  // Trigger Senders: 'VF-Cash', 'Vodafone', 'vfcash' (Case insensitive)
  static final Set<String> _triggers = {'vf-cash', 'vodafone', 'vfcash'};

  @override
  bool canParse(String sender) {
    return _triggers.contains(sender.toLowerCase());
  }

  @override
  ParsedSmsDto? parse(String normalizedBody) {
    // Keywords Check: Must contain "مبلغ" AND ("استلام" OR "تحويل")
    if (!normalizedBody.contains('مبلغ')) return null;
    if (!normalizedBody.contains('استلام') &&
        !normalizedBody.contains('تحويل')) {
      return null;
    }

    // Try Receive (Deposit)
    final receiveRegex = RegExp(
        r'تم\s+استلام\s+مبلغ\s*(?<amount>[\d\.,]+)\s*جنيه.*?من\s+رقم\s*(?<number>\d+)');
    final receiveMatch = receiveRegex.firstMatch(normalizedBody);
    if (receiveMatch != null) {
      final amountStr = receiveMatch.namedGroup('amount')?.replaceAll(',', '');
      final number = receiveMatch.namedGroup('number');
      if (amountStr != null) {
        try {
          final amount = double.parse(amountStr);
          return ParsedSmsDto(
            amount: amount,
            type: TransactionType.credit,
            counterpartyNumber: number,
            serviceProvider: 'Vodafone Cash',
            originalBody: normalizedBody,
          );
        } catch (_) {}
      }
    }

    // Try Send (Transfer)
    final sendRegex = RegExp(
        r'تم\s+تحويل\s+مبلغ\s*(?<amount>[\d\.,]+)\s*جنيه.*?الى\s+رقم\s*(?<number>\d+)');
    final sendMatch = sendRegex.firstMatch(normalizedBody);
    if (sendMatch != null) {
      final amountStr = sendMatch.namedGroup('amount')?.replaceAll(',', '');
      final number = sendMatch.namedGroup('number');
      if (amountStr != null) {
        try {
          final amount = double.parse(amountStr);
          return ParsedSmsDto(
            amount: amount,
            type: TransactionType.debit,
            counterpartyNumber: number,
            serviceProvider: 'Vodafone Cash',
            originalBody: normalizedBody,
          );
        } catch (_) {}
      }
    }

    return null;
  }
}
