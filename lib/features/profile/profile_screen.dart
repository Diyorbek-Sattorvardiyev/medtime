import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/app_colors.dart';
import '../../core/app_routes.dart';
import '../../core/app_settings.dart';
import '../../core/auth_api.dart';
import '../../core/permission_service.dart';
import '../../core/voice_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _api = ApiClient();
  var _appNotifications = true;
  var _emailEnabled = true;
  var _telegramConnected = false;
  var _notificationsAllowed = true;
  var _exactAlarmsAllowed = true;
  var _loadingPermissions = true;
  var _loggingOut = false;
  var _loadingProfile = true;
  String? _fullName;
  String? _email;
  String? _avatarUrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadPermissionState();
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    final strings = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.profile)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 116),
          children: [
            _ProfileCard(
              fullName: _fullName ?? 'User Name',
              email: _email ?? 'user@email.com',
              avatarUrl: _avatarUrl,
              loading: _loadingProfile,
              error: _error,
              onRetry: _loadProfile,
              onEdit: _showEditProfile,
            ),
            const SizedBox(height: 18),
            Text(
              strings.notificationIntegration,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _TelegramCard(
              connected: _telegramConnected,
              onConnect: _toggleTelegram,
            ),
            const SizedBox(height: 12),
            _EmailCard(
              enabled: _emailEnabled,
              onChanged: (value) {
                setState(() => _emailEnabled = value);
                _saveNotificationSettings();
              },
            ),
            const SizedBox(height: 12),
            _PermissionCard(
              loading: _loadingPermissions,
              notificationsAllowed: _notificationsAllowed,
              exactAlarmsAllowed: _exactAlarmsAllowed,
              onRefresh: _loadPermissionState,
              onRequestNotifications: _requestNotifications,
              onRequestExactAlarms: _requestExactAlarms,
              onOpenAppSettings: _openAppSettings,
              onOpenBatterySettings: _openBatterySettings,
            ),
            const SizedBox(height: 18),
            Text(
              strings.settings,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            AppCard(
              radius: 16,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _SettingTile(
                    icon: Icons.dark_mode,
                    iconColor: const Color(0xFF64748B),
                    title: strings.darkMode,
                    trailing: Switch(
                      value: settings.darkMode,
                      onChanged: (value) {
                        settings.setDarkMode(value);
                        _saveProfile(settings);
                      },
                    ),
                  ),
                  _SettingTile(
                    icon: Icons.notifications,
                    iconColor: AppColors.accent,
                    title: strings.appNotification,
                    trailing: Switch(
                      value: _appNotifications,
                      onChanged: (value) {
                        setState(() => _appNotifications = value);
                        _saveNotificationSettings();
                      },
                    ),
                  ),
                  _SettingTile(
                    icon: Icons.alarm_on,
                    iconColor: AppColors.primary,
                    title: 'Eslatma ruxsatlari',
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.reminderAccess),
                  ),
                  _SettingTile(
                    icon: Icons.language,
                    iconColor: AppColors.secondary,
                    title: strings.languageText,
                    trailing: DropdownButton<AppLanguage>(
                      value: settings.language,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(
                          value: AppLanguage.uz,
                          child: Text("O'zbek"),
                        ),
                        DropdownMenuItem(
                          value: AppLanguage.en,
                          child: Text('English'),
                        ),
                        DropdownMenuItem(
                          value: AppLanguage.ru,
                          child: Text('Русский'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        settings.setLanguage(value);
                        _saveProfile(settings);
                      },
                    ),
                  ),
                  _SettingTile(
                    icon: Icons.auto_awesome,
                    iconColor: AppColors.secondary,
                    title: 'AI yordamchi',
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.aiAssistant),
                  ),
                  _SettingTile(
                    icon: Icons.volume_up,
                    iconColor: AppColors.accent,
                    title: 'Ovozli eslatma',
                    onTap: _testVoiceReminder,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppButton(
              label: _loggingOut ? 'Kuting...' : strings.logout,
              style: AppButtonStyle.outline,
              onPressed: _loggingOut ? null : _confirmLogout,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppColors.errorSoft,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.error,
                  size: 30,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Chiqmoqchimisiz?',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                'Hisobdan chiqasiz, keyin yana login qilishingiz kerak bo‘ladi.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ActionChip(
                      label: const Center(child: Text('Bekor qilish')),
                      onPressed: () => Navigator.pop(context, false),
                      backgroundColor: AppColors.successSoft,
                      labelStyle: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ActionChip(
                      label: const Center(child: Text('Chiqish')),
                      onPressed: () => Navigator.pop(context, true),
                      backgroundColor: AppColors.error,
                      labelStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (shouldLogout != true) return;

    setState(() => _loggingOut = true);
    try {
      await AuthApi().logout();
    } on AuthApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }

    if (!mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loadingProfile = true;
      _error = null;
    });
    try {
      final json = await _api.getProfile();
      final data = json['data'] is Map<String, dynamic>
          ? json['data'] as Map<String, dynamic>
          : json;
      if (!mounted) return;
      setState(() {
        _fullName = (data['full_name'] ?? data['name'])?.toString();
        _email = data['email']?.toString();
        _avatarUrl = data['avatar_url']?.toString();
        _appNotifications =
            data['app_notifications_enabled'] as bool? ?? _appNotifications;
        _emailEnabled =
            data['email_notifications_enabled'] as bool? ?? _emailEnabled;
        _telegramConnected =
            data['telegram_connected'] as bool? ??
            data['telegram_notifications_enabled'] as bool? ??
            _telegramConnected;
      });
    } on AuthApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  Future<void> _saveProfile(AppSettings settings) async {
    try {
      await _api.updateProfile(
        fullName: _fullName ?? 'User Name',
        language: settings.language.name,
        darkMode: settings.darkMode,
      );
    } on AuthApiException catch (error) {
      _showError(error.message);
    }
  }

  Future<void> _showEditProfile() async {
    final settings = AppSettingsScope.of(context);
    final nameController = TextEditingController(text: _fullName ?? '');
    final emailController = TextEditingController(text: _email ?? '');
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                AppStrings.of(context).editProfile,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Ism',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.mail_outline),
              ),
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'Saqlash',
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;
    try {
      final name = nameController.text.trim();
      final email = emailController.text.trim();
      await _api.updateProfile(
        fullName: name.isEmpty ? (_fullName ?? 'User') : name,
        language: settings.language.name,
        darkMode: settings.darkMode,
      );
      if (email.isNotEmpty && email != _email) {
        await _api.updateEmail(email);
      }
      await _loadProfile();
    } on AuthApiException catch (error) {
      _showError(error.userMessage);
    }
  }

  Future<void> _testVoiceReminder() async {
    await VoiceService.instance.speak('MedReminder eslatma sinovi');
    _showError('Ovozli eslatma sinovi yuborildi');
  }

  Future<void> _saveNotificationSettings() async {
    try {
      await _api.updateNotificationSettings(
        appNotificationsEnabled: _appNotifications,
        emailNotificationsEnabled: _emailEnabled,
        telegramNotificationsEnabled: _telegramConnected,
      );
    } on AuthApiException catch (error) {
      _showError(error.message);
    }
  }

  Future<void> _loadPermissionState() async {
    setState(() => _loadingPermissions = true);
    try {
      final state = await PermissionService.instance.loadState();
      if (!mounted) return;
      setState(() {
        _notificationsAllowed = state.notificationsEnabled;
        _exactAlarmsAllowed = state.exactAlarmsEnabled;
      });
    } finally {
      if (mounted) setState(() => _loadingPermissions = false);
    }
  }

  Future<void> _requestNotifications() async {
    await PermissionService.instance.requestNotifications();
    await _loadPermissionState();
  }

  Future<void> _requestExactAlarms() async {
    await PermissionService.instance.requestExactAlarms();
    await _loadPermissionState();
  }

  Future<void> _openAppSettings() async {
    await PermissionService.instance.openAppSettings();
  }

  Future<void> _openBatterySettings() async {
    await PermissionService.instance.openBatterySettings();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleTelegram() async {
    try {
      if (_telegramConnected) {
        await _api.disconnectTelegram();
        if (mounted) setState(() => _telegramConnected = false);
        return;
      }
      final link = await _api.getTelegramConnectLink();
      final url = (link['telegram_url'] ?? '').toString();
      final code = (link['connect_code'] ?? link['code'] ?? '').toString();
      await Clipboard.setData(ClipboardData(text: url));
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!mounted) return;
      if (!opened) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Telegram ulash'),
            content: Text(
              'Telegram ochilmadi. Botga /start $code yuboring.\n\nLink clipboardga ko‘chirildi:\n$url',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      await _waitForTelegramConnection(code);
    } on AuthApiException catch (error) {
      _showError(error.message);
    }
  }

  Future<void> _waitForTelegramConnection(String code) async {
    if (code.isEmpty) {
      await _loadProfile();
      return;
    }
    for (var attempt = 0; attempt < 15; attempt++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      try {
        final status = await _api.getTelegramConnectStatus(code);
        final connected = status['connected'] as bool? ?? false;
        if (connected) {
          setState(() => _telegramConnected = true);
          _showError('Telegram ulandi');
          return;
        }
      } on AuthApiException {
        // Polling vaqtinchalik xatoda davom etsin.
      }
    }
    await _loadProfile();
    if (!mounted || _telegramConnected) return;
    _showError('Botda Start bosilgandan keyin ulanish holatini yangilang');
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.fullName,
    required this.email,
    required this.avatarUrl,
    required this.loading,
    required this.onRetry,
    required this.onEdit,
    this.error,
  });

  final String fullName;
  final String email;
  final String? avatarUrl;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final avatarImage = _avatarImage(avatarUrl);
    return AppCard(
      radius: 18,
      floating: true,
      child: Column(
        children: [
          Container(
            width: 92,
            height: 92,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 3),
            ),
            child: CircleAvatar(
              backgroundColor: Color(0xFFDFF6E9),
              backgroundImage: avatarImage,
              child: avatarImage == null
                  ? const Icon(Icons.face_6, color: Color(0xFF7A4A2A), size: 58)
                  : null,
            ),
          ),
          const SizedBox(height: 10),
          if (loading)
            const CircularProgressIndicator()
          else if (error != null)
            TextButton(onPressed: onRetry, child: Text(error!))
          else
            Text(
              fullName,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
          const SizedBox(height: 2),
          Text(email, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: OutlinedButton(
              onPressed: onEdit,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                foregroundColor: Theme.of(context).colorScheme.onSurface,
              ),
              child: Text(
                AppStrings.of(context).editProfile,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static ImageProvider<Object>? _avatarImage(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final text = value.trim();
    if (text.startsWith('http://') || text.startsWith('https://')) {
      return NetworkImage(text);
    }
    return FileImage(File(text));
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.loading,
    required this.notificationsAllowed,
    required this.exactAlarmsAllowed,
    required this.onRefresh,
    required this.onRequestNotifications,
    required this.onRequestExactAlarms,
    required this.onOpenAppSettings,
    required this.onOpenBatterySettings,
  });

  final bool loading;
  final bool notificationsAllowed;
  final bool exactAlarmsAllowed;
  final VoidCallback onRefresh;
  final VoidCallback onRequestNotifications;
  final VoidCallback onRequestExactAlarms;
  final VoidCallback onOpenAppSettings;
  final VoidCallback onOpenBatterySettings;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final allReady = notificationsAllowed && exactAlarmsAllowed;
    return AppCard(
      radius: 16,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                allReady ? Icons.verified_outlined : Icons.warning_amber,
                color: allReady ? AppColors.primary : AppColors.accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  strings.reminderPermissions,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Yangilash',
                onPressed: loading ? null : onRefresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (loading)
            const LinearProgressIndicator(minHeight: 3)
          else ...[
            _PermissionLine(
              label: 'Bildirishnoma',
              ok: notificationsAllowed,
              actionLabel: 'Ruxsat',
              onTap: onRequestNotifications,
            ),
            _PermissionLine(
              label: 'Aniq budilnik',
              ok: exactAlarmsAllowed,
              actionLabel: 'Sozlash',
              onTap: onRequestExactAlarms,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onOpenAppSettings,
                    icon: const Icon(Icons.settings, size: 18),
                    label: const Text('Ilova sozlamasi'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onOpenBatterySettings,
                    icon: const Icon(Icons.battery_saver, size: 18),
                    label: const Text('Batareya'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PermissionLine extends StatelessWidget {
  const _PermissionLine({
    required this.label,
    required this.ok,
    required this.actionLabel,
    required this.onTap,
  });

  final String label;
  final bool ok;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        ok ? Icons.check_circle : Icons.error_outline,
        color: ok ? AppColors.primary : AppColors.error,
      ),
      title: Text(label),
      trailing: ok
          ? const Text('OK')
          : TextButton(onPressed: onTap, child: Text(actionLabel)),
    );
  }
}

class _TelegramCard extends StatelessWidget {
  const _TelegramCard({required this.connected, required this.onConnect});

  final bool connected;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 24,
                backgroundColor: Color(0xFF2FA7DD),
                child: Icon(Icons.send, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Telegram bilan bog'lash",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        text: 'Status: ',
                        children: [
                          TextSpan(
                            text: connected ? 'Ulangan' : 'Ulanmagan',
                            style: TextStyle(
                              color: connected
                                  ? AppColors.primary
                                  : AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF123B44),
              ),
              onPressed: onConnect,
              child: Text(connected ? 'Uzish' : "Bog'lash"),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Dori vaqtidan 30 daqiqa oldin Telegram orqali eslatma keladi',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _EmailCard extends StatelessWidget {
  const _EmailCard({required this.enabled, required this.onChanged});

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFA726),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.mail, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Emailni ulash',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        text: 'Status: ',
                        children: [
                          TextSpan(
                            text: 'Ulangan',
                            style: TextStyle(color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Switch(value: enabled, onChanged: onChanged),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            decoration: InputDecoration(
              hintText: 'Email manzilini kiriting',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Dori vaqtidan 30 daqiqa oldin email xabar yuboriladi',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      onTap: onTap,
      leading: Icon(icon, color: iconColor, size: 22),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
      ),
      trailing: trailing ?? const Icon(Icons.chevron_right, size: 18),
    );
  }
}
