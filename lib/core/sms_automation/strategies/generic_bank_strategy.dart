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

    final upperSender = sender.toUpperCase();
    return BankConstants.supportedBankSenders.contains(upperSender) ||
        upperSender.contains("IPN") ||
        upperSender.contains("INSTAPAY");
  }

  @override
  ParsedSmsDto? parse(String normalizedBody) {
    // Keywords Check: Must contain "amount" AND ("sent" OR "received")
    if (!normalizedBody.contains('amount')) return null;
    if (!normalizedBody.contains('sent') &&
        !normalizedBody.contains('received')) {
      return null;
    }

    // Receive (Deposit)
    // Pattern: transfer received.*?amount of egp\s*(?<amount>[\d\.]+)
    if (normalizedBody.contains('received')) {
      final receiveRegex =
          RegExp(r'transfer received.*?amount of egp\s*(?<amount>[\d\.]+)');
      final match = receiveRegex.firstMatch(normalizedBody);
      if (match != null) {
        final amountStr = match.namedGroup('amount');
        if (amountStr != null) {
          try {
            final amount = double.parse(amountStr);
            return ParsedSmsDto(
              amount: amount,
              type: TransactionType.credit,
              counterpartyNumber:
                  null, // IPN doesn't show number often in this format
              serviceProvider: 'IPN/Bank',
              originalBody: normalizedBody,
            );
          } catch (_) {}
        }
      }
    }

    // Send (Transfer)
    // Pattern: transfer sent.*?amount of egp\s*(?<amount>[\d\.]+)
    if (normalizedBody.contains('sent')) {
      final sendRegex =
          RegExp(r'transfer sent.*?amount of egp\s*(?<amount>[\d\.]+)');
      final match = sendRegex.firstMatch(normalizedBody);
      if (match != null) {
        final amountStr = match.namedGroup('amount');
        if (amountStr != null) {
          try {
            final amount = double.parse(amountStr);
            return ParsedSmsDto(
              amount: amount,
              type: TransactionType.debit,
              counterpartyNumber: null,
              serviceProvider: 'IPN/Bank',
              originalBody: normalizedBody,
            );
          } catch (_) {}
        }
      }
    }

    return null;
  }
}
