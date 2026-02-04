import 'package:flutter/material.dart';

class AppColors {
  // Prevent instantiation
  AppColors._();

  // Primary Colors
  static const Color primary = Color(0xFF2196F3);
  static const Color primaryDark = Color(0xFF1976D2);
  static const Color primaryLight = Color(0xFF64B5F6);

  // --- Light & Dark Palettes ---
  static const LightColors light = LightColors();
  static const DarkColors dark = DarkColors();

  // --- Adaptive Getters ---
  static Color textPrimary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? dark.textPrimary
          : light.textPrimary;

  static Color textSecondary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? dark.textSecondary
          : light.textSecondary;

  static Color surface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? dark.surface
          : light.surface;

  static Color divider(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? dark.divider
          : light.divider;

  static Color scaffoldBg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? dark.scaffoldBg
          : light.scaffoldBg;

  static Color border(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? dark.border
          : light.border;

  static Color hint(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark.hint : light.hint;

  static Color licenseCardBg(BuildContext context,
      {required bool isTrial, required bool isExpired}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isTrial) {
      return isDark ? const Color(0xFF3E2723) : Colors.amber.shade50;
    }
    if (isExpired) {
      return isDark
          ? const Color(0xFF421412)
          : error.withAlpha((0.05 * 255).round());
    }
    return isDark
        ? const Color(0xFF1B321C)
        : success.withAlpha((0.05 * 255).round());
  }

  static Color licenseCardBorder(BuildContext context,
      {required bool isTrial, required bool isExpired}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isTrial) {
      return isDark ? Colors.amber.shade900 : Colors.amber.shade200;
    }
    if (isExpired) {
      return isDark
          ? error.withAlpha((0.4 * 255).round())
          : error.withAlpha((0.2 * 255).round());
    }
    return isDark
        ? success.withAlpha((0.4 * 255).round())
        : success.withAlpha((0.2 * 255).round());
  }

  // Status & Semantic Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFF44336);
  static const Color warning = Color(0xFFFF9800);
  static const Color info = Color(0xFF2196F3);

  // Transaction Types
  static const Color send = Color(0xFFF44336);
  static const Color receive = Color(0xFF4CAF50);

  // Wallet Status
  static const Color newWallet = Color(0xFF9C27B0);
  static const Color oldWallet = Color(0xFF009688);

  // Debt Status
  static const Color debtOpen = Color(0xFFF44336);
  static const Color debtPaid = Color(0xFF4CAF50);

  // Shadows
  static const Color shadow = Color(0x1F000000);
}

class LightColors {
  const LightColors();

  final Color textPrimary = const Color(0xFF1A1A1A);
  final Color textSecondary = const Color(0xFF6F6F6F);
  final Color surface = const Color(0xFFFFFFFF);
  final Color divider = const Color(0xFFE0E0E0);
  final Color scaffoldBg = const Color(0xFFF5F5F5);
  final Color border = const Color(0xFFBDBDBD);
  final Color hint = const Color(0xFFBDBDBD);
}

class DarkColors {
  const DarkColors();

  final Color textPrimary = const Color(0xFFEAEAEA);
  final Color textSecondary = const Color(0xFF9E9E9E);
  final Color surface = const Color(0xFF1E1E1E);
  final Color divider = const Color(0xFF333333);
  final Color scaffoldBg = const Color(0xFF121212);
  final Color border = const Color(0xFF4A4A4A);
  final Color hint = const Color(0xFF8A8A8A);
}
