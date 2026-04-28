import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'api_client.dart';
import 'app_colors.dart';
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
  var _syncInFlight = false;
  String? _lastSyncSignature;
  ReminderPayload? _pendingLaunchPayload;

  Future<void> initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Tashkent'));

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
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    final launchResponse = launchDetails?.notificationResponse;
    if (launchDetails?.didNotificationLaunchApp == true) {
      _pendingLaunchPayload = ReminderPayload.tryParse(launchResponse?.payload);
    }

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();
    _initialized = true;
  }

  Future<void> showPendingLaunchReminder() async {
    final payload = _pendingLaunchPayload;
    if (payload == null) return;
    _pendingLaunchPayload = null;
    await Future<void>.delayed(const Duration(milliseconds: 350));
    await showReminderDialog(payload);
  }

  Future<void> syncFromMedicineMaps(
    List<Map<String, dynamic>> medicines,
  ) async {
    final signature = _syncSignature(medicines);
    if (_syncInFlight || signature == _lastSyncSignature) return;
    _syncInFlight = true;
    await initialize();
    try {
      await _plugin.cancelAll();
      _clearTimers();
      for (final medicine in medicines) {
        await scheduleMedicine(medicine);
      }
      _lastSyncSignature = signature;
    } finally {
      _syncInFlight = false;
    }
  }

  Future<void> scheduleMedicine(Map<String, dynamic> medicine) async {
    await initialize();
    final medicineId = _int(medicine['id'] ?? medicine['medicine_id']);
    if (medicineId == null || medicine['active'] == false) return;

    final schedules = _schedules(medicine);
    final start = _date(medicine['start_date']) ?? DateTime.now();
    final end = _date(medicine['end_date']);
    final now = _tashkentNow();
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
        _tashkentNow().add(const Duration(minutes: 1)),
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
          'medicine_reminder_alarms',
          'Dori budilniklari',
          channelDescription:
              'Dori qabul qilish vaqti kelganda budilnik kabi ogohlantiradi',
          importance: Importance.max,
          channelBypassDnd: true,
          priority: Priority.max,
          visibility: NotificationVisibility.public,
          category: AndroidNotificationCategory.alarm,
          fullScreenIntent: true,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 700, 250, 700, 250, 900]),
          audioAttributesUsage: AudioAttributesUsage.alarm,
          color: AppColors.primary,
          colorized: true,
          showWhen: true,
          autoCancel: false,
          ticker: 'Dori vaqti',
          actions: const [
            AndroidNotificationAction(
              'taken',
              'Ichdim',
              titleColor: AppColors.primary,
              semanticAction: SemanticAction.markAsRead,
            ),
            AndroidNotificationAction(
              'snooze',
              'Keyin',
              titleColor: AppColors.accent,
              semanticAction: SemanticAction.archive,
            ),
            AndroidNotificationAction(
              'missed',
              "O'tkazdim",
              titleColor: AppColors.error,
              semanticAction: SemanticAction.delete,
            ),
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
    final delay = reminderAt.difference(_tashkentNow());
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
      builder: (context) => _ReminderAlarmDialog(
        payload: payload,
        onAction: (action) async {
          Navigator.pop(context);
          await applyAction(payload, action);
        },
      ),
    );
  }

  Future<void> applyAction(ReminderPayload payload, String action) async {
    final api = ApiClient();
    try {
      await _plugin.cancel(id: payload.notificationId);
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
          final next = _tashkentNow().add(const Duration(minutes: 10));
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

  static String _syncSignature(List<Map<String, dynamic>> medicines) {
    final parts = <String>[];
    for (final medicine in medicines) {
      final schedules = _schedules(medicine)
          .map(
            (schedule) =>
                '${schedule['id'] ?? schedule['schedule_id']}:${schedule['time']}:'
                '${(schedule['repeat_days'] as List? ?? const []).join(',')}:'
                '${schedule['reminder_before_minutes']}',
          )
          .join('|');
      parts.add(
        '${medicine['id'] ?? medicine['medicine_id']}:${medicine['active']}:'
        '${medicine['start_date']}:${medicine['end_date']}:'
        '${medicine['refill_reminder_enabled']}:${medicine['refill_needed']}:'
        '${medicine['stock_quantity']}:$schedules',
      );
    }
    parts.sort();
    return parts.join(';');
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

  static DateTime _tashkentNow() => tz.TZDateTime.now(tz.local);
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

class _ReminderAlarmDialog extends StatelessWidget {
  const _ReminderAlarmDialog({required this.payload, required this.onAction});

  final ReminderPayload payload;
  final Future<void> Function(String action) onAction;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppColors.floatingShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.successSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.medication_outlined,
                    color: AppColors.primary,
                    size: 25,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payload.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Dosage: ${payload.dosage.isEmpty ? '-' : payload.dosage}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => onAction('snooze'),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _AlarmActionButton(
                    label: 'Ichdim',
                    icon: Icons.check_rounded,
                    color: AppColors.primary,
                    onTap: () => onAction('taken'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _AlarmActionButton(
                    label: 'Keyin',
                    icon: Icons.alarm_rounded,
                    color: AppColors.accent,
                    onTap: () => onAction('snooze'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _AlarmActionButton(
                    label: "O'tkazdim",
                    icon: Icons.close_rounded,
                    color: AppColors.error,
                    onTap: () => onAction('missed'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AlarmActionButton extends StatelessWidget {
  const _AlarmActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: onTap,
        child: SizedBox(
          height: 42,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
