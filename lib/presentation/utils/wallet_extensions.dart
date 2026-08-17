import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:walletmanager/core/enums/wallet_enums.dart';
import 'package:walletmanager/data/models/wallet_model.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';

/// UI-related extensions for [WalletModel].
extension WalletUIExtensions on WalletModel {
  /// Localized display name key for the wallet type.
  String get walletTypeKey {
    switch (walletType) {
      case WalletType.vodafoneCash:
        return 'wallet_type_vodafone_cash';
      case WalletType.instaPay:
        return 'wallet_type_insta_pay';
      case WalletType.orangeCash:
        return 'wallet_type_orange_cash';
      case WalletType.etisalatCash:
        return 'wallet_type_etisalat_cash';
      case WalletType.wePay:
        return 'wallet_type_we_pay';
      case WalletType.other:
        return 'wallet_type_other';
    }
  }

  /// Localized display name key for the wallet status.
  String get walletStatusKey {
    switch (walletStatus) {
      case WalletStatus.active:
        return 'wallet_status_active';
      case WalletStatus.inactive:
        return 'wallet_status_inactive';
      case WalletStatus.suspended:
        return 'wallet_status_suspended';
    }
  }

  /// Icon representing the wallet type.
  IconData get walletTypeIcon {
    switch (walletType) {
      case WalletType.vodafoneCash:
      case WalletType.orangeCash:
      case WalletType.etisalatCash:
      case WalletType.wePay:
        return FontAwesomeIcons.mobileScreenButton.data;
      case WalletType.instaPay:
        return FontAwesomeIcons.buildingColumns.data;
      case WalletType.other:
        return FontAwesomeIcons.wallet.data;
    }
  }
}

extension WalletLocalization on AppLocalizations {
  String getWalletTypeName(WalletType type) {
    switch (type) {
      case WalletType.vodafoneCash:
        return wallet_type_vodafone_cash;
      case WalletType.instaPay:
        return wallet_type_insta_pay;
      case WalletType.orangeCash:
        return wallet_type_orange_cash;
      case WalletType.etisalatCash:
        return wallet_type_etisalat_cash;
      case WalletType.wePay:
        return wallet_type_we_pay;
      case WalletType.other:
        return wallet_type_other;
    }
  }

  String getWalletStatusName(WalletStatus status) {
    switch (status) {
      case WalletStatus.active:
        return newStatus;
      case WalletStatus.inactive:
        return oldStatus;
      case WalletStatus.suspended:
        return registeredStore;
    }
  }
}

/// Visual identity mapping helper for [WalletType].
class WalletProviderVisuals {
  final IconData icon;
  final Color color;
  final String label;

  const WalletProviderVisuals({
    required this.icon,
    required this.color,
    required this.label,
  });

  factory WalletProviderVisuals.fromWalletType(
    WalletType type, [
    AppLocalizations? l10n,
  ]) {
    switch (type) {
      case WalletType.instaPay:
        return WalletProviderVisuals(
          icon: Icons.account_balance_rounded,
          color: const Color(0xFF5C2D91),
          label: l10n?.getWalletTypeName(type) ?? 'إنستاباي',
        );
      case WalletType.vodafoneCash:
        return WalletProviderVisuals(
          icon: Icons.account_balance_wallet_rounded,
          color: Colors.red,
          label: l10n?.getWalletTypeName(type) ?? 'فودافون كاش',
        );
      case WalletType.orangeCash:
        return WalletProviderVisuals(
          icon: Icons.account_balance_wallet_rounded,
          color: Colors.orange,
          label: l10n?.getWalletTypeName(type) ?? 'أورانج كاش',
        );
      case WalletType.etisalatCash:
        return WalletProviderVisuals(
          icon: Icons.account_balance_wallet_rounded,
          color: Colors.green,
          label: l10n?.getWalletTypeName(type) ?? 'اتصالات كاش',
        );
      case WalletType.wePay:
        return WalletProviderVisuals(
          icon: Icons.account_balance_wallet_rounded,
          color: Colors.purple,
          label: l10n?.getWalletTypeName(type) ?? 'وي باي',
        );
      case WalletType.other:
        return WalletProviderVisuals(
          icon: Icons.account_balance_wallet_outlined,
          color: Colors.blueGrey,
          label: l10n?.getWalletTypeName(type) ?? 'أخرى',
        );
    }
  }

  factory WalletProviderVisuals.fromRawType(
    String? rawType, [
    AppLocalizations? l10n,
  ]) {
    final type = WalletType.fromString(rawType ?? 'other');
    return WalletProviderVisuals.fromWalletType(type, l10n);
  }
}
