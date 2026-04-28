import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/permission_service.dart';
import '../../widgets/app_card.dart';

class ReminderAccessScreen extends StatefulWidget {
  const ReminderAccessScreen({super.key});

  @override
  State<ReminderAccessScreen> createState() => _ReminderAccessScreenState();
}

class _ReminderAccessScreenState extends State<ReminderAccessScreen> {
  var _loading = true;
  var _notificationsAllowed = true;
  var _exactAlarmsAllowed = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _notificationsAllowed && _exactAlarmsAllowed;
    return Scaffold(
      appBar: AppBar(title: const Text('Eslatma sozlamalari')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            AppCard(
              radius: 20,
              floating: true,
              child: Column(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Icon(
                      ready
                          ? Icons.alarm_on_rounded
                          : Icons.notifications_active_outlined,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    ready ? 'Budilnik tayyor' : 'Eslatma ruxsatlarini yoqing',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Dori vaqti kelganda ilova yopiq bo‘lsa ham telefon ekrani ochiq yoki bloklangan holatda bildirishnoma ko‘rsatishi uchun quyidagi ruxsatlar kerak.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else ...[
              _AccessTile(
                icon: Icons.notifications_active_outlined,
                title: 'Bildirishnoma',
                subtitle: 'Dori vaqti kelganda xabar chiqaradi.',
                ok: _notificationsAllowed,
                action: 'Ruxsat berish',
                onTap: () async {
                  await PermissionService.instance.requestNotifications();
                  await _load();
                },
              ),
              const SizedBox(height: 12),
              _AccessTile(
                icon: Icons.alarm_rounded,
                title: 'Aniq budilnik',
                subtitle: 'Eslatma aynan siz qo‘ygan vaqtda chiqishi uchun.',
                ok: _exactAlarmsAllowed,
                action: 'Sozlash',
                onTap: () async {
                  await PermissionService.instance.requestExactAlarms();
                  await _load();
                },
              ),
              const SizedBox(height: 12),
              _AccessTile(
                icon: Icons.battery_saver_outlined,
                title: 'Batareya cheklovi',
                subtitle:
                    'Ayrim telefonlarda batareya optimizatsiyasi eslatmani kechiktirishi mumkin.',
                ok: false,
                action: 'Batareya sozlamasi',
                onTap: PermissionService.instance.openBatterySettings,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: PermissionService.instance.openAppSettings,
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Ilova sozlamalarini ochish'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final state = await PermissionService.instance.loadState();
      if (!mounted) return;
      setState(() {
        _notificationsAllowed = state.notificationsEnabled;
        _exactAlarmsAllowed = state.exactAlarmsEnabled;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _AccessTile extends StatelessWidget {
  const _AccessTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.ok,
    required this.action,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool ok;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 16,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: (ok ? AppColors.primary : AppColors.accent).withValues(
                alpha: 0.15,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: ok ? AppColors.primary : AppColors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ok
              ? const Icon(Icons.check_circle, color: AppColors.primary)
              : TextButton(onPressed: onTap, child: Text(action)),
        ],
      ),
    );
  }
}
