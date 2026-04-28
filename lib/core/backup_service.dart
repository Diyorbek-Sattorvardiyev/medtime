import 'dart:convert';

import 'api_client.dart';

class BackupService {
  BackupService({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  Future<String> exportJson() async {
    final data = {
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'profile': await _api.getProfile(),
      'family_members': await _api.getFamilyMembers(),
      'medicines': await _api.getMedicines(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Future<int> restoreJson(String raw) async {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return 0;
    var restored = 0;

    final members = decoded['family_members'];
    if (members is List) {
      for (final item in members.whereType<Map>()) {
        final name = (item['full_name'] ?? '').toString();
        if (name.isEmpty) continue;
        await _api.createFamilyMember(
          fullName: name,
          relationship: (item['relationship'] ?? 'Boshqa').toString(),
          avatarColor: (item['avatar_color'] ?? '#16a34a').toString(),
        );
        restored++;
      }
    }

    final medicines = decoded['medicines'];
    if (medicines is List) {
      for (final item in medicines.whereType<Map>()) {
        final body = Map<String, dynamic>.from(item);
        body.remove('id');
        body.remove('user_id');
        body.remove('family_member_name');
        body.remove('active');
        body.remove('created_at');
        body.remove('updated_at');
        for (final schedule in (body['schedules'] as List? ?? const [])) {
          if (schedule is Map) {
            schedule.remove('id');
            schedule.remove('medicine_id');
            schedule.remove('created_at');
          }
        }
        if ((body['name'] ?? '').toString().isEmpty) continue;
        await _api.createMedicine(body);
        restored++;
      }
    }

    return restored;
  }
}
