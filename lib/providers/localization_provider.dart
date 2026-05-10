import 'package:flutter/material.dart';
import 'package:walletmanager/core/utils/number_formatter.dart';
import 'package:walletmanager/core/utils/currency_formatter.dart';
import 'package:walletmanager/core/utils/date_helper.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';
import 'base_provider.dart';

class LocalizationProvider extends BaseProvider {
  final LocalStorageService _localStorage;
  Locale _locale = const Locale('ar');

  Locale get locale => _locale;

  LocalizationProvider({LocalStorageService? localStorage})
      : _localStorage = localStorage ?? LocalStorageService.instance {
    // Configure formatters with the default locale immediately
    _configureFormatters(_locale.languageCode);
    Future.microtask(() => _loadLocale());
  }

  Future<void> _loadLocale() async {
    final savedLocale = _localStorage.savedLocale;
    if (savedLocale != null) {
      _locale = Locale(savedLocale);
      _configureFormatters(savedLocale);
      safeNotify();
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    _configureFormatters(locale.languageCode);
    await _localStorage.saveLocale(locale.languageCode);
    safeNotify();
  }

  /// Configures all static formatters to use the given language code.
  /// Maps the language code to the appropriate ICU locale identifier
  /// and locale-specific currency symbol.
  static void _configureFormatters(String languageCode) {
    final icuLocale = languageCode == 'ar' ? 'ar_EG' : 'en_US';
    final currencySymbol = languageCode == 'ar' ? 'ج' : 'EGP';

    NumberFormatter.setLocale(icuLocale);
    CurrencyFormatter.setLocale(icuLocale, currencySymbol: currencySymbol);
    DateHelper.setLocale(icuLocale);
  }

  bool get isArabic => _locale.languageCode == 'ar';
}
