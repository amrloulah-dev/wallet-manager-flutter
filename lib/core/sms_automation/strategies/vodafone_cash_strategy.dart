import '../../errors/app_error_handler.dart';
import '../models/parsed_sms_dto.dart';
import 'sms_parser_strategy.dart';

class VodafoneCashStrategy extends SmsParserStrategy {
  // Trigger Senders: 'VF-Cash', 'Vodafone', 'vfcash', Arabic triggers (Case insensitive)
  static final Set<String> _triggers = {
    'vf-cash',
    'vodafone',
    'vfcash',
    'فودافون',
    'فودافونكاش',
    'فودافون كاش',
  };

  @override
  bool canParse(String sender) {
    final lower = sender.toLowerCase().trim();
    if (_triggers.contains(lower) ||
        _triggers.contains(lower.replaceAll(' ', '').replaceAll('_', ''))) {
      return true;
    }

    return false;
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
    // 1. Amount before Number: e.g. "تم استلام مبلغ 1000 جنيه من رقم 01012345678" or "وصلك 500 من 01012345678"
    final arabicReceiveAmountFirst = RegExp(
        r'(?:استلام|وصل|وصلك|ايداع|تم ايداع|تحويل من)(?:(?!رصيد|رصيدك|متاح).)*?(?:مبلغ)?\s*(?<amount>\d+(?:[\.,]\d+)?)\s*(?:جنيه|ج\.م)?.*?(?:محول من رقم|محول من|من رقم|منه|من)\s*(?<number>01[0125]\d{8})');

    // 2. Number before Amount: e.g. "محول من 01234567890 مبلغ 2500" or "من 01012345678 مبلغ 100"
    final arabicReceiveNumberFirst = RegExp(
        r'(?:محول من رقم|محول من|من رقم|من)\s*(?<number>01[0125]\d{8})(?:(?!رصيد|رصيدك|متاح).)*?(?:مبلغ)?\s*(?<amount>\d+(?:[\.,]\d+)?)');

    final englishReceiveRegex = RegExp(
        r'(?:received)(?:(?!balance).)*?(?<amount>\d+(?:[\.,]\d+)?)\s*(?:egp|le)?.*?(?:from)\s*(?<number>01[0125]\d{8})');

    final receiveMatch = arabicReceiveAmountFirst.firstMatch(normalizedBody) ??
        arabicReceiveNumberFirst.firstMatch(normalizedBody) ??
        englishReceiveRegex.firstMatch(normalizedBody);

    if (receiveMatch != null) {
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
    // 1. Amount before Number: e.g. "تم تحويل مبلغ 50.50 جنيه إلى 01012345678" or "ارسال 200 ل 01012345678"
    final arabicSendAmountFirst = RegExp(
        r'(?:ارسال|تم ارسال|تحويل الى|تحويل إلي|تحويل الي|تحويل ل|تم تحويل|دفع)(?:(?!رصيد|رصيدك|متاح).)*?(?:مبلغ)?\s*(?<amount>\d+(?:[\.,]\d+)?)\s*(?:جنيه|ج\.م)?.*?(?:إلى رقم|الى رقم|الي رقم|إلي رقم|لرقم|محول إلى|محول الى|محول الي|إضافة إلى|اضافة الى|اضافة الي|إلى|الى|الي|إلي|ل)\s*(?<number>01[0125]\d{8})');

    // 2. Number before Amount: e.g. "إلى 01012345678 مبلغ 50.50"
    final arabicSendNumberFirst = RegExp(
        r'(?:إلى رقم|الى رقم|الي رقم|إلي رقم|لرقم|محول إلى|محول الى|محول الي|إضافة إلى|اضافة الى|اضافة الي|إلى|الى|الي|إلي|ل)\s*(?<number>01[0125]\d{8})(?:(?!رصيد|رصيدك|متاح).)*?(?:مبلغ)?\s*(?<amount>\d+(?:[\.,]\d+)?)');

    final englishSendRegex = RegExp(
        r'(?:sent|send|transfer|transferred|paid)(?:(?!balance).)*?(?<amount>\d+(?:[\.,]\d+)?)\s*(?:egp|le)?.*?(?:to)\s*(?<number>01[0125]\d{8})');

    final sendMatch = arabicSendAmountFirst.firstMatch(normalizedBody) ??
        arabicSendNumberFirst.firstMatch(normalizedBody) ??
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
