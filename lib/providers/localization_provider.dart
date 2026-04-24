import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'base_provider.dart';

class LocalizationProvider extends BaseProvider {
  Locale _locale = const Locale('ar');
  static const String _localeKey = 'app_locale';

  Locale get locale => _locale;

  LocalizationProvider() {
    Future.microtask(() => _loadLocale());
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLocale = prefs.getString(_localeKey);
    if (savedLocale != null) {
      _locale = Locale(savedLocale);
      safeNotify();
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale.languageCode);
    safeNotify();
  }

  bool get isArabic => _locale.languageCode == 'ar';
}
