import '../../errors/app_error_handler.dart';
import '../models/parsed_sms_dto.dart';
import '../utils/bank_constants.dart';
import 'sms_parser_strategy.dart';

class GenericBankStrategy extends SmsParserStrategy {
  @override
  bool canParse(String sender) {
    // 1. Normalize the sender for comparison (remove +20, spaces, dashes)
    String normalizedSender =
        sender.replaceAll(RegExp(r'[^\d]'), ''); // leaves only digits
    if (normalizedSender.startsWith('20')) {
      normalizedSender =
          normalizedSender.substring(2); // remove 20 -> becomes 10xxxxxxxxx
    }
    if (normalizedSender.startsWith('0')) {
      normalizedSender = normalizedSender
          .substring(1); // remove leading 0 -> becomes 10xxxxxxxxx
    }

    // 2. Egyptian mobile number check (+201..., 01..., 1...)
    if (normalizedSender.length == 10 &&
        RegExp(r'^1[0125]\d{8}$').hasMatch(normalizedSender)) {
      return true;
    }

    final upperSender = sender.toUpperCase().trim();
    if (BankConstants.supportedBankSenders.contains(upperSender) ||
        upperSender.contains("IPN") ||
        upperSender.contains("INSTAPAY")) {
      return true;
    }

    // Arabic aggregator / bank sender names
    final trimmed = sender.trim();
    if (trimmed.contains("انستاباي") ||
        trimmed.contains("إنستاباي") ||
        trimmed.contains("انستا باي") ||
        trimmed.contains("إنستا باي")) {
      return true;
    }

    return false;
  }

  @override
  ParsedSmsDto? parse(String normalizedBody) {
    // Try to extract counterparty phone number if present in body
    String? counterpartyNumber;
    final phoneMatch = RegExp(r'01[0125]\d{8}').firstMatch(normalizedBody);
    if (phoneMatch != null) {
      counterpartyNumber = phoneMatch.group(0);
    }

    // ── Receive (Credit / Deposit / Incoming Transfer) ──
    // 1. Account destination: e.g. "تم تحويل مبلغ 1500.50 ج.م لحسابكم"
    final creditAccountRegex = RegExp(
      r'(?:تحويل)(?:(?!رصيد|رصيدك|متاح).)*?(?:مبلغ|بمبلغ)?\s*(?<amount>\d+(?:[\.,]\d+)?).*?(?:لحسابكم|لحسابك|في حسابكم|في حسابك|الي حسابك|إلى حسابك|الي حسابكم|إلى حسابكم)',
      caseSensitive: false,
    );

    // 2. Transfer from specific number: e.g. "تم تحويل من 01012345678 مبلغ 400.00" or "محول من 01234567890 مبلغ 2500"
    final creditFromNumberRegex = RegExp(
      r'(?:تحويل من|محول من|من)\s*(?:رقم)?\s*(?<number>01[0125]\d{8})(?:(?!رصيد|رصيدك|متاح).)*?(?:مبلغ|بمبلغ)?\s*(?<amount>\d+(?:[\.,]\d+)?)',
      caseSensitive: false,
    );

    // 3. Deposit / Addition / Inward keywords: e.g. "تم ايداع مبلغ 3000" or "تم اضافة مبلغ 1200"
    final creditArabicRegex = RegExp(
      r'(?:استلام|ايداع|إيداع|تم ايداع|تم إيداع|اضافة|إضافة|تم اضافة|تم إضافة|وارد|وصلك|وصل)(?:(?!رصيد|رصيدك|متاح).)*?(?:مبلغ|بمبلغ)?\s*(?<amount>\d+(?:[\.,]\d+)?)',
      caseSensitive: false,
    );

    // 4. English Receive: e.g. "Transfer Received. Amount of EGP 5000.00"
    final creditEnglishRegex = RegExp(
      r'(?:transfer received|received|deposit|credited)(?:(?!balance).)*?(?:amount of egp|amount of|amount|egp|le|\:)?\s*(?<amount>\d+(?:[\.,]\d+)?)',
      caseSensitive: false,
    );

    final creditMatch = creditAccountRegex.firstMatch(normalizedBody) ??
        creditFromNumberRegex.firstMatch(normalizedBody) ??
        creditArabicRegex.firstMatch(normalizedBody) ??
        creditEnglishRegex.firstMatch(normalizedBody);

    if (creditMatch != null) {
      final rawAmount = creditMatch.namedGroup('amount');
      String? matchedNumber;
      try {
        matchedNumber = creditMatch.namedGroup('number');
      } catch (_) {}
      if (rawAmount != null) {
        final sanitizedAmountStr = rawAmount.replaceAll(',', '').trim();
        final amount = double.tryParse(sanitizedAmountStr);

        if (amount != null) {
          return ParsedSmsDto(
            amount: amount,
            type: TransactionType.credit,
            counterpartyNumber: matchedNumber ?? counterpartyNumber,
            serviceProvider: 'IPN/Bank',
            originalBody: normalizedBody,
          );
        } else {
          AppErrorHandler.logSilentError(
            'Failed to parse bank credit amount: $rawAmount',
            'GenericBankStrategy_Receive',
          );
        }
      }
    }

    // ── Send (Debit / Transfer / Outgoing Payment / Deduction) ──
    // 1. Deduction / Payment keywords: e.g. "تم خصم مبلغ 450.00 ج.م من حسابكم"
    final debitArabicRegex = RegExp(
      r'(?:ارسال|إرسال|خصم|تم خصم|دفع|تم دفع|سحب|تم سحب)(?:(?!رصيد|رصيدك|متاح).)*?(?:مبلغ|بمبلغ)?\s*(?<amount>\d+(?:[\.,]\d+)?)',
      caseSensitive: false,
    );

    // 2. Transfer out of account: e.g. "تم تحويل مبلغ 800 ج.م من حسابكم"
    final debitAccountRegex = RegExp(
      r'(?:تحويل)(?:(?!رصيد|رصيدك|متاح).)*?(?:مبلغ|بمبلغ)?\s*(?<amount>\d+(?:[\.,]\d+)?).*?(?:من حسابكم|من حسابك|من كارت|من بطاقة)',
      caseSensitive: false,
    );

    // 3. Transfer to destination: e.g. "تم تحويل مبلغ 500 إلى 010..."
    final debitToRegex = RegExp(
      r'(?:تحويل الى|تحويل إلي|تحويل الي|تحويل إلى|تحويل ل)(?:(?!رصيد|رصيدك|متاح).)*?(?:مبلغ|بمبلغ)?\s*(?<amount>\d+(?:[\.,]\d+)?)',
      caseSensitive: false,
    );

    // 4. English Send: e.g. "Transfer Sent. Amount of EGP 123.45"
    final debitEnglishRegex = RegExp(
      r'(?:transfer sent|sent|debit|debited|payment|transferred)(?:(?!balance).)*?(?:amount of egp|amount of|amount|egp|le|\:)?\s*(?<amount>\d+(?:[\.,]\d+)?)',
      caseSensitive: false,
    );

    final debitMatch = debitArabicRegex.firstMatch(normalizedBody) ??
        debitAccountRegex.firstMatch(normalizedBody) ??
        debitToRegex.firstMatch(normalizedBody) ??
        debitEnglishRegex.firstMatch(normalizedBody);

    if (debitMatch != null) {
      final rawAmount = debitMatch.namedGroup('amount');
      if (rawAmount != null) {
        final sanitizedAmountStr = rawAmount.replaceAll(',', '').trim();
        final amount = double.tryParse(sanitizedAmountStr);

        if (amount != null) {
          return ParsedSmsDto(
            amount: amount,
            type: TransactionType.debit,
            counterpartyNumber: counterpartyNumber,
            serviceProvider: 'IPN/Bank',
            originalBody: normalizedBody,
          );
        } else {
          AppErrorHandler.logSilentError(
            'Failed to parse bank debit amount: $rawAmount',
            'GenericBankStrategy_Send',
          );
        }
      }
    }

    return null;
  }
}
