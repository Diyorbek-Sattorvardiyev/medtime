import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/app_colors.dart';
import '../../core/app_routes.dart';
import '../../core/app_settings.dart';
import '../../core/auth_api.dart';
import '../../core/backup_service.dart';
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
  var _quickStats = <String, dynamic>{
    'taken_count': 0,
    'missed_count': 0,
    'pending_count': 0,
  };
  String? _fullName;
  String? _email;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadQuickStats();
    _loadPermissionState();
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    final strings = AppStrings.of(context);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 116),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  strings.profile,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
              ),
              IconButton(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.notifications),
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _ProfileCard(
            fullName: _fullName ?? 'User Name',
            email: _email ?? 'user@email.com',
            loading: _loadingProfile,
            error: _error,
            onRetry: _loadProfile,
            onEdit: _showEditProfile,
          ),
          const SizedBox(height: 18),
          Text(
            strings.quickStats,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _QuickStat(
                  icon: Icons.check,
                  color: AppColors.primary,
                  title: 'Ichilgan\ndorilar',
                  value: '${_statCount('taken')}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickStat(
                  icon: Icons.close,
                  color: AppColors.error,
                  title: "O'tkazilgan",
                  value: '${_statCount('missed')}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickStat(
                  icon: Icons.schedule,
                  color: AppColors.accent,
                  title: 'Kutilmoqda',
                  value: '${_statCount('pending')}',
                ),
              ),
            ],
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
                      Navigator.pushNamed(context, AppRoutes.notifications),
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
                  icon: Icons.lock,
                  iconColor: AppColors.mutedText,
                  title: strings.security,
                  trailing: const Text(
                    'PIN / FaceID',
                    style: TextStyle(fontSize: 13),
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
                  title: 'Voice reminder',
                  onTap: _testVoiceReminder,
                ),
                _SettingTile(
                  icon: Icons.backup_outlined,
                  iconColor: AppColors.primary,
                  title: 'Backup',
                  onTap: _exportBackup,
                ),
                _SettingTile(
                  icon: Icons.restore,
                  iconColor: AppColors.secondary,
                  title: 'Restore',
                  onTap: _restoreBackup,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                const _FamilyAvatars(),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _SettingTile(
                  icon: Icons.help,
                  iconColor: AppColors.secondary,
                  title: strings.help,
                ),
                _SettingTile(
                  icon: Icons.mail,
                  iconColor: AppColors.mutedText,
                  title: strings.feedback,
                ),
                _SettingTile(
                  icon: Icons.star,
                  iconColor: AppColors.accent,
                  title: strings.rate,
                ),
                _SettingTile(
                  icon: Icons.info,
                  iconColor: const Color(0xFF5B7DB1),
                  title: strings.about,
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
    );
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Chiqmoqchimisiz?'),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ok'),
          ),
        ],
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
        _appNotifications =
            data['app_notifications_enabled'] as bool? ?? _appNotifications;
        _emailEnabled =
            data['email_notifications_enabled'] as bool? ?? _emailEnabled;
        _telegramConnected =
            data['telegram_notifications_enabled'] as bool? ??
            data['telegram_connected'] as bool? ??
            _telegramConnected;
      });
    } on AuthApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  Future<void> _loadQuickStats() async {
    try {
      final stats = await _api.getStatistics(period: 7);
      if (mounted) setState(() => _quickStats = stats);
    } on AuthApiException {
      // Profil asosiy ma'lumotlari stats endpointga bog'lanib qolmasin.
    }
  }

  int _statCount(String key) {
    final value = _quickStats['${key}_count'] ?? _quickStats[key];
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
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

  Future<void> _exportBackup() async {
    try {
      final json = await BackupService(api: _api).exportJson();
      await Clipboard.setData(ClipboardData(text: json));
      _showError('Backup clipboardga ko‘chirildi');
    } on AuthApiException catch (error) {
      _showError(error.userMessage);
    }
  }

  Future<void> _restoreBackup() async {
    final controller = TextEditingController();
    final confirmed = await showModalBottomSheet<bool>(
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
          children: [
            Text('Restore', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              minLines: 4,
              maxLines: 7,
              decoration: const InputDecoration(
                hintText: 'Backup JSON ni shu yerga joylang',
              ),
            ),
            const SizedBox(height: 12),
            AppButton(
              label: 'Restore',
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    try {
      final count = await BackupService(api: _api).restoreJson(controller.text);
      _showError('$count ta yozuv tiklandi');
    } catch (error) {
      _showError('Restore xatosi: $error');
    }
  }

  Future<void> _testVoiceReminder() async {
    await VoiceService.instance.speak('MedReminder eslatma sinovi');
    _showError('Voice reminder sinovi yuborildi');
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
      final code = (link['connect_code'] ?? '').toString();
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
    } on AuthApiException catch (error) {
      _showError(error.message);
    }
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.fullName,
    required this.email,
    required this.loading,
    required this.onRetry,
    required this.onEdit,
    this.error,
  });

  final String fullName;
  final String email;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
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
            child: const CircleAvatar(
              backgroundColor: Color(0xFFDFF6E9),
              child: Icon(Icons.face_6, color: Color(0xFF7A4A2A), size: 58),
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
}

class _QuickStat extends StatelessWidget {
  const _QuickStat({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 12,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 17),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.medication, color: color, size: 16),
              const SizedBox(width: 5),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
              label: 'Notification',
              ok: notificationsAllowed,
              actionLabel: 'Ruxsat',
              onTap: onRequestNotifications,
            ),
            _PermissionLine(
              label: 'Exact alarm',
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
                    label: const Text('App settings'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onOpenBatterySettings,
                    icon: const Icon(Icons.battery_saver, size: 18),
                    label: const Text('Battery'),
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
                      'Email irän',
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
              hintText: 'Modify your email address',
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

class _FamilyAvatars extends StatelessWidget {
  const _FamilyAvatars();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Oila a'zolari", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Row(
            children: [
              const _SmallAvatar(icon: Icons.face_6),
              const SizedBox(width: 8),
              const _SmallAvatar(icon: Icons.face_3),
              const SizedBox(width: 8),
              const _SmallAvatar(icon: Icons.face_4),
              const Spacer(),
              CircleAvatar(
                backgroundColor: AppColors.border,
                child: IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.add),
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                "Qo'shish",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallAvatar extends StatelessWidget {
  const _SmallAvatar({required this.icon});
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(2),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.primary, width: 2),
    ),
    child: CircleAvatar(
      radius: 20,
      backgroundColor: AppColors.successSoft,
      child: Icon(icon, color: Theme.of(context).colorScheme.onSurface),
    ),
  );
}
