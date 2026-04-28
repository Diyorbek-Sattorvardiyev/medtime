import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../api_client.dart';
import '../auth_api.dart';
import '../utils/app_events.dart';

class OfflineMedicineQueue {
  const OfflineMedicineQueue._();

  static const _key = 'offline_medicine_create_queue';

  static Future<int> pendingCount() async {
    final prefs = await SharedPreferences.getInstance();
    return _read(prefs).length;
  }

  static Future<void> enqueueCreate(Map<String, dynamic> body) async {
    final prefs = await SharedPreferences.getInstance();
    final items = _read(prefs)
      ..add({
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'created_at': DateTime.now().toIso8601String(),
        'body': body,
      });
    await prefs.setString(_key, jsonEncode(items));
  }

  static Future<int> sync({ApiClient? api}) async {
    final prefs = await SharedPreferences.getInstance();
    final items = _read(prefs);
    if (items.isEmpty) return 0;

    final client = api ?? ApiClient();
    final remaining = <Map<String, dynamic>>[];
    var synced = 0;

    for (final item in items) {
      final body = item['body'];
      if (body is! Map) continue;
      try {
        await client.createMedicine(Map<String, dynamic>.from(body));
        synced++;
      } on AuthApiException catch (error) {
        if (error.kind == AuthApiErrorKind.network ||
            error.kind == AuthApiErrorKind.server) {
          remaining.add(item);
          continue;
        }
        // Validation/auth errors should not block all future sync attempts.
      }
    }

    await prefs.setString(_key, jsonEncode(remaining));
    if (synced > 0) AppEvents.notifyMedicineChanged();
    return synced;
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
