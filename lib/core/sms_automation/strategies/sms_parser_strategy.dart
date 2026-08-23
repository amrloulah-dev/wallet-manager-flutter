import '../../errors/app_error_handler.dart';
import '../models/parsed_sms_dto.dart';

abstract class SmsParserStrategy {
  /// Returns true if this strategy can handle the given sender.
  bool canParse(String sender);

  /// Parses the message body and returns a DTO.
  /// Returns null if parsing fails or keywords are missing.
  ParsedSmsDto? parse(String normalizedBody);

  // ── Strict Extraction Helpers ─────────────────────────────

  /// Strict anchor-based amount regex.
  /// Only matches amounts immediately following designated linguistic anchors.
  /// Accepts strictly English decimal dot (.) notation (\d+(?:\.\d+)?).
  static final RegExp amountAnchorRegex = RegExp(
    r'(?:مبلغ|بمبلغ|خصم|amount\s+of\s+(?:egp|le)?|amount\s*:\s*|amount\s+|received\s+|sent\s+)\s*(?<amount>\d+(?:\.\d+)?)',
    caseSensitive: false,
  );

  /// Prefixed Egyptian mobile phone regex (11 digits starting with 010, 011, 012, 015).
  static final RegExp prefixedPhoneRegex = RegExp(
    r'(?:رقم|من رقم|من|إلى رقم|الى رقم|الي رقم|إلي رقم|لرقم|إلى|الى|الي|إلي|لـ|ل|محول من|محول الى|محول الي|to|from)\s*(?<number>01[0125]\d{8})',
    caseSensitive: false,
  );

  /// Standalone fallback Egyptian mobile phone regex.
  static final RegExp standalonePhoneRegex = RegExp(r'01[0125]\d{8}');

  // ── Compound Context Regexes & Keywords ────────────────────

  static final List<RegExp> _debitCompoundRegexes = [
    RegExp(r'خصم', caseSensitive: false),
    RegExp(r'sent', caseSensitive: false),
    RegExp(r'تنفيذ\s+تحويل\s+من', caseSensitive: false),
    RegExp(r'من\s+(?:بطاقة|بطاقه|كارت|كارتك|كارتكم|بطاقتك|بطاقتكم|حسابكم|حسابك)', caseSensitive: false),
    RegExp(r'تحويل.*?(?:إلى|الى|الي|إلي|لـ|ل\s+|لرقم)', caseSensitive: false),
    RegExp(r'دفع', caseSensitive: false),
    RegExp(r'سحب', caseSensitive: false),
    RegExp(r'paid', caseSensitive: false),
    RegExp(r'debit', caseSensitive: false),
    RegExp(r'debited', caseSensitive: false),
    RegExp(r'transfer\s+sent', caseSensitive: false),
    RegExp(r'transferred\s+to', caseSensitive: false),
  ];

  static final List<RegExp> _creditCompoundRegexes = [
    RegExp(r'إضافة|اضافة', caseSensitive: false),
    RegExp(r'استلام', caseSensitive: false),
    RegExp(r'received', caseSensitive: false),
    RegExp(r'ايداع|إيداع', caseSensitive: false),
    RegExp(r'وارد', caseSensitive: false),
    RegExp(r'تحويل.*?(?:لبطاقتكم|لبطاقتك|لحسابكم|لحسابك|في\s+حسابكم|في\s+حسابك|الي\s+حسابك|الى\s+حسابك|الي\s+حسابكم|الى\s+حسابكم)', caseSensitive: false),
    RegExp(r'(?:محول|تحويل)\s+من', caseSensitive: false),
    RegExp(r'وصلك|وصل', caseSensitive: false),
    RegExp(r'credited', caseSensitive: false),
    RegExp(r'deposit', caseSensitive: false),
    RegExp(r'transfer\s+received', caseSensitive: false),
  ];

  /// Parses a normalized SMS body using strict anchor-based extraction and compound context.
  static ParsedSmsDto? parseStrict({
    required String normalizedBody,
    required String defaultProvider,
    required String strategyTag,
  }) {
    // 1. Amount Extraction (Anchor-Based ONLY)
    final amountMatch = amountAnchorRegex.firstMatch(normalizedBody);
    if (amountMatch == null) {
      return null;
    }

    final rawAmountStr = amountMatch.namedGroup('amount');
    if (rawAmountStr == null) {
      return null;
    }

    final amount = double.tryParse(rawAmountStr);
    if (amount == null || amount <= 0) {
      AppErrorHandler.logSilentError(
        'Failed to parse numeric amount: $rawAmountStr',
        '$strategyTag:parseStrict',
      );
      return null;
    }

    // 2. Transaction Type Resolution (Compound Context)
    final isDebit =
        _debitCompoundRegexes.any((r) => r.hasMatch(normalizedBody));
    final isCredit =
        _creditCompoundRegexes.any((r) => r.hasMatch(normalizedBody));

    // Fail-fast if type is ambiguous or contradictory
    if (isDebit == isCredit) {
      return null;
    }

    final TransactionType type =
        isDebit ? TransactionType.debit : TransactionType.credit;

    // 3. Counterparty Phone & Source/Provider Routing
    String? counterpartyNumber;
    final prefixedMatch = prefixedPhoneRegex.firstMatch(normalizedBody);
    if (prefixedMatch != null) {
      counterpartyNumber = prefixedMatch.namedGroup('number');
    }
    if (counterpartyNumber == null || counterpartyNumber.isEmpty) {
      final fallbackMatch = standalonePhoneRegex.firstMatch(normalizedBody);
      if (fallbackMatch != null) {
        counterpartyNumber = fallbackMatch.group(0);
      }
    }

    final String serviceProvider;
    if (counterpartyNumber != null && counterpartyNumber.isNotEmpty) {
      // E-Wallet transaction
      serviceProvider = defaultProvider;
    } else {
      // Bank / IPN transaction
      counterpartyNumber = 'IPN/Bank';
      serviceProvider =
          defaultProvider == 'Vodafone Cash' ? 'IPN/Bank' : defaultProvider;
    }

    return ParsedSmsDto(
      amount: amount,
      type: type,
      counterpartyNumber: counterpartyNumber,
      serviceProvider: serviceProvider,
      originalBody: normalizedBody,
    );
  }
}
