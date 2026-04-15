import 'package:walletmanager/core/sms_automation/utils/text_normalizer.dart';
import '../errors/app_error_handler.dart';
import '../errors/error_severity.dart';
import 'models/parsed_sms_dto.dart';
import 'strategies/sms_parser_strategy.dart';
import 'strategies/vodafone_cash_strategy.dart';
import 'strategies/generic_bank_strategy.dart';

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

    // 1. Normalize the body using TextNormalizer
    final normalizedBody = TextNormalizer.normalize(body);

    // 2. Normalize the sender
    final normalizedSender = sender
        .trim(); // Strategies handle case-insensitivity internally usually, but we can do it here if needed.
    // The requirement says "Normalize the sender".
    // Let's assume trimming and ensuring not null (already string).

    // 3. Select the correct strategy based on the sender

    // 3a. Try Specific Strategy First
    for (final strategy in _strategies) {
      if (strategy.canParse(normalizedSender)) {
        try {
          final result = strategy.parse(normalizedBody);
          if (result != null) {
            return result;
          }
        } catch (e, stack) {
          AppErrorHandler.handle(e,
              severity: ErrorSeverity.low,
              operation: 'sms_parsing_strategy',
              stackTrace: stack);
        }
      }
    }

    // 3b. FALLBACK (For Testing/Unknown Senders): Try ALL strategies
    for (final strategy in _strategies) {
      try {
        final result = strategy.parse(normalizedBody);
        if (result != null) {
          return result;
        }
      } catch (e, stack) {
        // Log low severity but continue loop
        AppErrorHandler.handle(e,
            severity: ErrorSeverity.low,
            operation: 'sms_parsing_fallback',
            stackTrace: stack);
      }
    }

    // 5. Return null if parsing fails or message is irrelevant
    return null;
  }
}
