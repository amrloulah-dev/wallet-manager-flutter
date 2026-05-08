import 'package:flutter/foundation.dart';
import 'package:ntp/ntp.dart';
import '../core/errors/app_exceptions.dart';

class TimeService {
  static int _offset = 0;
  static bool _isSynced = false;

  static Future<void> sync() async {
    try {
      final ntpTime = await NTP.now();
      _offset = ntpTime.difference(DateTime.now()).inMilliseconds;
      _isSynced = true;
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('🔴 [TIME_SERVICE] CRITICAL: NTP sync failed - $e\n$stack');
      }
      throw DomainException(
        'time_error_sync_failed',
      );
    }
  }

  static DateTime now() {
    return DateTime.now().add(Duration(milliseconds: _offset));
  }

  static bool get isSynced => _isSynced;
}
