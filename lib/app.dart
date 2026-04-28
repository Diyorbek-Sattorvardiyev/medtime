import 'package:flutter/material.dart';

import 'core/app_routes.dart';
import 'core/app_settings.dart';
import 'core/app_theme.dart';
import 'core/reminder_service.dart';

class MedReminderApp extends StatelessWidget {
  const MedReminderApp({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return AppSettingsScope(
      settings: settings,
      child: AnimatedBuilder(
        animation: settings,
        builder: (context, _) {
          return MaterialApp(
            navigatorKey: ReminderService.navigatorKey,
            title: 'MedReminder',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.light,
            initialRoute: AppRoutes.splash,
            onGenerateRoute: AppRoutes.onGenerateRoute,
          );
        },
      ),
    );
  }
}
