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
    // Gatekeeper Clause: Fast fail if message lacks a valid Egyptian mobile number
    // We strictly check for an 11-digit number starting with 010, 011, 012, or 015
    // This safely filters out ATM withdrawals and bill payments without failing on valid English messages.
    if (!RegExp(r'01[0125]\d{8}').hasMatch(normalizedBody)) {
      return null;
    }

    // --- Receive (Credit / Deposit) ---
    final arabicReceiveRegex = RegExp(
        r'(استلام|ارسال|تحويل|ايداع).*?(مبلغ)?\s*(?<amount>[\d\.,]+)\s*(جنيه|ج\.م)?.*?(من\s*رقم)\s*(?<number>01[0125]\d{8})');
    final englishReceiveRegex = RegExp(
        r'(received).*?(?<amount>[\d\.,]+)\s*(egp|le).*?(from)\s*(?<number>01[0125]\d{8})');

    final receiveMatch = arabicReceiveRegex.firstMatch(normalizedBody) ??
        englishReceiveRegex.firstMatch(normalizedBody);

    if (receiveMatch != null) {
      // Replace any internal commas with dots for valid double parsing
      final amountStr = receiveMatch.namedGroup('amount')?.replaceAll(',', '.');
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

    // --- Send (Debit / Transfer / Payment) ---
    final arabicSendRegex = RegExp(
        r'(ارسال|تحويل|دفع).*?(مبلغ)?\s*(?<amount>[\d\.,]+)\s*(جنيه|ج\.م)?.*?(الي|الى|ل|لرقم)\s*(رقم)?\s*(?<number>01[0125]\d{8})');
    final englishSendRegex = RegExp(
        r'(sent|send|transfer|transferred).*?(?<amount>[\d\.,]+)\s*(egp|le).*?(to)\s*(?<number>01[0125]\d{8})');

    final sendMatch = arabicSendRegex.firstMatch(normalizedBody) ??
        englishSendRegex.firstMatch(normalizedBody);

    if (sendMatch != null) {
      final amountStr = sendMatch.namedGroup('amount')?.replaceAll(',', '.');
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
