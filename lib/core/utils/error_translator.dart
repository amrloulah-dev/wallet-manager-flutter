import 'package:flutter/material.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';

class ErrorTranslator {
  /// Maps a semantic error code to a localized user-facing string.
  /// If the code is not recognized, it returns the code itself.
  static String getLocalizedString(BuildContext context, String errorCode) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return errorCode;

    final parts = errorCode.split(':');
    final baseCode = parts[0];
    final arg = parts.length > 1 ? parts[1] : '';

    switch (baseCode) {
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
        return l10n.weakPasswordException;
      case 'auth_error_google_sign_in':
        return l10n.auth_error_google_sign_in;
      case 'auth_error_sign_out_failed':
        return l10n.auth_error_sign_out_failed;

      // License Errors
      case 'license_expired':
        return l10n.licenseExpired;

      // Network Errors
      case 'network_error_fetch_failed':
        return l10n.somethingWentWrong; // Generic fallback

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

      // Transaction Validator Errors
      case 'wallet_error_not_found':
        return l10n.wallet_error_not_found;
      case 'wallet_error_inactive':
        return l10n.wallet_error_inactive;
      case 'wallet_error_instapay_limit':
        return l10n.wallet_error_instapay_limit(arg.isNotEmpty ? arg : '70,000');
      case 'wallet_error_telecom_limit':
        return l10n.wallet_error_telecom_limit(arg.isNotEmpty ? arg : '60,000');
      case 'wallet_error_insufficient_balance':
        return l10n.wallet_error_insufficient_balance;
      case 'wallet_error_instapay_daily_limit':
        return l10n.wallet_error_instapay_daily_limit(arg.isNotEmpty ? arg : '120,000');
      case 'wallet_error_daily_send_limit':
        return l10n.wallet_error_daily_send_limit;
      case 'wallet_error_monthly_send_limit':
        return l10n.wallet_error_monthly_send_limit;
      case 'wallet_error_daily_receive_limit':
        return l10n.wallet_error_daily_receive_limit;
      case 'wallet_error_monthly_receive_limit':
        return l10n.wallet_error_monthly_receive_limit;
      case 'wallet_error_transaction_failed':
        return l10n.wallet_error_transaction_failed;

      // Permission Errors
      case 'permission_denied':
        return l10n.ownerOnlyFeature;

      // Device Errors
      case 'device_limit_exceeded':
        return l10n.somethingWentWrong;

      // Overlay Errors
      case 'overlay_error_amount_limit_instapay':
        return l10n.overlay_error_amount_limit_instapay(arg.isNotEmpty ? arg : '70,000');
      case 'overlay_error_amount_limit_telecom':
        return l10n.overlay_error_amount_limit_telecom(arg.isNotEmpty ? arg : '60,000');

      // Logic Keys (from OverlayProvider)
      case 'pleaseSelectWallet':
        return l10n.pleaseSelectWallet;
      case 'authErrorRelogin':
        return l10n.authErrorRelogin;

      // Migration Errors
      case 'migration_error_recalculate_failed':
        return l10n.migration_error_recalculate_failed;
      case 'migration_error_unexpected':
        return l10n.migration_error_unexpected;

      // Overlay Errors (C-1)
      case 'overlay_error_load_failed':
        return l10n.overlay_error_load_failed;
      case 'overlay_error_submit_failed':
        return l10n.overlay_error_submit_failed;

      // Debt Errors (C-2)
      case 'debt_error_create_failed':
        return l10n.debt_error_create_failed;
      case 'debt_error_fetch_failed':
        return l10n.debt_error_fetch_failed;
      case 'debt_error_payment_failed':
        return l10n.debt_error_payment_failed;
      case 'debt_error_partial_add_failed':
        return l10n.debt_error_partial_add_failed;
      case 'debt_error_update_failed':
        return l10n.debt_error_update_failed;
      case 'debt_error_delete_failed':
        return l10n.debt_error_delete_failed;

      // Transaction Errors (C-2)
      case 'transaction_error_create_failed':
        return l10n.transaction_error_create_failed;
      case 'transaction_error_fetch_failed':
        return l10n.transaction_error_fetch_failed;
      case 'transaction_error_update_failed':
        return l10n.transaction_error_update_failed;
      case 'transaction_error_delete_failed':
        return l10n.transaction_error_delete_failed;

      // Wallet Errors (C-2)
      case 'wallet_error_status_update_failed':
        return l10n.wallet_error_status_update_failed;

      // Auth Errors (H-2/H-3)
      case 'auth_error_must_login_first':
        return l10n.auth_error_must_login_first;
      case 'auth_error_store_already_exists':
        return l10n.auth_error_store_already_exists;
      case 'auth_error_employee_fetch_failed':
        return l10n.auth_error_employee_fetch_failed;

      // Generic fallback (H-4)
      case 'error_unexpected':
        return l10n.error_unexpected;

      // Carrier mismatch errors
      case 'carrier_mismatch_vodafone':
        return l10n.carrier_mismatch_vodafone;
      case 'carrier_mismatch_etisalat':
        return l10n.carrier_mismatch_etisalat;
      case 'carrier_mismatch_orange':
        return l10n.carrier_mismatch_orange;
      case 'carrier_mismatch_we':
        return l10n.carrier_mismatch_we;

      default:
        return errorCode;
    }
  }
}
