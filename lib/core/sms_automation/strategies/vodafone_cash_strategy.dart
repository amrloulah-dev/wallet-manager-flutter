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
    return SmsParserStrategy.parseStrict(
      normalizedBody: normalizedBody,
      defaultProvider: 'Vodafone Cash',
      strategyTag: 'VodafoneCashStrategy',
    );
  }
}
