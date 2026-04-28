import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/app_settings.dart';
import 'core/reminder_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ReminderService.instance.initialize();
  final settings = await AppSettings.load();
  runApp(ProviderScope(child: MedReminderApp(settings: settings)));
}
