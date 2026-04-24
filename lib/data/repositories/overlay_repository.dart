import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class OverlayRepository {
  Future<void> savePendingTransaction(Map<String, dynamic> txData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_overlay_tx', jsonEncode(txData));
  }
}
