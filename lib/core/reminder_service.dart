import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'api_client.dart';
import 'auth_api.dart';
import 'storage/offline_action_queue.dart';
import 'utils/app_events.dart';
import 'voice_service.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  ReminderService.handleBackgroundResponse(response);
}

class ReminderService {
  ReminderService._();

  static final instance = ReminderService._();
  static final navigatorKey = GlobalKey<NavigatorState>();

  final _plugin = FlutterLocalNotificationsPlugin();
  final _timers = <Timer>[];
  var _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Tashkent'));
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    final ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: [
        DarwinNotificationCategory(
          'medicine_reminder',
          actions: [
            DarwinNotificationAction.plain('taken', 'Ichdim'),
            DarwinNotificationAction.plain(
              'snooze',
              'Keyinroq',
              options: {DarwinNotificationActionOption.foreground},
            ),
            DarwinNotificationAction.plain('missed', "O'tkazdim"),
          ],
        ),
      ],
    );
    await _plugin.initialize(
      settings: InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _handleForegroundResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();
    _initialized = true;
  }

  Future<void> syncFromMedicineMaps(
    List<Map<String, dynamic>> medicines,
  ) async {
    await initialize();
    await _plugin.cancelAll();
    _clearTimers();
    for (final medicine in medicines) {
      await scheduleMedicine(medicine);
    }
  }

  Future<void> scheduleMedicine(Map<String, dynamic> medicine) async {
    final medicineId = _int(medicine['id'] ?? medicine['medicine_id']);
    if (medicineId == null || medicine['active'] == false) return;

    final schedules = _schedules(medicine);
    final start = _date(medicine['start_date']) ?? DateTime.now();
    final end = _date(medicine['end_date']);
    final now = DateTime.now();
    var scheduledCount = 0;
    for (final schedule in schedules) {
      if (scheduledCount >= 40) break;
      final scheduleId = _int(schedule['id'] ?? schedule['schedule_id']);
      final time = _time(schedule['time']);
      final days = (schedule['repeat_days'] as List? ?? const [])
          .map((e) => e.toString())
          .toSet();
      if (scheduleId == null || time == null || days.isEmpty) continue;

      for (var offset = 0; offset < 21; offset++) {
        if (scheduledCount >= 40) break;
        final day = DateTime(now.year, now.month, now.day + offset);
        if (day.isBefore(DateTime(start.year, start.month, start.day))) {
          continue;
        }
        if (end != null &&
            day.isAfter(DateTime(end.year, end.month, end.day))) {
          continue;
        }
        if (!days.contains(_weekday(day))) continue;
        final plannedAt = DateTime(
          day.year,
          day.month,
          day.day,
          time.hour,
          time.minute,
        );
        final reminderAt = plannedAt.subtract(
          Duration(
            minutes:
                _int(schedule['reminder_before_minutes'])?.clamp(0, 1440) ?? 0,
          ),
        );
        if (!reminderAt.isAfter(now)) continue;

        final payload = ReminderPayload(
          medicineId: medicineId,
          scheduleId: scheduleId,
          plannedAt: plannedAt.toIso8601String(),
          name: (medicine['name'] ?? 'Dori').toString(),
          dosage: (medicine['dosage'] ?? '').toString(),
        );
        await _schedule(payload, reminderAt);
        _scheduleInAppDialog(payload, reminderAt);
        scheduledCount++;
      }
    }
    await _scheduleRefillReminder(medicine, medicineId);
  }

  Future<void> _scheduleRefillReminder(
    Map<String, dynamic> medicine,
    int medicineId,
  ) async {
    if (medicine['refill_reminder_enabled'] != true ||
        medicine['refill_needed'] != true) {
      return;
    }
    final name = (medicine['name'] ?? 'Dori').toString();
    final stock = medicine['stock_quantity']?.toString() ?? '';
    await _plugin.zonedSchedule(
      id: Object.hash(medicineId, 'refill') & 0x7fffffff,
      title: 'Dori tugayapti',
      body: '$name zaxirasi kamaydi${stock.isEmpty ? '' : ': $stock qoldi'}',
      scheduledDate: tz.TZDateTime.from(
        DateTime.now().add(const Duration(minutes: 1)),
        tz.local,
      ),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'medicine_refills',
          'Dori zaxirasi',
          channelDescription: 'Dori tugashiga yaqin eslatadi',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> _schedule(ReminderPayload payload, DateTime reminderAt) async {
    await _plugin.zonedSchedule(
      id: payload.notificationId,
      title: 'Dori vaqti',
      body: '${payload.name} ${payload.dosage}'.trim(),
      scheduledDate: tz.TZDateTime.from(reminderAt, tz.local),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'medicine_reminders',
          'Dori eslatmalari',
          channelDescription: 'Dori qabul qilish vaqti kelganda ogohlantiradi',
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          fullScreenIntent: true,
          playSound: true,
          enableVibration: true,
          actions: const [
            AndroidNotificationAction('taken', 'Ichdim'),
            AndroidNotificationAction('snooze', 'Keyinroq'),
            AndroidNotificationAction('missed', "O'tkazdim"),
          ],
        ),
        iOS: const DarwinNotificationDetails(
          categoryIdentifier: 'medicine_reminder',
          presentAlert: true,
          presentSound: true,
        ),
      ),
      payload: payload.toJsonString(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  void _scheduleInAppDialog(ReminderPayload payload, DateTime reminderAt) {
    final delay = reminderAt.difference(DateTime.now());
    if (delay.isNegative || delay > const Duration(days: 1)) return;
    _timers.add(Timer(delay, () => showReminderDialog(payload)));
  }

  Future<void> showReminderDialog(ReminderPayload payload) async {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    await VoiceService.instance.speak('${payload.name} ichish vaqti keldi');
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Dori vaqti'),
        content: Text('${payload.name} ${payload.dosage}\nQabul qildingizmi?'),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await applyAction(payload, 'missed');
            },
            child: const Text("O'tkazdim"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await applyAction(payload, 'snooze');
            },
            child: const Text('Keyinroq'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await applyAction(payload, 'taken');
            },
            child: const Text('Ichdim'),
          ),
        ],
      ),
    );
  }

  Future<void> applyAction(ReminderPayload payload, String action) async {
    final api = ApiClient();
    try {
      switch (action) {
        case 'taken':
          await api.markTaken(
            medicineId: payload.medicineId,
            scheduleId: payload.scheduleId,
            plannedAt: payload.plannedAt,
          );
        case 'missed':
          await api.markMissed(
            medicineId: payload.medicineId,
            scheduleId: payload.scheduleId,
            plannedAt: payload.plannedAt,
          );
        default:
          await api.snooze(
            medicineId: payload.medicineId,
            scheduleId: payload.scheduleId,
            plannedAt: payload.plannedAt,
            minutes: 10,
          );
          final next = DateTime.now().add(const Duration(minutes: 10));
          await _schedule(payload, next);
          _scheduleInAppDialog(payload, next);
      }
      AppEvents.notifyMedicineChanged();
    } on AuthApiException catch (error) {
      if (error.kind == AuthApiErrorKind.network ||
          error.kind == AuthApiErrorKind.server) {
        await OfflineActionQueue.enqueue(
          medicineId: payload.medicineId,
          scheduleId: payload.scheduleId,
          plannedAt: payload.plannedAt,
          action: action,
          minutes: action == 'snooze' ? 10 : null,
        );
        AppEvents.notifyMedicineChanged();
      }
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  void _handleForegroundResponse(NotificationResponse response) {
    final payload = ReminderPayload.tryParse(response.payload);
    if (payload == null) return;
    final action = response.actionId?.isNotEmpty == true
        ? response.actionId!
        : 'open';
    if (action == 'open') {
      showReminderDialog(payload);
    } else {
      applyAction(payload, action);
    }
  }

  static Future<void> handleBackgroundResponse(
    NotificationResponse response,
  ) async {
    WidgetsFlutterBinding.ensureInitialized();
    final payload = ReminderPayload.tryParse(response.payload);
    if (payload == null) return;
    final action = response.actionId?.isNotEmpty == true
        ? response.actionId!
        : 'snooze';
    final api = ApiClient();
    try {
      switch (action) {
        case 'taken':
          await api.markTaken(
            medicineId: payload.medicineId,
            scheduleId: payload.scheduleId,
            plannedAt: payload.plannedAt,
          );
        case 'missed':
          await api.markMissed(
            medicineId: payload.medicineId,
            scheduleId: payload.scheduleId,
            plannedAt: payload.plannedAt,
          );
        default:
          await api.snooze(
            medicineId: payload.medicineId,
            scheduleId: payload.scheduleId,
            plannedAt: payload.plannedAt,
            minutes: 10,
          );
      }
      AppEvents.notifyMedicineChanged();
    } on AuthApiException catch (error) {
      if (error.kind == AuthApiErrorKind.network ||
          error.kind == AuthApiErrorKind.server) {
        await OfflineActionQueue.enqueue(
          medicineId: payload.medicineId,
          scheduleId: payload.scheduleId,
          plannedAt: payload.plannedAt,
          action: action,
          minutes: action == 'snooze' ? 10 : null,
        );
      }
    } catch (_) {}
  }

  void _clearTimers() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
  }

  static List<Map<String, dynamic>> _schedules(Map<String, dynamic> medicine) {
    final schedules = medicine['schedules'];
    if (schedules is List) {
      return schedules.whereType<Map<String, dynamic>>().toList();
    }
    final schedule = medicine['schedule'];
    if (schedule is Map<String, dynamic>) return [schedule];
    return const [];
  }

  static int? _int(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  static DateTime? _date(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static TimeOfDay? _time(Object? value) {
    final text = value?.toString();
    if (text == null || !text.contains(':')) return null;
    final parts = text.split(':');
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  static String _weekday(DateTime date) {
    return const [
      'MON',
      'TUE',
      'WED',
      'THU',
      'FRI',
      'SAT',
      'SUN',
    ][date.weekday - 1];
  }
}

class ReminderPayload {
  const ReminderPayload({
    required this.medicineId,
    required this.scheduleId,
    required this.plannedAt,
    required this.name,
    required this.dosage,
  });

  final int medicineId;
  final int scheduleId;
  final String plannedAt;
  final String name;
  final String dosage;

  int get notificationId =>
      Object.hash(medicineId, scheduleId, plannedAt) & 0x7fffffff;

  String toJsonString() => jsonEncode({
    'medicine_id': medicineId,
    'schedule_id': scheduleId,
    'planned_at': plannedAt,
    'name': name,
    'dosage': dosage,
  });

  static ReminderPayload? tryParse(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      final json = jsonDecode(value) as Map<String, dynamic>;
      return ReminderPayload(
        medicineId: int.parse(json['medicine_id'].toString()),
        scheduleId: int.parse(json['schedule_id'].toString()),
        plannedAt: json['planned_at'].toString(),
        name: json['name'].toString(),
        dosage: json['dosage'].toString(),
      );
    } catch (_) {
      return null;
    }
  }
}
