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

    // 2. Test Number Check (Replace with your actual test number or just allow specific length)
    // Checking if it looks like a personal mobile number (10 digits after cleaning)
    // This allows ANY mobile number to act as a "Bank" for testing purposes.
    if (normalizedSender.length == 10) {
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
    // ── Receive (Credit / Deposit / Incoming Transfer) ──
    final creditAccountRegex = RegExp(
      r'(?:تحويل).*?(?:مبلغ|بمبلغ)\s*(?<amount>[\d\.,]+).*?(?:لحسابكم|لحسابك|في حسابكم|في حسابك|الي حسابك|إلى حسابك|الي حسابكم|إلى حسابكم)',
      caseSensitive: false,
    );
    final creditArabicRegex = RegExp(
      r'(?:استلام|ايداع|إيداع|اضافة|إضافة|وارد).*?(?:مبلغ|بمبلغ)\s*(?<amount>[\d\.,]+)',
      caseSensitive: false,
    );
    final creditEnglishRegex = RegExp(
      r'(?:transfer received|received|deposit|credited).*?(?:amount of egp|amount of|amount)\s*(?<amount>[\d\.,]+)',
      caseSensitive: false,
    );

    final creditMatch = creditAccountRegex.firstMatch(normalizedBody) ??
        creditArabicRegex.firstMatch(normalizedBody) ??
        creditEnglishRegex.firstMatch(normalizedBody);

    if (creditMatch != null) {
      final rawAmount = creditMatch.namedGroup('amount');
      if (rawAmount != null) {
        final sanitizedAmountStr = rawAmount.replaceAll(',', '').trim();
        final amount = double.tryParse(sanitizedAmountStr);

        if (amount != null) {
          return ParsedSmsDto(
            amount: amount,
            type: TransactionType.credit,
            counterpartyNumber:
                null, // IPN/Bank doesn't show number often in this format
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
    final debitArabicRegex = RegExp(
      r'(?:ارسال|إرسال|خصم|دفع|تحويل).*?(?:مبلغ|بمبلغ)\s*(?<amount>[\d\.,]+)',
      caseSensitive: false,
    );
    final debitEnglishRegex = RegExp(
      r'(?:transfer sent|sent|debit|debited|payment|transferred).*?(?:amount of egp|amount of|amount)\s*(?<amount>[\d\.,]+)',
      caseSensitive: false,
    );

    final debitMatch = debitArabicRegex.firstMatch(normalizedBody) ??
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
            counterpartyNumber: null,
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
