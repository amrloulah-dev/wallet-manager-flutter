import 'package:walletmanager/core/sms_automation/utils/text_normalizer.dart';
import 'package:walletmanager/core/sms_automation/utils/bank_constants.dart';
import '../errors/app_error_handler.dart';
import '../errors/error_severity.dart';
import 'models/parsed_sms_dto.dart';
import 'strategies/sms_parser_strategy.dart';
import 'strategies/egyptian_telco_wallet_strategy.dart';
import 'strategies/generic_bank_strategy.dart';

class SmsParserEngine {
  final List<SmsParserStrategy> _strategies;

  static final Set<String> _knownTelecomTriggers = {
    'vf-cash',
    'vodafone',
    'vfcash',
    'orange',
    'etisalat',
    'we',
    'we pay',
    'wepay',
    'orange cash',
    'orangecash',
    'etisalat cash',
    'etisalatcash',
    // Arabic Triggers (corresponding to WalletType enum aliases)
    'فودافون',
    'فودافونكاش',
    'فودافون كاش',
    'انستاباي',
    'إنستاباي',
    'انستا باي',
    'إنستا باي',
    'اورانج',
    'أورانج',
    'اورانجكاش',
    'أورانجكاش',
    'اورانج كاش',
    'أورانج كاش',
    'اتصالات',
    'اتصالاتكاش',
    'اتصالات كاش',
    'وي',
    'ويباي',
    'وي باي',
  };

  SmsParserEngine({List<SmsParserStrategy>? strategies})
      : _strategies = strategies ??
            [
              EgyptianTelcoWalletStrategy(),
              GenericBankStrategy(),
            ];

  /// Checks if [sender] matches a recognized telecom, phone, or bank identity.
  bool isValidSender(String sender) {
    final trimmed = sender.trim();
    if (trimmed.isEmpty) return false;

    final lower = trimmed.toLowerCase();
    if (_knownTelecomTriggers.contains(lower) ||
        _knownTelecomTriggers
            .contains(lower.replaceAll(' ', '').replaceAll('_', ''))) {
      return true;
    }

    // Check normalized Arabic forms (e.g. أ -> ا, ة -> ه)
    final normalized = TextNormalizer.normalize(trimmed);
    final normalizedNoSpaces =
        normalized.replaceAll(' ', '').replaceAll('_', '');
    if (_knownTelecomTriggers.contains(normalized) ||
        _knownTelecomTriggers.contains(normalizedNoSpaces)) {
      return true;
    }

    final upper = trimmed.toUpperCase();
    if (BankConstants.isSupportedBankSender(trimmed) ||
        upper.contains('IPN') ||
        upper.contains('INSTAPAY')) {
      return true;
    }

    // Check Egyptian mobile number format (+201..., 201..., 01..., 1...)
    String digitsOnly = trimmed.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.startsWith('20')) {
      digitsOnly = digitsOnly.substring(2);
    }
    if (digitsOnly.startsWith('0')) {
      digitsOnly = digitsOnly.substring(1);
    }
    if (digitsOnly.length == 10 &&
        RegExp(r'^1[0125]\d{8}$').hasMatch(digitsOnly)) {
      return true;
    }

    return false;
  }

  /// Parses an SMS message using a fail-fast approach.
  ///
  /// Steps:
  /// 1. Normalize sender and validate against authorized sender criteria.
  /// 2. If sender is unrecognized, fail-fast and return null immediately.
  /// 3. Normalize body.
  /// 4. Delegate parsing strictly to strategies matching the sender via canParse().
  // [TEMP DIAGNOSTIC]
  SmsRejectionInfo? _lastRejection;

  /// [TEMP DIAGNOSTIC] Last recorded rejection information from the latest parse invocation.
  SmsRejectionInfo? get lastRejection => _lastRejection;

  /// Parses an SMS message using a fail-fast approach.
  ///
  /// Steps:
  /// 1. Normalize sender and validate against authorized sender criteria.
  /// 2. If sender is unrecognized, fail-fast and return null immediately.
  /// 3. Normalize body.
  /// 4. Delegate parsing strictly to strategies matching the sender via canParse().
  ParsedSmsDto? parse(String sender, String body) {
    _lastRejection = null;
    final normalizedSender = sender.trim();

    // 1. Fail-Fast Guard: Validate sender identity before heavy parsing
    if (!isValidSender(normalizedSender)) {
      // [TEMP DIAGNOSTIC]
      _lastRejection = const SmsRejectionInfo(
        reason: 'UNKNOWN_SENDER',
        failureStep: 'SENDER_VALIDATION_FAILED',
      );
      return null;
    }

    // 2. Normalize the body using TextNormalizer
    final normalizedBody = TextNormalizer.normalize(body);

    // 3. Delegate strictly to matching strategies
    bool matchedAnyStrategy = false;
    for (final strategy in _strategies) {
      if (strategy.canParse(normalizedSender)) {
        matchedAnyStrategy = true;
        try {
          final result = strategy.parse(
            normalizedBody,
            normalizedSender,
            (reason, step) {
              // [TEMP DIAGNOSTIC]
              _lastRejection = SmsRejectionInfo(
                reason: reason,
                failureStep: step,
              );
            },
          );
          if (result != null) {
            _lastRejection = null;
            return result;
          }
        } catch (e, stack) {
          AppErrorHandler.handle(
            e,
            severity: ErrorSeverity.low,
            operation: 'sms_parsing_strategy',
            stackTrace: stack,
          );
        }
      }
    }

    if (!matchedAnyStrategy) {
      // [TEMP DIAGNOSTIC]
      _lastRejection = const SmsRejectionInfo(
        reason: 'UNKNOWN_SENDER',
        failureStep: 'NO_MATCHING_STRATEGY',
      );
    }

    // 4. Return null if parsing fails or message is irrelevant
    return null;
  }
}
