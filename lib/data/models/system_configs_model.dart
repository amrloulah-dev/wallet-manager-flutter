import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/utils/number_parser.dart';

class SystemConfigsModel {
  final int trialDays; // Default 14
  final int gracePeriodHours; // Default 48
  final String vfCashNumber;
  final String instaPayHandle;
  final bool lifetimePlanEnabled;
  final int remainingLifetimeSeats;

  SystemConfigsModel({
    this.trialDays = 14,
    this.gracePeriodHours = 48,
    this.vfCashNumber = '',
    this.instaPayHandle = '',
    this.lifetimePlanEnabled = true,
    this.remainingLifetimeSeats = 50,
  });

  factory SystemConfigsModel.fromFirestore(DocumentSnapshot doc) {
    if (!doc.exists) return SystemConfigsModel();
    final data = doc.data() as Map<String, dynamic>;
    return SystemConfigsModel(
      trialDays: NumberParser.toInt(data['trialDays'], 14),
      gracePeriodHours: NumberParser.toInt(data['gracePeriodHours'], 48),
      vfCashNumber: data['vfCashNumber'] ?? '',
      instaPayHandle: data['instaPayHandle'] ?? '',
      lifetimePlanEnabled: data['lifetimePlanEnabled'] ?? true,
      remainingLifetimeSeats:
          NumberParser.toInt(data['remainingLifetimeSeats'], 50),
    );
  }
}
