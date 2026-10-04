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
  ParsedSmsDto? parse(
    String normalizedBody, [
    String? sender,
    void Function(String reason, String failureStep)? onDiagnostic, // [TEMP DIAGNOSTIC]
  ]) {
    return SmsParserStrategy.parseStrict(
      normalizedBody: normalizedBody,
      defaultProvider: 'IPN/Bank',
      strategyTag: 'GenericBankStrategy',
      onDiagnostic: onDiagnostic, // [TEMP DIAGNOSTIC]
    );
  }
}
