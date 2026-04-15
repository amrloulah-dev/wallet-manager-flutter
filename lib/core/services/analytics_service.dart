import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  static bool isTestMode = false;
  static FirebaseAnalytics get _analytics => FirebaseAnalytics.instance;

  static FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  static Future<void> logAppOpen() async {
    if (isTestMode) return;
    await _analytics.logAppOpen();
  }

  static Future<void> logScreenView(String screenName) async {
    if (isTestMode) return;
    await _analytics.logScreenView(screenName: screenName);
  }

  static Future<void> logTransactionCreated(String type) async {
    if (isTestMode) return;
    await _analytics.logEvent(
      name: 'transaction_created',
      parameters: {
        'transaction_type': type,
      },
    );
  }

  static Future<void> logDebtAdded() async {
    if (isTestMode) return;
    await _analytics.logEvent(name: 'debt_added');
  }

  static Future<void> logLicenseUpgraded(String plan) async {
    if (isTestMode) return;
    await _analytics.logEvent(
      name: 'license_upgraded',
      parameters: {
        'plan_type': plan,
      },
    );
  }

  static Future<void> logLogin(String method) async {
    if (isTestMode) return;
    await _analytics.logLogin(loginMethod: method);
  }

  static Future<void> logSignUp(String method) async {
    if (isTestMode) return;
    await _analytics.logSignUp(signUpMethod: method);
  }

  static Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {
    if (isTestMode) return;
    await _analytics.setUserProperty(name: name, value: value);
  }

  static Future<void> setUserId(String? id) async {
    if (isTestMode) return;
    await _analytics.setUserId(id: id);
  }

  static Future<void> logError(String error,
      {String? operation, String? severity}) async {
    if (isTestMode) return;
    await _analytics.logEvent(
      name: 'app_error',
      parameters: {
        'error_message': error.length > 100 ? error.substring(0, 100) : error,
        if (operation != null) 'operation': operation,
        if (severity != null) 'severity': severity,
      },
    );
  }
}
