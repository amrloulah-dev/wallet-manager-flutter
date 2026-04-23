import 'package:flutter/material.dart';
import '../data/services/local_storage_service.dart';
import '../core/errors/app_error_handler.dart';
import '../core/errors/error_severity.dart';

class ThemeProvider extends ChangeNotifier {
  final LocalStorageService _localStorage;
  ThemeMode _themeMode = ThemeMode.system;

  ThemeProvider({LocalStorageService? localStorage})
      : _localStorage = localStorage ?? LocalStorageService() {
    Future.microtask(() => _loadThemeMode());
  }

  void _safeNotify() {
    if (hasListeners) {
      Future.microtask(() => notifyListeners());
    }
  }

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isLightMode => _themeMode == ThemeMode.light;
  bool get isSystemMode => _themeMode == ThemeMode.system;

  String get themeModeString {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  String get themeModeDisplay {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'فاتح';
      case ThemeMode.dark:
        return 'غامق';
      case ThemeMode.system:
        return 'حسب النظام';
    }
  }

  void _loadThemeMode() {
    try {
      final themeString = _localStorage.themeMode;
      switch (themeString) {
        case 'light':
          _themeMode = ThemeMode.light;
          break;
        case 'dark':
          _themeMode = ThemeMode.dark;
          break;
        case 'system':
        default:
          _themeMode = ThemeMode.system;
          break;
      }
      _safeNotify();
    } catch (e, stack) {
      _themeMode = ThemeMode.system;
      AppErrorHandler.handle(e,
          severity: ErrorSeverity.low,
          operation: 'load_theme_mode',
          stackTrace: stack);
      _safeNotify();
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    _safeNotify();
    await _localStorage.saveThemeMode(themeModeString);
  }

  void toggleTheme() {
    if (_themeMode == ThemeMode.light) {
      setThemeMode(ThemeMode.dark);
    } else {
      setThemeMode(ThemeMode.light);
    }
  }
}
