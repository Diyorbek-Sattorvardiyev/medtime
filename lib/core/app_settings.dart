import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { uz, en, ru }

class AppSettings extends ChangeNotifier {
  AppSettings._(this._prefs) {
    _darkMode = _prefs.getBool(_darkModeKey) ?? false;
    final code = _prefs.getString(_languageKey) ?? AppLanguage.uz.name;
    _language = AppLanguage.values.firstWhere(
      (item) => item.name == code,
      orElse: () => AppLanguage.uz,
    );
  }

  static const _darkModeKey = 'dark_mode';
  static const _languageKey = 'language';

  final SharedPreferences _prefs;
  late bool _darkMode;
  late AppLanguage _language;

  bool get darkMode => _darkMode;
  AppLanguage get language => _language;

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings._(prefs);
  }

  Future<void> setDarkMode(bool value) async {
    _darkMode = value;
    notifyListeners();
    await _prefs.setBool(_darkModeKey, value);
  }

  Future<void> setLanguage(AppLanguage value) async {
    _language = value;
    notifyListeners();
    await _prefs.setString(_languageKey, value.name);
  }
}

class AppSettingsScope extends InheritedNotifier<AppSettings> {
  const AppSettingsScope({
    super.key,
    required AppSettings settings,
    required super.child,
  }) : super(notifier: settings);

  static AppSettings of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppSettingsScope>();
    assert(scope != null, 'AppSettingsScope not found');
    return scope!.notifier!;
  }
}

class AppStrings {
  AppStrings(this.language);

  final AppLanguage language;

  static AppStrings of(BuildContext context) =>
      AppStrings(AppSettingsScope.of(context).language);

  String get profile => _pick('Profil', 'Profile', 'Профиль');
  String get home => _pick('Asosiy', 'Home', 'Главная');
  String get medicines => _pick('Dorilar', 'Medicines', 'Лекарства');
  String get stats => _pick('Statistika', 'Stats', 'Статистика');
  String get add => _pick("Qo'shish", 'Add', 'Добавить');
  String get greeting => _pick('Salom, Ism!', 'Hello, Name!', 'Привет, Имя!');
  String get todayMedicines =>
      _pick('Bugungi dorilar', "Today's medicines", 'Лекарства сегодня');
  String get progressIndicator =>
      _pick('Progress indicator', 'Progress indicator', 'Индикатор прогресса');
  String get completed => _pick('Bajarilish', 'Completed', 'Выполнено');
  String get remaining => _pick('qoldi', 'left', 'осталось');
  String get noMedicinesToday => _pick(
    'Bugun uchun dorilar yo‘q',
    'No medicines today',
    'Сегодня лекарств нет',
  );
  String get notifications =>
      _pick('Bildirishnomalar', 'Notifications', 'Уведомления');
  String get reminderPermissions => _pick(
    'Eslatma ruxsatlari',
    'Reminder permissions',
    'Разрешения напоминаний',
  );
  String get refillReminder => _pick(
    'Dori tugashini eslatish',
    'Refill reminder',
    'Напомнить о пополнении',
  );
  String get settings => _pick('Sozlamalar', 'Settings', 'Настройки');
  String get darkMode => _pick('Qorong‘i rejim', 'Dark Mode', 'Темная тема');
  String get appNotification =>
      _pick('Ilova bildirishnomasi', 'App Notification', 'Уведомления');
  String get languageText => _pick('Til', 'Language', 'Язык');
  String get security => _pick('Xavfsizlik', 'Security', 'Безопасность');
  String get editProfile =>
      _pick('Profilni tahrirlash', 'Edit profile', 'Редактировать профиль');
  String get logout => _pick('Chiqish', 'Logout', 'Выйти');
  String get help => _pick('Yordam', 'Help', 'Помощь');
  String get feedback => _pick('Feedback', 'Feedback', 'Обратная связь');
  String get rate => _pick('Baholash', 'Rate', 'Оценить');
  String get about => _pick('Ilova haqida', 'About app', 'О приложении');
  String get family => _pick("Oila a'zolari", 'Family members', 'Члены семьи');
  String get quickStats =>
      _pick('Tezkor statistika', 'Quick stats', 'Быстрая статистика');
  String get notificationIntegration => _pick(
    'Bildirishnoma integratsiyasi',
    'Notification integration',
    'Интеграция уведомлений',
  );
  String get medicineDetails =>
      _pick('Dori tafsiloti', 'Medicine details', 'Детали лекарства');
  String get todayStatus =>
      _pick('Today status', 'Today status', 'Статус сегодня');
  String get history => _pick('Tarix', 'History', 'История');
  String get save => _pick('Saqlash', 'Save', 'Сохранить');

  String _pick(String uz, String en, String ru) {
    return switch (language) {
      AppLanguage.uz => uz,
      AppLanguage.en => en,
      AppLanguage.ru => ru,
    };
  }
}
