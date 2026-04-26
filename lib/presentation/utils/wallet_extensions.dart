import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:walletmanager/core/enums/wallet_enums.dart';
import 'package:walletmanager/data/models/wallet_model.dart';

/// UI-related extensions for [WalletModel].
extension WalletUIExtensions on WalletModel {
  /// Localized display name for the wallet type.
  String get walletTypeDisplayName {
    switch (walletType) {
      case WalletType.vodafoneCash:
        return 'فودافون كاش';
      case WalletType.instaPay:
        return 'إنستاباي';
      case WalletType.orangeCash:
        return 'أورانج كاش';
      case WalletType.etisalatCash:
        return 'اتصالات كاش';
      case WalletType.wePay:
        return 'وي باي';
      case WalletType.other:
        return 'أخرى';
    }
  }

  /// Localized display name for the wallet status.
  String get walletStatusDisplayName {
    switch (walletStatus) {
      case WalletStatus.active:
        return 'نشطة';
      case WalletStatus.inactive:
        return 'غير نشطة';
      case WalletStatus.suspended:
        return 'معلقة';
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
