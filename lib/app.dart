import 'package:flutter/material.dart';

import 'core/app_routes.dart';
import 'core/app_settings.dart';
import 'core/app_theme.dart';
import 'core/reminder_service.dart';

class MedReminderApp extends StatefulWidget {
  const MedReminderApp({super.key, required this.settings});

  final AppSettings settings;

  @override
  State<MedReminderApp> createState() => _MedReminderAppState();
}

class _MedReminderAppState extends State<MedReminderApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ReminderService.instance.showPendingLaunchReminder();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppSettingsScope(
      settings: widget.settings,
      child: AnimatedBuilder(
        animation: widget.settings,
        builder: (context, _) {
          return MaterialApp(
            navigatorKey: ReminderService.navigatorKey,
            title: 'MedReminder',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: widget.settings.darkMode
                ? ThemeMode.dark
                : ThemeMode.light,
            initialRoute: AppRoutes.splash,
            onGenerateRoute: AppRoutes.onGenerateRoute,
          );
        },
      ),
    );
  }
}
