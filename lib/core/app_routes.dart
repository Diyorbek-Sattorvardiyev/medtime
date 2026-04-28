import 'package:flutter/material.dart';

import '../features/auth/login_screen.dart';
import '../features/add/add_medicine_screen.dart';
import '../features/ai/ai_assistant_screen.dart';
import '../features/calendar/calendar_screen.dart';
import '../features/family/family_screen.dart';
import '../features/history/history_screen.dart';
import '../features/home/app_shell.dart';
import '../features/medicines/medicine_details_screen.dart';
import '../features/notifications/notification_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/onboarding/splash_screen.dart';
import '../features/reminders/reminder_access_screen.dart';
import 'page_transitions.dart';

class AppRoutes {
  const AppRoutes._();

  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const home = '/home';
  static const addMedicine = '/add-medicine';
  static const details = '/details';
  static const calendar = '/calendar';
  static const history = '/history';
  static const family = '/family';
  static const notifications = '/notifications';
  static const aiAssistant = '/ai-assistant';
  static const reminderAccess = '/reminder-access';

  static Route<void> onGenerateRoute(RouteSettings settings) {
    if (settings.name == addMedicine) {
      return ModalBottomSheetRoute<void>(
        settings: settings,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          final topGap =
              MediaQuery.paddingOf(context).top + kToolbarHeight + 10;
          return Padding(
            padding: EdgeInsets.only(top: topGap),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              child: AddMedicineScreen(
                initialMedicine: settings.arguments is Map<String, dynamic>
                    ? settings.arguments as Map<String, dynamic>
                    : null,
                initialFamilyMemberId: settings.arguments is int
                    ? settings.arguments as int
                    : null,
              ),
            ),
          );
        },
      );
    }

    final Widget page = switch (settings.name) {
      splash => const SplashScreen(),
      onboarding => const OnboardingScreen(),
      login => const LoginScreen(),
      home => const AppShell(),
      details => MedicineDetailsScreen(
        medicineId: settings.arguments is int
            ? settings.arguments as int
            : null,
      ),
      calendar => const CalendarScreen(),
      history => const HistoryScreen(),
      family => const FamilyScreen(),
      notifications => const NotificationScreen(),
      aiAssistant => const AiAssistantScreen(),
      reminderAccess => const ReminderAccessScreen(),
      _ => const SplashScreen(),
    };

    return AppPageRoute(page: page, settings: settings);
  }
}
