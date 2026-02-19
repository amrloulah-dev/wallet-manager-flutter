import 'models/parsed_sms_dto.dart';
import 'strategies/sms_parser_strategy.dart';
import 'strategies/vodafone_cash_strategy.dart';
import 'strategies/generic_bank_strategy.dart';
import 'package:flutter/foundation.dart';
import 'utils/text_normalizer.dart';

class SmsParserEngine {
  final List<SmsParserStrategy> _strategies;

  SmsParserEngine({List<SmsParserStrategy>? strategies})
      : _strategies = strategies ??
            [
              VodafoneCashStrategy(),
              GenericBankStrategy(),
            ];

  /// Parses an SMS message.
  ///
  /// Steps:
  /// 1. Normalize the body.
  /// 2. Normalize the sender.
  /// 3. Select strategy.
  /// 4. Delegate parsing.
  ParsedSmsDto? parse(String sender, String body) {
    debugPrint(">>> ENGINE: Parsing body: '$body'");

    // 1. Normalize the body using TextNormalizer
    final normalizedBody = TextNormalizer.normalize(body);

    // 2. Normalize the sender
    final normalizedSender = sender
        .trim(); // Strategies handle case-insensitivity internally usually, but we can do it here if needed.
    // The requirement says "Normalize the sender".
    // Let's assume trimming and ensuring not null (already string).

    // 3. Select the correct strategy based on the sender
    debugPrint(">>> ENGINE: Normalized body: '$normalizedBody'");

    // 3a. Try Specific Strategy First
    for (final strategy in _strategies) {
      if (strategy.canParse(normalizedSender)) {
        try {
          final result = strategy.parse(normalizedBody);
          if (result != null) {
            debugPrint(
                ">>> ENGINE: Specific strategy success with ${strategy.runtimeType}");
            return result;
          }
        } catch (e) {
          debugPrint(">>> ENGINE: Specific strategy failed: $e");
        }
      }
    }

    // 3b. FALLBACK (For Testing/Unknown Senders): Try ALL strategies
    debugPrint(
        ">>> ENGINE: No specific strategy matched. Trying fallback on all strategies...");
    for (final strategy in _strategies) {
      try {
        final result = strategy.parse(normalizedBody);
        if (result != null) {
          debugPrint(
              ">>> ENGINE: Fallback success with ${strategy.runtimeType}");
          return result;
        }
      } catch (e) {
        // Ignore failures in fallback loop
      }
    }

    // 5. Return null if parsing fails or message is irrelevant
    return null;
  }
}
