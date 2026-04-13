import 'package:ntp/ntp.dart';

class TimeService {
  static int _offset = 0;
  static bool _isSynced = false;

  static Future<void> sync() async {
    try {
      final ntpTime = await NTP.now();
      _offset = ntpTime.difference(DateTime.now()).inMilliseconds;
      _isSynced = true;
    } catch (e) {
      // Fallback to local time if NTP sync fails
      _offset = 0;
      _isSynced = false;
    }
  }

  static DateTime now() {
    return DateTime.now().add(Duration(milliseconds: _offset));
  }
  
  static bool get isSynced => _isSynced;
}
