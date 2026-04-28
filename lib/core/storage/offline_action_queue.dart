import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../api_client.dart';
import '../auth_api.dart';
import '../utils/app_events.dart';

class OfflineActionQueue {
  const OfflineActionQueue._();

  static const _key = 'offline_medicine_action_queue';

  static Future<int> pendingCount() async {
    final prefs = await SharedPreferences.getInstance();
    return _read(prefs).length;
  }

  static Future<void> enqueue({
    required int medicineId,
    required int scheduleId,
    required String plannedAt,
    required String action,
    int? minutes,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final items = _read(prefs)
      ..add({
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'created_at': DateTime.now().toIso8601String(),
        'medicine_id': medicineId,
        'schedule_id': scheduleId,
        'planned_at': plannedAt,
        'action': action,
        ...(minutes == null ? const {} : {'minutes': minutes}),
      });
    await prefs.setString(_key, jsonEncode(items));
  }

  static Future<int> sync({ApiClient? api}) async {
    final prefs = await SharedPreferences.getInstance();
    final items = _read(prefs);
    if (items.isEmpty) return 0;

    final client = api ?? ApiClient();
    try {
      final processed = await client.syncMedicineActions(items);
      final remaining = items.skip(processed).toList();
      await prefs.setString(_key, jsonEncode(remaining));
      if (processed > 0) AppEvents.notifyMedicineChanged();
      return processed;
    } on AuthApiException catch (error) {
      if (error.kind == AuthApiErrorKind.network ||
          error.kind == AuthApiErrorKind.server) {
        return 0;
      }
      await prefs.remove(_key);
      return 0;
    }
  }

  static List<Map<String, dynamic>> _read(SharedPreferences prefs) {
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.whereType<Map<String, dynamic>>().toList();
    } on FormatException {
      return [];
    }
  }
}
