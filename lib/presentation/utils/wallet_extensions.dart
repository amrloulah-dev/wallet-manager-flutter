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
        return FontAwesomeIcons.mobileScreenButton;
      case WalletType.instaPay:
        return FontAwesomeIcons.buildingColumns;
      case WalletType.other:
        return FontAwesomeIcons.wallet;
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
