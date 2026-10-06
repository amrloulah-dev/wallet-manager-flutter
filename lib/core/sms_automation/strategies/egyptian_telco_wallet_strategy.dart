import '../models/parsed_sms_dto.dart';
import '../utils/text_normalizer.dart';
import 'sms_parser_strategy.dart';

/// Unified Egyptian Telco Wallet Strategy handling Vodafone Cash, Orange Cash,
/// Etisalat Cash, and WE Pay with dynamic provider resolution.
class EgyptianTelcoWalletStrategy extends SmsParserStrategy {
  static final RegExp debitRegex = SmsParserStrategy.telcoDebitRegex;
  static final RegExp creditRegex = SmsParserStrategy.telcoCreditRegex;

  static final Set<String> _vodafoneTriggers = {
    'vf-cash',
    'vodafone',
    'vfcash',
    'فودافون',
    'فودافونكاش',
    'فودافون كاش',
  };

  static final Set<String> _orangeTriggers = {
    'orange',
    'orangecash',
    'orange cash',
    'اورانج',
    'أورانج',
    'اورانجكاش',
    'أورانجكاش',
    'اورانج كاش',
    'أورانج كاش',
  };

  static final Set<String> _etisalatTriggers = {
    'etisalat',
    'etisalatcash',
    'etisalat cash',
    'اتصالات',
    'اتصالاتكاش',
    'اتصالات كاش',
  };

  static final Set<String> _weTriggers = {
    'we',
    'wepay',
    'we pay',
    'وي',
    'ويباي',
    'وي باي',
  };

  String _currentProvider = 'Vodafone Cash';

  static bool _matches(
      Set<String> triggers, String lower, String normalizedNoSpace) {
    if (triggers.contains(lower) ||
        triggers.contains(lower.replaceAll(' ', '').replaceAll('_', ''))) {
      return true;
    }
    return triggers.contains(normalizedNoSpace);
  }

  /// Determines the provider name based on the sender string.
  String resolveProvider(String sender) {
    final lower = sender.toLowerCase().trim();
    final normalized = TextNormalizer.normalize(lower);
    final normalizedNoSpace =
        normalized.replaceAll(' ', '').replaceAll('_', '');

    if (_matches(_orangeTriggers, lower, normalizedNoSpace)) {
      return 'Orange Cash';
    } else if (_matches(_etisalatTriggers, lower, normalizedNoSpace)) {
      return 'Etisalat Cash';
    } else if (_matches(_weTriggers, lower, normalizedNoSpace)) {
      return 'WE Pay';
    } else if (_matches(_vodafoneTriggers, lower, normalizedNoSpace)) {
      return 'Vodafone Cash';
    }
    return 'Vodafone Cash';
  }

  @override
  bool canParse(String sender) {
    final lower = sender.toLowerCase().trim();
    final normalized = TextNormalizer.normalize(lower);
    final normalizedNoSpace =
        normalized.replaceAll(' ', '').replaceAll('_', '');

    if (_matches(_orangeTriggers, lower, normalizedNoSpace)) {
      _currentProvider = 'Orange Cash';
      return true;
    } else if (_matches(_etisalatTriggers, lower, normalizedNoSpace)) {
      _currentProvider = 'Etisalat Cash';
      return true;
    } else if (_matches(_weTriggers, lower, normalizedNoSpace)) {
      _currentProvider = 'WE Pay';
      return true;
    } else if (_matches(_vodafoneTriggers, lower, normalizedNoSpace)) {
      _currentProvider = 'Vodafone Cash';
      return true;
    }

    return false;
  }

  @override
  ParsedSmsDto? parse(
    String normalizedBody, [
    String? sender,
    void Function(String reason, String failureStep)?
        onDiagnostic, // [TEMP DIAGNOSTIC]
  ]) {
    final provider = (sender != null && sender.isNotEmpty)
        ? resolveProvider(sender)
        : _currentProvider;

    return SmsParserStrategy.parseStrict(
      normalizedBody: normalizedBody,
      defaultProvider: provider,
      strategyTag: 'EgyptianTelcoWalletStrategy',
      onDiagnostic: onDiagnostic, // [TEMP DIAGNOSTIC]
    );
  }
}
