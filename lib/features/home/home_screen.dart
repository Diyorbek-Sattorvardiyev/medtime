import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_colors.dart';
import '../../core/app_routes.dart';
import '../../core/app_settings.dart';
import '../../core/auth_api.dart';
import '../../core/demo_data.dart';
import '../../core/reminder_service.dart';
import '../../core/storage/offline_action_queue.dart';
import '../../core/storage/offline_medicine_queue.dart';
import '../../core/utils/app_events.dart';
import '../../widgets/app_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static _Dashboard? _cache;
  static DateTime? _cacheAt;
  static String? _profileNameCache;

  final _api = ApiClient();
  var _loading = true;
  String? _error;
  String? _profileName;
  var _dashboard = _Dashboard.empty();
  Timer? _refreshDebounce;

  @override
  void initState() {
    super.initState();
    AppEvents.medicineChanged.addListener(_queueRefresh);
    _profileName = _profileNameCache;
    unawaited(_loadProfile());
    final cached = _cache;
    if (cached != null) {
      _dashboard = cached;
      _loading = false;
      if (_cacheIsStale) _queueRefresh();
    } else {
      _loadDashboard(showLoading: true);
    }
  }

  @override
  void dispose() {
    AppEvents.medicineChanged.removeListener(_queueRefresh);
    _refreshDebounce?.cancel();
    super.dispose();
  }

  bool get _cacheIsStale {
    final cached = _cacheAt;
    if (cached == null) return true;
    return DateTime.now().difference(cached) > const Duration(seconds: 30);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 116),
        children: [
          _HomeHeader(strings: strings, profileName: _profileName),
          const SizedBox(height: 18),
          Text(
            strings.todayMedicines,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _TodaySummaryCard(
            strings: strings,
            loading: _loading,
            error: _error,
            dashboard: _dashboard,
            onRetry: () => _loadDashboard(showLoading: true),
            onStatusChanged: _updateStatus,
            onOpenDetails: () =>
                Navigator.pushNamed(context, AppRoutes.calendar),
          ),
          const SizedBox(height: 18),
          AppCard(
            radius: 18,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                SizedBox(
                  width: 92,
                  height: 92,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 78,
                        height: 78,
                        child: CircularProgressIndicator(
                          value: _dashboard.progress,
                          strokeWidth: 9,
                          color: AppColors.primary,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.outlineVariant,
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${(_dashboard.progress * 100).round()}%',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            strings.completed,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontSize: 9,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      _ProgressLegend(
                        color: AppColors.primary,
                        text:
                            '${_dashboard.taken} ${statusLabel(MedicineStatus.taken).toLowerCase()}',
                      ),
                      const SizedBox(height: 8),
                      _ProgressLegend(
                        color: AppColors.accent,
                        text: '${_dashboard.pending} ${strings.remaining}',
                      ),
                      const SizedBox(height: 8),
                      _ProgressLegend(
                        color: AppColors.error,
                        text:
                            '${_dashboard.missed} ${statusLabel(MedicineStatus.missed).toLowerCase()}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text('Quick actions', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _QuickAction(
                  icon: Icons.add_box_outlined,
                  label: strings.add,
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.addMedicine),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickAction(
                  icon: Icons.bar_chart_rounded,
                  label: strings.stats,
                  onTap: () => Navigator.pushNamed(context, AppRoutes.calendar),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickAction(
                  icon: Icons.groups_outlined,
                  label: 'Oila',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.family),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            strings.todayMedicines,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 88,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _dashboard.upcomingMedicines.isEmpty
                  ? [
                      SizedBox(
                        width: 220,
                        child: AppCard(
                          radius: 18,
                          child: Center(child: Text(strings.noMedicinesToday)),
                        ),
                      ),
                    ]
                  : _dashboard.upcomingMedicines
                        .map(
                          (medicine) => Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: _UpcomingMedicine(
                              time: medicine.time,
                              title: medicine.name,
                              dose: medicine.dose,
                            ),
                          ),
                        )
                        .toList(),
            ),
          ),
        ],
      ),
    );
  }

  void _queueRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(
      const Duration(milliseconds: 300),
      () => _loadDashboard(showLoading: false),
    );
  }

  Future<void> _loadDashboard({bool showLoading = false}) async {
    if (showLoading || _cache == null) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      await OfflineMedicineQueue.sync(api: _api);
      await OfflineActionQueue.sync(api: _api);
      final results = await Future.wait([
        _api.getTodayDashboard(),
        _api.getMedicines(active: true),
      ]);
      final json = results[0] as Map<String, dynamic>;
      final allMedicines = results[1] as List<Map<String, dynamic>>;
      if (!mounted) return;
      final dashboard = _Dashboard.fromJson(json);
      _cache = dashboard;
      _cacheAt = DateTime.now();
      setState(() => _dashboard = dashboard);
      unawaited(ReminderService.instance.syncFromMedicineMaps(allMedicines));
    } on AuthApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.userMessage;
        if (_cache != null) _dashboard = _cache!;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _api.getProfile();
      final name = (profile['full_name'] ?? profile['name'])?.toString().trim();
      if (!mounted || name == null || name.isEmpty) return;
      _profileNameCache = name;
      setState(() => _profileName = name);
    } on AuthApiException {
      // Header can still render while profile is unavailable.
    }
  }

  Future<void> _updateStatus(Medicine medicine, MedicineStatus status) async {
    if (medicine.id == null ||
        medicine.scheduleId == null ||
        medicine.plannedAt == null) {
      return;
    }
    try {
      await _sendStatus(medicine, status);
    } on AuthApiException catch (error) {
      if (error.kind != AuthApiErrorKind.network &&
          error.kind != AuthApiErrorKind.server) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.userMessage)));
        return;
      }
      await OfflineActionQueue.enqueue(
        medicineId: medicine.id!,
        scheduleId: medicine.scheduleId!,
        plannedAt: medicine.plannedAt!,
        action: _actionName(status),
        minutes: status == MedicineStatus.later ? 10 : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Internet yo‘q. Amal offline saqlandi.'),
          ),
        );
      }
    }
    if (!mounted) return;
    setState(() {
      _dashboard = _dashboard.replaceMedicineStatus(medicine, status);
      _cache = _dashboard;
      _cacheAt = DateTime.now();
    });
  }

  Future<void> _sendStatus(Medicine medicine, MedicineStatus status) {
    return switch (status) {
      MedicineStatus.taken => _api.markTaken(
        medicineId: medicine.id!,
        scheduleId: medicine.scheduleId!,
        plannedAt: medicine.plannedAt!,
      ),
      MedicineStatus.missed => _api.markMissed(
        medicineId: medicine.id!,
        scheduleId: medicine.scheduleId!,
        plannedAt: medicine.plannedAt!,
      ),
      MedicineStatus.later => _api.snooze(
        medicineId: medicine.id!,
        scheduleId: medicine.scheduleId!,
        plannedAt: medicine.plannedAt!,
        minutes: 10,
      ),
      MedicineStatus.pending => Future.value(),
    };
  }

  String _actionName(MedicineStatus status) {
    return switch (status) {
      MedicineStatus.taken => 'taken',
      MedicineStatus.missed => 'missed',
      MedicineStatus.later => 'snooze',
      MedicineStatus.pending => 'pending',
    };
  }
}

class _Dashboard {
  const _Dashboard({
    required this.todayMedicines,
    required this.upcomingMedicines,
    required this.taken,
    required this.pending,
    required this.missed,
  });

  factory _Dashboard.empty() {
    return const _Dashboard(
      todayMedicines: [],
      upcomingMedicines: [],
      taken: 0,
      pending: 0,
      missed: 0,
    );
  }

  factory _Dashboard.fromJson(Map<String, dynamic> json) {
    final today = _items(json['today'] ?? json['medicines'] ?? json['items']);
    final upcoming = _items(json['upcoming'] ?? json['upcoming_medicines']);
    return _Dashboard(
      todayMedicines: today.map(Medicine.fromJson).toList(),
      upcomingMedicines: upcoming.map(Medicine.fromJson).toList(),
      taken: _int(json['taken'] ?? json['taken_count']),
      pending: _int(json['pending'] ?? json['pending_count']),
      missed: _int(json['missed'] ?? json['missed_count']),
    );
  }

  final List<Medicine> todayMedicines;
  final List<Medicine> upcomingMedicines;
  final int taken;
  final int pending;
  final int missed;

  double get progress {
    final total = taken + pending + missed;
    return total == 0 ? 0 : taken / total;
  }

  _Dashboard replaceMedicineStatus(Medicine medicine, MedicineStatus status) {
    final updated = todayMedicines
        .map(
          (item) =>
              identical(item, medicine) ? item.copyWith(status: status) : item,
        )
        .toList();
    int count(MedicineStatus value) =>
        updated.where((item) => item.status == value).length;
    return _Dashboard(
      todayMedicines: updated,
      upcomingMedicines: upcomingMedicines
          .where((item) => item.plannedAt != medicine.plannedAt)
          .toList(),
      taken: count(MedicineStatus.taken),
      pending: count(MedicineStatus.pending) + count(MedicineStatus.later),
      missed: count(MedicineStatus.missed),
    );
  }

  static List<Map<String, dynamic>> _items(Object? value) {
    if (value is! List) return const [];
    return value.whereType<Map<String, dynamic>>().toList();
  }

  static int _int(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.strings, required this.profileName});

  final AppStrings strings;
  final String? profileName;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profileName == null || profileName!.isEmpty
                    ? strings.greeting
                    : 'Salom, $profileName',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 3),
              Text(
                '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () =>
              Navigator.pushNamed(context, AppRoutes.notifications),
          icon: const Icon(Icons.notifications_none_rounded, size: 22),
        ),
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            gradient: LinearGradient(
              colors: dark
                  ? const [Color(0xFF334155), Color(0xFF1E293B)]
                  : const [Color(0xFFE2E8F0), Color(0xFFCBD5E1)],
            ),
          ),
          child: Icon(
            Icons.person,
            color: Theme.of(context).colorScheme.onSurface,
            size: 24,
          ),
        ),
      ],
    );
  }
}

class _TodaySummaryCard extends StatelessWidget {
  const _TodaySummaryCard({
    required this.strings,
    required this.loading,
    required this.error,
    required this.dashboard,
    required this.onRetry,
    required this.onStatusChanged,
    required this.onOpenDetails,
  });

  final AppStrings strings;
  final bool loading;
  final String? error;
  final _Dashboard dashboard;
  final VoidCallback onRetry;
  final Future<void> Function(Medicine medicine, MedicineStatus status)
  onStatusChanged;
  final VoidCallback onOpenDetails;

  @override
  Widget build(BuildContext context) {
    final visible = dashboard.todayMedicines.take(3).toList();
    return AppCard(
      radius: 18,
      padding: const EdgeInsets.symmetric(vertical: 6),
      onTap: onOpenDetails,
      child: loading
          ? const SizedBox(
              height: 126,
              child: Center(child: CircularProgressIndicator()),
            )
          : error != null
          ? SizedBox(
              height: 126,
              child: Center(
                child: TextButton(
                  onPressed: onRetry,
                  child: Text(error!, textAlign: TextAlign.center),
                ),
              ),
            )
          : visible.isEmpty
          ? SizedBox(
              height: 126,
              child: Center(child: Text(strings.noMedicinesToday)),
            )
          : Column(
              children: [
                for (var i = 0; i < visible.length; i++) ...[
                  _TodayMedicineRow(
                    medicine: visible[i],
                    onStatusChanged: onStatusChanged,
                  ),
                  if (i != visible.length - 1)
                    Divider(
                      height: 1,
                      indent: 56,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                ],
              ],
            ),
    );
  }
}

class _TodayMedicineRow extends StatelessWidget {
  const _TodayMedicineRow({
    required this.medicine,
    required this.onStatusChanged,
  });

  final Medicine medicine;
  final Future<void> Function(Medicine medicine, MedicineStatus status)
  onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: medicine.status == MedicineStatus.taken
          ? null
          : () => onStatusChanged(medicine, MedicineStatus.taken),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: statusColor(medicine.status).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                statusIcon(medicine.status),
                color: statusColor(medicine.status),
                size: 21,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medicine.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    medicine.time,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              statusIcon(medicine.status),
              color: statusColor(medicine.status),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressLegend extends StatelessWidget {
  const _ProgressLegend({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.check_circle, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      radius: 14,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      child: Column(
        children: [
          Icon(icon, color: AppColors.secondary, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingMedicine extends StatelessWidget {
  const _UpcomingMedicine({
    required this.time,
    required this.title,
    required this.dose,
  });

  final String time;
  final String title;
  final String dose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 152,
      child: AppCard(
        radius: 18,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Text(
              time,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontSize: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(fontSize: 12),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    dose,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.check_circle, color: AppColors.primary, size: 16),
          ],
        ),
      ),
    );
  }
}
