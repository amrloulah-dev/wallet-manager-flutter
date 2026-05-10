import 'package:flutter/material.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';

class ErrorMapper {
  /// Maps a semantic error code to a localized user-facing string.
  /// If the code is not recognized, it returns the code itself.
  static String getLocalizedString(BuildContext context, String errorCode) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return errorCode;

    switch (errorCode) {
      // Auth Errors
      case 'auth_error_account_not_found':
        return l10n.auth_error_account_not_found;
      case 'auth_error_invalid_email':
        return l10n.auth_error_invalid_email;
      case 'auth_error_too_many_requests':
        return l10n.auth_error_too_many_requests;
      case 'auth_error_invalid_credentials':
        return l10n.auth_error_invalid_credentials;
      case 'auth_error_session_expired':
        return l10n.auth_error_session_expired;
      case 'auth_error_store_not_found':
        return l10n.auth_error_store_not_found;
      case 'auth_error_user_not_found':
        return l10n.auth_error_user_not_found;
      case 'auth_error_login_failed':
        return l10n.auth_error_login_failed;
      case 'auth_error_employee_login_failed':
        return l10n.auth_error_employee_login_failed;
      case 'auth_error_store_lookup_failed':
        return l10n.auth_error_store_lookup_failed;
      case 'auth_error_reset_failed':
        return l10n.auth_error_reset_failed;
      case 'auth_error_unexpected':
        return l10n.auth_error_unexpected;
      case 'auth_operation_failed':
        return l10n.auth_operation_failed;
      case 'auth_error_store_not_active':
        return l10n.auth_error_store_not_active;
      case 'auth_error_email_already_in_use':
        return l10n.auth_error_email_already_in_use;
      case 'auth_error_invalid_key':
        return l10n.auth_error_invalid_key;
      case 'auth_error_key_already_used':
        return l10n.auth_error_key_already_used;
      case 'weak_password':
        return l10n.weakPasswordException ?? errorCode;

      // License Errors
      case 'license_expired':
        return l10n.licenseExpired;

      // Network Errors
      case 'network_error_fetch_failed':
        return l10n.somethingWentWrong; // Generic fallback if no specific network error in l10n

      // Wallet Errors
      case 'wallet_error_fetch_failed':
        return l10n.wallet_error_fetch_failed;
      case 'wallet_error_fetch_more_failed':
        return l10n.wallet_error_fetch_more_failed;
      case 'wallet_error_create_failed':
        return l10n.wallet_error_create_failed;
      case 'wallet_error_update_failed':
        return l10n.wallet_error_update_failed;
      case 'wallet_error_delete_failed':
        return l10n.wallet_error_delete_failed;
      case 'wallet_error_balance_update_failed':
        return l10n.wallet_error_balance_update_failed;
      case 'wallet_error_limit_reached':
        return l10n.wallet_error_limit_reached;
      case 'wallet_error_frozen':
        return l10n.wallet_error_frozen;
      case 'wallet_error_subscription_unresolved':
        return l10n.wallet_error_subscription_unresolved;

      // Permission Errors
      case 'permission_denied':
        return l10n.ownerOnlyFeature; // Or add specific permission_denied key

      // Device Errors
      case 'device_limit_exceeded':
        return l10n.somethingWentWrong; // Fallback

      // Overlay Errors
      case 'overlay_error_amount_limit_instapay':
        return l10n.overlay_error_amount_limit_instapay;
      case 'overlay_error_amount_limit_telecom':
        return l10n.overlay_error_amount_limit_telecom;

      // Logic Keys (from OverlayProvider)
      case 'pleaseSelectWallet':
        return l10n.pleaseSelectWallet;
      case 'authErrorRelogin':
        return l10n.authErrorRelogin;

      default:
        return errorCode;
    }
  }
}
