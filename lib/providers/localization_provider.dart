import 'package:flutter/material.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';
import 'base_provider.dart';

class LocalizationProvider extends BaseProvider {
  final LocalStorageService _localStorage;
  Locale _locale = const Locale('ar');

  Locale get locale => _locale;

  LocalizationProvider({LocalStorageService? localStorage})
      : _localStorage = localStorage ?? LocalStorageService.instance {
    Future.microtask(() => _loadLocale());
  }

  Future<void> _loadLocale() async {
    final savedLocale = _localStorage.savedLocale;
    if (savedLocale != null) {
      _locale = Locale(savedLocale);
      safeNotify();
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    await _localStorage.saveLocale(locale.languageCode);
    safeNotify();
  }

  bool get isArabic => _locale.languageCode == 'ar';
}
