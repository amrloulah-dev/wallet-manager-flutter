import 'package:walletmanager/core/utils/number_parser.dart';
import 'subscription_plan_model.dart';

class NetworkLimits {
  final double dailyReceive;
  final double dailySend;
  final double maxPerTransaction;
  final double monthlyReceive;
  final double monthlySend;

  const NetworkLimits({
    required this.dailyReceive,
    required this.dailySend,
    required this.maxPerTransaction,
    required this.monthlyReceive,
    required this.monthlySend,
  });

  factory NetworkLimits.fromJson(
      Map<String, dynamic>? json, NetworkLimits fallback) {
    if (json == null) return fallback;
    return NetworkLimits(
      dailyReceive:
          NumberParser.toDouble(json['dailyReceive'], fallback.dailyReceive),
      dailySend: NumberParser.toDouble(json['dailySend'], fallback.dailySend),
      maxPerTransaction: NumberParser.toDouble(
          json['maxPerTransaction'], fallback.maxPerTransaction),
      monthlyReceive: NumberParser.toDouble(
          json['monthlyReceive'], fallback.monthlyReceive),
      monthlySend:
          NumberParser.toDouble(json['monthlySend'], fallback.monthlySend),
    );
  }
}

class PlatformSettingsModel {
  final bool isRegistrationOpen;

  // Limits
  final NetworkLimits instapayLimits;
  final NetworkLimits networkCommercialLimits;
  final NetworkLimits networkNewLimits;
  final NetworkLimits networkOldLimits;

  // Fee Limits
  final double minCrossNetworkFee;
  final double maxCrossNetworkFee;
  final double minInstapayFee;
  final double maxInstapayFee;

  // Service Fees
  final double sameNetworkFee;
  final double crossNetworkFeeRate;
  final double instapayFeeRate;

  // Subscriptions
  final int lifetimeCountLimit;
  final int gracePeriodHours;
  final int trialDays;
  final Map<String, SubscriptionPlanModel> plans;

  const PlatformSettingsModel({
    required this.isRegistrationOpen,
    required this.instapayLimits,
    required this.networkCommercialLimits,
    required this.networkNewLimits,
    required this.networkOldLimits,
    required this.minCrossNetworkFee,
    required this.maxCrossNetworkFee,
    required this.minInstapayFee,
    required this.maxInstapayFee,
    required this.sameNetworkFee,
    required this.crossNetworkFeeRate,
    required this.instapayFeeRate,
    required this.lifetimeCountLimit,
    required this.gracePeriodHours,
    required this.trialDays,
    required this.plans,
  });

  factory PlatformSettingsModel.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return const PlatformSettingsModel.defaults();
    }

    final limits = json['limits'] as Map<String, dynamic>? ?? {};
    final feeLimits = json['feeLimits'] as Map<String, dynamic>? ?? {};
    final feeNetworks = feeLimits['networks'] as Map<String, dynamic>? ?? {};
    final feeInstapay = feeLimits['instapay'] as Map<String, dynamic>? ?? {};
    final serviceFees = json['serviceFees'] as Map<String, dynamic>? ?? {};
    final subscriptions = json['subscriptions'] as Map<String, dynamic>? ?? {};

    final plansData = json['plans'] ?? subscriptions['plans'];
    final Map<String, SubscriptionPlanModel> parsedPlans = {};
    if (plansData is Map) {
      plansData.forEach((key, value) {
        if (value is Map) {
          try {
            parsedPlans[key.toString()] = SubscriptionPlanModel.fromMap(
              Map<String, dynamic>.from(value),
            );
          } catch (_) {}
        }
      });
    }

    return PlatformSettingsModel(
      isRegistrationOpen: json['isRegistrationOpen'] as bool? ?? true,
      instapayLimits: NetworkLimits.fromJson(
        limits['instapay'] as Map<String, dynamic>?,
        const PlatformSettingsModel.defaults().instapayLimits,
      ),
      networkCommercialLimits: NetworkLimits.fromJson(
        limits['networkCommercial'] as Map<String, dynamic>?,
        const PlatformSettingsModel.defaults().networkCommercialLimits,
      ),
      networkNewLimits: NetworkLimits.fromJson(
        limits['networkNew'] as Map<String, dynamic>?,
        const PlatformSettingsModel.defaults().networkNewLimits,
      ),
      networkOldLimits: NetworkLimits.fromJson(
        limits['networkOld'] as Map<String, dynamic>?,
        const PlatformSettingsModel.defaults().networkOldLimits,
      ),
      minCrossNetworkFee: NumberParser.toDouble(feeNetworks['min'], 1.0),
      maxCrossNetworkFee: NumberParser.toDouble(feeNetworks['max'], 15.0),
      minInstapayFee: NumberParser.toDouble(feeInstapay['min'], 0.5),
      maxInstapayFee: NumberParser.toDouble(feeInstapay['max'], 20.0),
      sameNetworkFee: NumberParser.toDouble(serviceFees['sameNetwork'], 1.0),
      crossNetworkFeeRate:
          NumberParser.toDouble(serviceFees['crossNetwork'], 0.005),
      instapayFeeRate: NumberParser.toDouble(serviceFees['instapay'], 0.001),
      lifetimeCountLimit:
          NumberParser.toInt(subscriptions['lifetimeCountLimit'], 50),
      gracePeriodHours:
          NumberParser.toInt(subscriptions['gracePeriodHours'], 48),
      trialDays: NumberParser.toInt(subscriptions['trialDays'], 14),
      plans: parsedPlans,
    );
  }

  // Safe defaults matching our exact Firestore schema structure
  const PlatformSettingsModel.defaults()
      : isRegistrationOpen = true,
        instapayLimits = const NetworkLimits(
            dailyReceive: 120000,
            dailySend: 120000,
            maxPerTransaction: 70000,
            monthlyReceive: 400000,
            monthlySend: 400000),
        networkCommercialLimits = const NetworkLimits(
            dailyReceive: 200000,
            dailySend: 200000,
            maxPerTransaction: 200000,
            monthlyReceive: 500000,
            monthlySend: 500000),
        networkNewLimits = const NetworkLimits(
            dailyReceive: 10000,
            dailySend: 10000,
            maxPerTransaction: 30000,
            monthlyReceive: 600000,
            monthlySend: 600000),
        networkOldLimits = const NetworkLimits(
            dailyReceive: 60000,
            dailySend: 80000,
            maxPerTransaction: 70000,
            monthlyReceive: 200000,
            monthlySend: 200000),
        minCrossNetworkFee = 1.0,
        maxCrossNetworkFee = 15.0,
        minInstapayFee = 0.5,
        maxInstapayFee = 20.0,
        sameNetworkFee = 1.0,
        crossNetworkFeeRate = 0.005,
        instapayFeeRate = 0.001,
        lifetimeCountLimit = 50,
        gracePeriodHours = 48,
        trialDays = 14,
        plans = const {};

  // Compatibility getters for legacy code
  double get newWalletTransactionLimit => networkNewLimits.maxPerTransaction;
  double get newWalletMonthlyLimit => networkNewLimits.monthlySend;
  double get oldWalletTransactionLimit => networkOldLimits.maxPerTransaction;
  double get oldWalletMonthlyLimit => networkOldLimits.monthlySend;
  double get registeredStoreTransactionLimit =>
      networkCommercialLimits.maxPerTransaction;
  double get registeredStoreMonthlyLimit => networkCommercialLimits.monthlySend;
  double get instapayTransactionLimit => instapayLimits.maxPerTransaction;
  double get instapayMonthlyLimit => instapayLimits.monthlySend;
  int get trialDurationDays => trialDays;

  Map<String, dynamic> toJson() {
    return {
      'isRegistrationOpen': isRegistrationOpen,
      'limits': {
        'instapay': {
          'dailyReceive': instapayLimits.dailyReceive,
          'dailySend': instapayLimits.dailySend,
          'maxPerTransaction': instapayLimits.maxPerTransaction,
          'monthlyReceive': instapayLimits.monthlyReceive,
          'monthlySend': instapayLimits.monthlySend,
        },
        'networkCommercial': {
          'dailyReceive': networkCommercialLimits.dailyReceive,
          'dailySend': networkCommercialLimits.dailySend,
          'maxPerTransaction': networkCommercialLimits.maxPerTransaction,
          'monthlyReceive': networkCommercialLimits.monthlyReceive,
          'monthlySend': networkCommercialLimits.monthlySend,
        },
        'networkNew': {
          'dailyReceive': networkNewLimits.dailyReceive,
          'dailySend': networkNewLimits.dailySend,
          'maxPerTransaction': networkNewLimits.maxPerTransaction,
          'monthlyReceive': networkNewLimits.monthlyReceive,
          'monthlySend': networkNewLimits.monthlySend,
        },
        'networkOld': {
          'dailyReceive': networkOldLimits.dailyReceive,
          'dailySend': networkOldLimits.dailySend,
          'maxPerTransaction': networkOldLimits.maxPerTransaction,
          'monthlyReceive': networkOldLimits.monthlyReceive,
          'monthlySend': networkOldLimits.monthlySend,
        },
      },
      'feeLimits': {
        'networks': {
          'min': minCrossNetworkFee,
          'max': maxCrossNetworkFee,
        },
        'instapay': {
          'min': minInstapayFee,
          'max': maxInstapayFee,
        },
      },
      'serviceFees': {
        'sameNetwork': sameNetworkFee,
        'crossNetwork': crossNetworkFeeRate,
        'instapay': instapayFeeRate,
      },
      'subscriptions': {
        'lifetimeCountLimit': lifetimeCountLimit,
        'gracePeriodHours': gracePeriodHours,
        'trialDays': trialDays,
        'plans': plans.map((key, value) => MapEntry(key, value.toMap())),
      },
    };
  }
}
