import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:walletmanager/data/models/wallet_model.dart';

/// UI-related extensions for [WalletModel].
extension WalletUIExtensions on WalletModel {
  /// Localized display name for the wallet type.
  /// TODO: Replace with AppLocalizations when context is available in caller.
  String get walletTypeDisplayName {
    switch (walletType) {
      case 'vodafone_cash':
        return 'فودافون كاش';
      case 'instapay':
        return 'إنستاباي';
      default:
        return walletType;
    }
  }

  /// Localized display name for the wallet status.
  String get walletStatusDisplayName {
    switch (walletStatus) {
      case 'new':
        return 'جديدة';
      case 'old':
        return 'قديمة';
      case 'registered_store':
        return 'محل مسجل';
      default:
        return walletStatus;
    }
  }

  /// Icon representing the wallet type.
  IconData get walletTypeIcon {
    switch (walletType) {
      case 'vodafone_cash':
        return FontAwesomeIcons.mobileScreenButton;
      case 'instapay':
        return FontAwesomeIcons.buildingColumns;
      default:
        return FontAwesomeIcons.wallet;
    }
  }
}
