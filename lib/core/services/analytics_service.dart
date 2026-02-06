import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  static FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  static Future<void> logAppOpen() async {
    await _analytics.logAppOpen();
  }

  static Future<void> logScreenView(String screenName) async {
    await _analytics.logScreenView(screenName: screenName);
  }

  static Future<void> logTransactionCreated(String type) async {
    await _analytics.logEvent(
      name: 'transaction_created',
      parameters: {
        'transaction_type': type,
      },
    );
  }

  static Future<void> logDebtAdded() async {
    await _analytics.logEvent(name: 'debt_added');
  }

  static Future<void> logLicenseUpgraded(String plan) async {
    await _analytics.logEvent(
      name: 'license_upgraded',
      parameters: {
        'plan_type': plan,
      },
    );
  }

  static Future<void> logLogin(String method) async {
    await _analytics.logLogin(loginMethod: method);
  }

  static Future<void> logSignUp(String method) async {
    await _analytics.logSignUp(signUpMethod: method);
  }

  static Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {
    await _analytics.setUserProperty(name: name, value: value);
  }

  static Future<void> setUserId(String? id) async {
    await _analytics.setUserId(id: id);
  }
}
