import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class ReminderPermissionState {
  const ReminderPermissionState({
    required this.notificationsEnabled,
    required this.exactAlarmsEnabled,
  });

  final bool notificationsEnabled;
  final bool exactAlarmsEnabled;
}

class PermissionService {
  PermissionService._();

  static final instance = PermissionService._();
  static const _channel = MethodChannel('medtime/system_settings');

  final _notifications = FlutterLocalNotificationsPlugin();

  Future<ReminderPermissionState> loadState() async {
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final notifications = await android?.areNotificationsEnabled() ?? true;
    final exact = await android?.canScheduleExactNotifications() ?? true;
    return ReminderPermissionState(
      notificationsEnabled: notifications,
      exactAlarmsEnabled: exact,
    );
  }

  Future<void> requestNotifications() async {
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestNotificationsPermission();
  }

  Future<void> requestExactAlarms() async {
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestExactAlarmsPermission();
  }

  Future<void> openAppSettings() async {
    try {
      await _channel.invokeMethod<void>('openAppSettings');
    } on MissingPluginException {
      // Native shortcut is Android-only in this app.
    }
  }

  Future<void> openBatterySettings() async {
    try {
      await _channel.invokeMethod<void>('openBatterySettings');
    } on MissingPluginException {
      // Native shortcut is Android-only in this app.
    }
  }
}
