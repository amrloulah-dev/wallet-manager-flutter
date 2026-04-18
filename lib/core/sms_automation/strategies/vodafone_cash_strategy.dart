import '../../errors/app_error_handler.dart';
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
      // Replace any internal commas with empty for valid double parsing (e.g. 1,000 -> 1000)
      final rawAmount = receiveMatch.namedGroup('amount');
      final number = receiveMatch.namedGroup('number');
      if (rawAmount != null) {
        final sanitizedAmountStr = rawAmount.replaceAll(',', '').trim();
        final amount = double.tryParse(sanitizedAmountStr);
        
        if (amount != null) {
          return ParsedSmsDto(
            amount: amount,
            type: TransactionType.credit,
            counterpartyNumber: number,
            serviceProvider: 'Vodafone Cash',
            originalBody: normalizedBody,
          );
        } else {
          AppErrorHandler.logSilentError(
            'Failed to parse amount: $rawAmount from SMS',
            'VodafoneCashStrategy_Receive',
          );
        }
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
      final rawAmount = sendMatch.namedGroup('amount');
      final number = sendMatch.namedGroup('number');
      if (rawAmount != null) {
        final sanitizedAmountStr = rawAmount.replaceAll(',', '').trim();
        final amount = double.tryParse(sanitizedAmountStr);

        if (amount != null) {
          return ParsedSmsDto(
            amount: amount,
            type: TransactionType.debit,
            counterpartyNumber: number,
            serviceProvider: 'Vodafone Cash',
            originalBody: normalizedBody,
          );
        } else {
          AppErrorHandler.logSilentError(
            'Failed to parse amount: $rawAmount from SMS',
            'VodafoneCashStrategy_Send',
          );
        }
      }
    }

    return null;
  }
}
