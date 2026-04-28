import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medtime/app.dart';
import 'package:medtime/core/app_settings.dart';

void main() {
  testWidgets('MedReminder onboarding flow opens login screen', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.load();
    await tester.pumpWidget(MedReminderApp(settings: settings));

    expect(find.text('MedReminder'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pumpAndSettle();

    expect(find.text('Dorini unutma'), findsOneWidget);

    await tester.tap(find.text('Keyingisi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keyingisi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Boshlash'));
    await tester.pumpAndSettle();

    expect(find.text('Email'), findsWidgets);
    expect(find.text('Password'), findsWidgets);
  });
}
