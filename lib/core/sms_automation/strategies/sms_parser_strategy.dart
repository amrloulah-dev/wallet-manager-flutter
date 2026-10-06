import '../../errors/app_error_handler.dart';
import '../models/parsed_sms_dto.dart';

// [TEMP DIAGNOSTIC]
class SmsRejectionInfo {
  final String reason;
  final String failureStep;
  const SmsRejectionInfo({required this.reason, required this.failureStep});
}

abstract class SmsParserStrategy {
  /// Returns true if this strategy can handle the given sender.
  bool canParse(String sender);

  /// Parses the message body and returns a DTO.
  /// Returns null if parsing fails or keywords are missing.
  ParsedSmsDto? parse(
    String normalizedBody, [
    String? sender,
    void Function(String reason, String failureStep)?
        onDiagnostic, // [TEMP DIAGNOSTIC]
  ]);

  // ── Strict Extraction Helpers ─────────────────────────────

  /// Strict anchor-based amount regex.
  /// Strict anchor-based amount regex.
  /// Only matches amounts immediately following designated linguistic anchors.
  /// Accepts strictly English decimal dot (.) notation (\d+(?:\.\d+)?).
  static final RegExp amountAnchorRegex = RegExp(
    r'(?:مبلغ|بمبلغ|بقيمة|بقيمه|قيمة|قيمه|خصم|amount\s+of\s+(?:egp|le)?|amount\s*:\s*|amount\s+|received\s+|sent\s+)\s*(?<amount>\d+(?:\.\d+)?)',
    caseSensitive: false,
  );

  /// Prefixed Egyptian mobile phone regex (11 digits starting with 010, 011, 012, 015).
  static final RegExp prefixedPhoneRegex = RegExp(
    r'(?:رقم|من رقم|من|إلى رقم|الى رقم|الي رقم|إلي رقم|لرقم|إلى|الى|الي|إلي|لـ|ل|محول من|محول الى|محول الي|to|from)\s*(?<number>01[0125]\d{8})',
    caseSensitive: false,
  );

  /// Standalone fallback Egyptian mobile phone regex.
  static final RegExp standalonePhoneRegex = RegExp(r'01[0125]\d{8}');

  /// Specialized Vodafone Cash & Telco Outbound Debit regex.
  /// Matches `تحويل [مبلغ] <amount> [جنيه] ... لرقم <phone>`
  static final RegExp telcoDebitRegex = RegExp(
    r'(?:تم\s+)?تحويل\s+(?:مبلغ\s+)?(?<amount>\d+(?:\.\d+)?)\s*(?:جنيه|ج\.م|جم|egp|le)?.*?(?:لـ?رقم|إلى\s+رقم|الي\s+رقم|إلي\s+رقم)\s*(?<phone>01[0125]\d{8})',
    caseSensitive: false,
  );

  /// Specialized Vodafone Cash & Telco Inbound Credit regex.
  /// Matches `استلام [مبلغ] <amount> [جنيه] ... من رقم <phone>`
  /// Strictly anchors to "من رقم" to prevent capturing receiver wallet number in "على رقم محفظتك".
  static final RegExp telcoCreditRegex = RegExp(
    r'(?:تم\s+)?(?:استلام|إستلام)\s+(?:مبلغ\s+)?(?<amount>\d+(?:\.\d+)?)\s*(?:جنيه|ج\.م|جم|egp|le)?.*?من\s+رقم\s*(?<phone>01[0125]\d{8})',
    caseSensitive: false,
  );

  /// Specialized Bank Instant Payment Network (IPN / InstaPay) Inbound Credit regex.
  /// Matches `تم اضافة [مبلغ] <amount> [EGP/LE/جنيه/جم] إلى حساب [رقم] <account>`
  static final RegExp bankIpnCreditRegex = RegExp(
    r'(?:تم\s+)?(?:اضاف[ةه]|إضاف[ةه])\s+(?:مبلغ\s+)?(?<amount>\d+(?:\.\d+)?)\s*(?<currency>EGP|LE|جنيه|جم)?\s+(?:إلى|الى|الي|إلي)\s+حساب\s+(?:رقم\s+)?(?<account>[a-zA-Z0-9*#\-_]+)',
    caseSensitive: false,
  );

  /// Specialized Bank Instant Payment Network (IPN / InstaPay) Outbound Debit regex.
  /// Matches `تم تحويل/خصم [مبلغ] <amount> [EGP/LE/جنيه/جم] من حساب [رقم] <account>`
  static final RegExp bankIpnDebitRegex = RegExp(
    r'(?:تم\s+)?(?:تحويل|خصم)\s+(?:مبلغ\s+)?(?<amount>\d+(?:\.\d+)?)\s*(?<currency>EGP|LE|جنيه|جم)?\s+من\s+حساب\s+(?:رقم\s+)?(?<account>[a-zA-Z0-9*#\-_]+)',
    caseSensitive: false,
  );

  /// Strips fee, service charge, and commission clauses from SMS body as noise.
  /// The app calculates all fees and commissions internally and automatically.
  static final RegExp feeClauseRegex = RegExp(
    r'(?:'
    // Arabic: [تم خصم / خصم / بخصم] X [جنيه/جم] رسوم/مصاريف/عمولة [الخدمة/تحويل/ادارية]
    r'(?:(?:تم\s+خصم|خصم|بخصم)\s*\d{1,4}(?:\.\d+)?\s*(?:جنيه|جم|egp|le)?|\b\d{1,4}(?:\.\d+)?\s*(?:جنيه|جم|egp|le)\s*)\s*(?:رسوم|مصاريف|عمول[ةه])(?:\s*(?:الخدم[ةه]|خدم[ةه]|إداري[ةه]|اداري[ةه]|تحويل))*'
    r'|'
    // Arabic: رسوم/مصاريف/عمولة [الخدمة/تحويل/ادارية] [:] X [جنيه/جم]
    r'(?:رسوم|مصاريف|عمول[ةه])(?:\s*(?:الخدم[ةه]|خدم[ةه]|إداري[ةه]|اداري[ةه]|تحويل))?\s*(?:هي|:)?\s*[\d.]+\s*(?:جنيه|جم|egp|le)?'
    r'|'
    // English: [service] fee / fees / commission [of / :] X [egp / le] [was debited / debited / deducted]
    r'(?:service\s+fee|fee|fees|commission)\s*(?:of|:)?\s*[\d.]+\s*(?:egp|le)?(?:\s*(?:was|is)?\s*(?:debited|deducted))?'
    r'|'
    // English: [debited / deducted] X [egp] [as] fee / service fee / commission
    r'(?:debited|deducted)\s*[\d.]+\s*(?:egp|le)?\s*(?:as\s+)?(?:fee|service\s+fee|commission)'
    r')',
    caseSensitive: false,
  );

  // ── Compound Context Regexes & Keywords ────────────────────

  static final List<RegExp> _debitCompoundRegexes = [
    RegExp(r'خصم', caseSensitive: false),
    RegExp(r'sent', caseSensitive: false),
    RegExp(r'تنفيذ\s+تحويل\s+من', caseSensitive: false),
    RegExp(
        r'من\s+(?:بطاقة|بطاقه|كارت|كارتك|كارتكم|بطاقتك|بطاقتكم|حسابكم|حسابك)',
        caseSensitive: false),
    RegExp(
        r'تحويل.*?(?:إلى|الى|الي|إلي|لـ|ل\s+|لرقم)\s*(?!(?:محفظتك|محفظتكم|حسابك|حسابكم|كارتك|كارتكم|بطاقتك|بطاقتكم))',
        caseSensitive: false),
    RegExp(
        r'(?:تم\s+)?(?:ارسال|إرسال|أرسلت|ارسلت).*?(?:إلى|الى|الي|إلي|لـ|ل\s+|لرقم)\s*(?!(?:محفظتك|محفظتكم|حسابك|حسابكم|كارتك|كارتكم|بطاقتك|بطاقتكم))',
        caseSensitive: false),
    RegExp(r'(?:تم\s+)?(?:ارسال|إرسال|أرسلت|ارسلت)\s+مبلغ',
        caseSensitive: false),
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
    RegExp(
        r'تحويل.*?(?:لبطاقتكم|لبطاقتك|لحسابكم|لحسابك|في\s+حسابكم|في\s+حسابك|الي\s+حسابك|الى\s+حسابك|الي\s+حسابكم|الى\s+حسابكم|في\s+محفظتك|في\s+محفظتكم|الي\s+محفظتك|الى\s+محفظتك|الي\s+محفظتكم|الى\s+محفظتكم)',
        caseSensitive: false),
    RegExp(r'(?:محول|تحويل|مرسل|ارسال|إرسال)\s+من', caseSensitive: false),
    RegExp(r'وصلك|وصل', caseSensitive: false),
    RegExp(r'credited', caseSensitive: false),
    RegExp(r'deposit', caseSensitive: false),
    RegExp(r'transfer\s+received', caseSensitive: false),
  ];

  static final RegExp _strongCreditAnchor = RegExp(
    r'(?:تم\s+استلام|استلام|تم\s+ايداع|إيداع|ايداع|تم\s+اضافة|إضافة|اضافة|وارد|وصلك|received|credited|deposit)',
    caseSensitive: false,
  );

  static final RegExp _strongDebitAnchor = RegExp(
    r'(?:تم\s+ارسال|تم\s+إرسال|ارسال|إرسال|أرسلت|ارسلت|تم\s+سحب|سحب|تم\s+دفع|دفع|تنفيذ\s+تحويل\s+من|من\s+(?:بطاقة|بطاقه|كارت|كارتك|كارتكم|بطاقتك|بطاقتكم|حسابكم|حسابك)|paid|debited|sent|transfer\s+sent)',
    caseSensitive: false,
  );

  /// Parses a normalized SMS body using strict anchor-based extraction and compound context.
  static ParsedSmsDto? parseStrict({
    required String normalizedBody,
    required String defaultProvider,
    required String strategyTag,
    void Function(String reason, String failureStep)?
        onDiagnostic, // [TEMP DIAGNOSTIC]
  }) {
    // 0. Fee Clause Stripping (Fees treated as noise per system architecture)
    final sanitizedBody = normalizedBody.replaceAll(feeClauseRegex, ' ');

    // Check specialized Telco Inbound Credit pattern first
    final telcoCreditMatch = telcoCreditRegex.firstMatch(sanitizedBody);
    if (telcoCreditMatch != null) {
      final amount =
          double.tryParse(telcoCreditMatch.namedGroup('amount') ?? '');
      final phone = telcoCreditMatch.namedGroup('phone');
      if (amount != null && amount > 0 && phone != null && phone.isNotEmpty) {
        return ParsedSmsDto(
          amount: amount,
          type: TransactionType.credit,
          counterpartyNumber: phone,
          serviceProvider: defaultProvider,
          originalBody: normalizedBody,
        );
      }
    }

    // Check specialized Telco Outbound Debit pattern
    final telcoDebitMatch = telcoDebitRegex.firstMatch(sanitizedBody);
    if (telcoDebitMatch != null) {
      final amount =
          double.tryParse(telcoDebitMatch.namedGroup('amount') ?? '');
      final phone = telcoDebitMatch.namedGroup('phone');
      if (amount != null && amount > 0 && phone != null && phone.isNotEmpty) {
        return ParsedSmsDto(
          amount: amount,
          type: TransactionType.debit,
          counterpartyNumber: phone,
          serviceProvider: defaultProvider,
          originalBody: normalizedBody,
        );
      }
    }

    // Check specialized Bank IPN Inbound Credit pattern
    final bankIpnCreditMatch = bankIpnCreditRegex.firstMatch(sanitizedBody);
    if (bankIpnCreditMatch != null) {
      final amount =
          double.tryParse(bankIpnCreditMatch.namedGroup('amount') ?? '');
      final account = bankIpnCreditMatch.namedGroup('account');
      if (amount != null && amount > 0) {
        return ParsedSmsDto(
          amount: amount,
          type: TransactionType.credit,
          counterpartyNumber:
              (account != null && account.isNotEmpty) ? account : 'IPN/Bank',
          serviceProvider:
              defaultProvider == 'Vodafone Cash' ? 'IPN/Bank' : defaultProvider,
          originalBody: normalizedBody,
        );
      }
    }

    // Check specialized Bank IPN Outbound Debit pattern
    final bankIpnDebitMatch = bankIpnDebitRegex.firstMatch(sanitizedBody);
    if (bankIpnDebitMatch != null) {
      final amount =
          double.tryParse(bankIpnDebitMatch.namedGroup('amount') ?? '');
      final account = bankIpnDebitMatch.namedGroup('account');
      if (amount != null && amount > 0) {
        return ParsedSmsDto(
          amount: amount,
          type: TransactionType.debit,
          counterpartyNumber:
              (account != null && account.isNotEmpty) ? account : 'IPN/Bank',
          serviceProvider:
              defaultProvider == 'Vodafone Cash' ? 'IPN/Bank' : defaultProvider,
          originalBody: normalizedBody,
        );
      }
    }

    // 1. Amount Extraction (Anchor-Based ONLY on sanitized body)
    final amountMatch = amountAnchorRegex.firstMatch(sanitizedBody);
    if (amountMatch == null) {
      // [TEMP DIAGNOSTIC]
      onDiagnostic?.call(
          'AMOUNT_NOT_FOUND', 'Regex anchor missing in: $normalizedBody');
      return null;
    }

    final rawAmountStr = amountMatch.namedGroup('amount');
    if (rawAmountStr == null) {
      // [TEMP DIAGNOSTIC]
      onDiagnostic?.call(
          'AMOUNT_NOT_FOUND', 'Amount named group missing in: $normalizedBody');
      return null;
    }

    final amount = double.tryParse(rawAmountStr);
    if (amount == null || amount <= 0) {
      AppErrorHandler.logSilentError(
        'Failed to parse numeric amount: $rawAmountStr',
        '$strategyTag:parseStrict',
      );
      // [TEMP DIAGNOSTIC]
      onDiagnostic?.call('AMOUNT_NOT_FOUND',
          'Invalid numeric amount "$rawAmountStr" in: $normalizedBody');
      return null;
    }

    // 2. Transaction Type Resolution (Compound Context with Action Anchor Precedence)
    bool isDebit = _debitCompoundRegexes.any((r) => r.hasMatch(sanitizedBody));
    bool isCredit =
        _creditCompoundRegexes.any((r) => r.hasMatch(sanitizedBody));

    if (isDebit && isCredit) {
      final hasStrongCredit = _strongCreditAnchor.hasMatch(sanitizedBody);
      final hasStrongDebit = _strongDebitAnchor.hasMatch(sanitizedBody);

      if (hasStrongCredit && !hasStrongDebit) {
        isDebit = false;
      } else if (hasStrongDebit && !hasStrongCredit) {
        isCredit = false;
      } else {
        // True contradiction or ambiguity
        // [TEMP DIAGNOSTIC]
        onDiagnostic?.call('TYPE_UNRESOLVED',
            'Conflicting debit and credit indicators in: $sanitizedBody');
        return null;
      }
    }

    // Fail-fast if neither matches or still ambiguous
    if (isDebit == isCredit) {
      // [TEMP DIAGNOSTIC]
      onDiagnostic?.call('TYPE_UNRESOLVED',
          'No debit/credit context found in: $sanitizedBody');
      return null;
    }

    final TransactionType type =
        isDebit ? TransactionType.debit : TransactionType.credit;

    // 3. Counterparty Phone & Source/Provider Routing
    String? counterpartyNumber;
    final prefixedMatch = prefixedPhoneRegex.firstMatch(sanitizedBody);
    if (prefixedMatch != null) {
      counterpartyNumber = prefixedMatch.namedGroup('number');
    }
    if (counterpartyNumber == null || counterpartyNumber.isEmpty) {
      final fallbackMatch = standalonePhoneRegex.firstMatch(sanitizedBody);
      if (fallbackMatch != null) {
        counterpartyNumber = fallbackMatch.group(0);
      }
    }

    // Fallback: check masked account or card reference
    if (counterpartyNumber == null || counterpartyNumber.isEmpty) {
      final accountMatch = RegExp(
        r'(?:حساب|بطاق[ةه]|كارت)\s*(?:رقم\s*)?(?<account>[a-zA-Z0-9*#\-_]+)',
        caseSensitive: false,
      ).firstMatch(sanitizedBody);
      if (accountMatch != null) {
        counterpartyNumber = accountMatch.namedGroup('account');
      }
    }

    final String serviceProvider;
    if (counterpartyNumber != null &&
        counterpartyNumber.isNotEmpty &&
        counterpartyNumber != 'IPN/Bank') {
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
