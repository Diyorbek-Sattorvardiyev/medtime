import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_colors.dart';
import '../../core/app_routes.dart';
import '../../core/auth_api.dart';
import '../../core/demo_data.dart';
import '../../core/storage/offline_action_queue.dart';
import '../../core/tashkent_time.dart';
import '../../core/utils/app_events.dart';
import '../../widgets/app_card.dart';

class MedicineDetailsScreen extends StatefulWidget {
  const MedicineDetailsScreen({super.key, this.medicineId});

  final int? medicineId;

  @override
  State<MedicineDetailsScreen> createState() => _MedicineDetailsScreenState();
}

class _MedicineDetailsScreenState extends State<MedicineDetailsScreen> {
  final _api = ApiClient();
  var _loading = true;
  String? _error;
  Map<String, dynamic>? _medicine;
  final _history = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  @override
  Widget build(BuildContext context) {
    final medicine = _medicine;
    final schedules = (medicine?['schedules'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final latestStatus = _history.isEmpty
        ? MedicineStatus.pending
        : _statusFrom(_history.first['status']);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Dori tafsilotlari'),
        actions: [
          IconButton(
            tooltip: 'Tahrirlash',
            onPressed: medicine == null ? null : _editMedicine,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _ErrorView(message: _error!, onRetry: _loadDetails)
            : medicine == null
            ? const Center(child: Text('Dori topilmadi'))
            : ListView(
                padding: EdgeInsets.zero,
                children: [
                  _DetailsHero(medicine: medicine, status: latestStatus),
                  Transform.translate(
                    offset: const Offset(0, -28),
                    child: _AnimatedDetailsPanel(
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 18, 12, 116),
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dori tafsilotlari',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 12),
                            _SectionCard(
                              title: "Qabul qilish jadvali",
                              icon: Icons.calendar_month_outlined,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _TinyChip(
                                        'Ichildi',
                                        color: AppColors.primary,
                                      ),
                                      _TinyChip(
                                        "O‘tkazildi",
                                        color: AppColors.error,
                                      ),
                                      _TinyChip(
                                        'Kutilmoqda',
                                        color: AppColors.accent,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: FilledButton(
                                          onPressed: _editMedicine,
                                          style: FilledButton.styleFrom(
                                            backgroundColor: AppColors.primary
                                                .withValues(alpha: 0.12),
                                            foregroundColor: AppColors.primary,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                          child: const Text('Tahrirlash'),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: FilledButton(
                                          onPressed: _deleteMedicine,
                                          style: FilledButton.styleFrom(
                                            backgroundColor: AppColors.error,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                          child: const Text("O'chirish"),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  if (schedules.isEmpty)
                                    const Text('Jadval topilmadi')
                                  else
                                    ...schedules.map(
                                      (schedule) => _ScheduleRow(
                                        time:
                                            schedule['time']?.toString() ??
                                            '--:--',
                                        days: _daysLabel(
                                          schedule['repeat_days'],
                                        ),
                                        reminder:
                                            '${schedule['reminder_before_minutes'] ?? 0} daqiqa oldin',
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _ActionPillButton(
                                          label: 'Ichdim',
                                          icon: Icons.check_rounded,
                                          color: AppColors.primary,
                                          onTap: () =>
                                              _mark(MedicineStatus.taken),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _ActionPillButton(
                                          label: 'Keyin',
                                          icon: Icons.schedule_rounded,
                                          color: AppColors.accent,
                                          onTap: () =>
                                              _mark(MedicineStatus.later),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _ActionPillButton(
                                          label: "O'tkazdim",
                                          icon: Icons.close_rounded,
                                          color: AppColors.error,
                                          onTap: () =>
                                              _mark(MedicineStatus.missed),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            _SectionCard(
                              title: "Tarix ko'rinishi",
                              icon: Icons.history_rounded,
                              child: _history.isEmpty
                                  ? const Text('Bu dori uchun tarix yo‘q')
                                  : Column(
                                      children: _history.take(5).map((item) {
                                        final status = _statusFrom(
                                          item['status'],
                                        );
                                        return _HistoryLine(
                                          color: statusColor(status),
                                          text:
                                              '${(medicine['name'] ?? 'Dori')}  ${_formatDateTime(item['planned_at'])} - ${statusLabel(status)}',
                                        );
                                      }).toList(),
                                    ),
                            ),
                            const SizedBox(height: 12),
                            _SectionCard(
                              title: 'Zaxira va eslatma',
                              icon: medicine['refill_needed'] == true
                                  ? Icons.warning_amber_rounded
                                  : Icons.inventory_2_outlined,
                              iconColor: medicine['refill_needed'] == true
                                  ? AppColors.accent
                                  : AppColors.primary,
                              child: Text(
                                _refillText(medicine),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _loadDetails() async {
    if (widget.medicineId == null) {
      setState(() {
        _loading = false;
        _error = 'Dori ID topilmadi';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await OfflineActionQueue.sync(api: _api);
      final medicine = await _api.getMedicine(widget.medicineId!);
      final history = await _api.getHistory(medicineId: widget.medicineId);
      if (!mounted) return;
      setState(() {
        _medicine = medicine;
        _history
          ..clear()
          ..addAll(history);
      });
    } on AuthApiException catch (error) {
      if (mounted) setState(() => _error = error.userMessage);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteMedicine() async {
    if (widget.medicineId == null) return;
    try {
      await _api.deleteMedicine(widget.medicineId!);
      AppEvents.notifyMedicineChanged();
      if (mounted) Navigator.pop(context);
    } on AuthApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.userMessage)));
    }
  }

  Future<void> _editMedicine() async {
    final medicine = _medicine;
    if (medicine == null) return;
    final changed = await Navigator.pushNamed(
      context,
      AppRoutes.addMedicine,
      arguments: medicine,
    );
    if (changed == true) await _loadDetails();
  }

  Future<void> _mark(MedicineStatus status) async {
    final schedules = (_medicine?['schedules'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    if (widget.medicineId == null || schedules.isEmpty) return;
    final schedule = schedules.first;
    final plannedAt = '${tashkentDateOnly()}T${schedule['time']}:00';
    try {
      switch (status) {
        case MedicineStatus.taken:
          await _api.markTaken(
            medicineId: widget.medicineId!,
            scheduleId: schedule['id'] as int,
            plannedAt: plannedAt,
          );
        case MedicineStatus.missed:
          await _api.markMissed(
            medicineId: widget.medicineId!,
            scheduleId: schedule['id'] as int,
            plannedAt: plannedAt,
          );
        case MedicineStatus.later:
          await _api.snooze(
            medicineId: widget.medicineId!,
            scheduleId: schedule['id'] as int,
            plannedAt: plannedAt,
            minutes: 10,
          );
        case MedicineStatus.pending:
          return;
      }
      AppEvents.notifyMedicineChanged();
      await _loadDetails();
    } on AuthApiException catch (error) {
      if (error.kind == AuthApiErrorKind.network ||
          error.kind == AuthApiErrorKind.server) {
        await OfflineActionQueue.enqueue(
          medicineId: widget.medicineId!,
          scheduleId: schedule['id'] as int,
          plannedAt: plannedAt,
          action: switch (status) {
            MedicineStatus.taken => 'taken',
            MedicineStatus.missed => 'missed',
            MedicineStatus.later => 'snooze',
            MedicineStatus.pending => 'pending',
          },
          minutes: status == MedicineStatus.later ? 10 : null,
        );
        AppEvents.notifyMedicineChanged();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Internet yo‘q. Amal offline saqlandi.'),
          ),
        );
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.userMessage)));
    }
  }

  static MedicineStatus _statusFrom(Object? value) {
    return switch (value?.toString()) {
      'pending' => MedicineStatus.pending,
      'taken' => MedicineStatus.taken,
      'missed' => MedicineStatus.missed,
      'snoozed' => MedicineStatus.later,
      _ => MedicineStatus.later,
    };
  }

  static String _daysLabel(Object? value) {
    final days = value is List
        ? value.map((item) => item.toString()).toList()
        : const <String>[];
    if (days.isEmpty) return 'Kunlar tanlanmagan';
    const labels = {
      'MON': 'Du',
      'TUE': 'Se',
      'WED': 'Ch',
      'THU': 'Pa',
      'FRI': 'Ju',
      'SAT': 'Sha',
      'SUN': 'Ya',
    };
    return days.map((item) => labels[item] ?? item).join(', ');
  }

  static String _formatDateTime(Object? value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) return value?.toString() ?? '';
    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '$day.$month.${parsed.year}  $hour:$minute';
  }

  static String _refillText(Map<String, dynamic> medicine) {
    if (medicine['refill_reminder_enabled'] != true) {
      return 'Refill eslatma o‘chirilgan';
    }
    final stock = medicine['stock_quantity']?.toString() ?? '-';
    final threshold = medicine['refill_threshold']?.toString() ?? '-';
    if (medicine['refill_needed'] == true) {
      return 'Dori tugayapti: $stock qoldi. Chegara: $threshold';
    }
    return 'Zaxira: $stock. Eslatma chegarasi: $threshold';
  }
}

class _DetailsHero extends StatelessWidget {
  const _DetailsHero({required this.medicine, required this.status});

  final Map<String, dynamic> medicine;
  final MedicineStatus status;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, -18 * (1 - value)),
          child: child,
        ),
      ),
      child: Container(
        height: 246,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 34),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF22C66B), Color(0xFF2EA7FF)],
          ),
        ),
        child: Column(
          children: [
            const Spacer(),
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: _HeroMedicineImage(
                value: (medicine['image_url'] ?? '').toString(),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                _HeroChip(statusLabel(status)),
                _HeroChip((medicine['dosage'] ?? 'Doza').toString()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroMedicineImage extends StatelessWidget {
  const _HeroMedicineImage({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final image = value.trim();
    if (image.isEmpty) return const _HeroFallbackIcon();
    if (image.startsWith('http://') || image.startsWith('https://')) {
      return Image.network(
        image,
        width: 86,
        height: 86,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const _HeroFallbackIcon(),
      );
    }
    return Image.file(
      File(image),
      width: 86,
      height: 86,
      cacheWidth: 172,
      cacheHeight: 172,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const _HeroFallbackIcon(),
    );
  }
}

class _HeroFallbackIcon extends StatelessWidget {
  const _HeroFallbackIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 86,
      height: 86,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.32)),
      ),
      child: const Icon(
        Icons.medication_outlined,
        color: Colors.white,
        size: 58,
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.isEmpty ? 'Doza' : label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _AnimatedDetailsPanel extends StatelessWidget {
  const _AnimatedDetailsPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 22 * (1 - value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _ActionPillButton extends StatelessWidget {
  const _ActionPillButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.iconColor,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 18,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor ?? AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({
    required this.time,
    required this.days,
    required this.reminder,
  });

  final String time;
  final String days;
  final String reminder;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.successSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              time,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(days, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  reminder,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('Qayta urinish')),
        ],
      ),
    );
  }
}

class _TinyChip extends StatelessWidget {
  const _TinyChip(this.label, {this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: tint,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _HistoryLine extends StatelessWidget {
  const _HistoryLine({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(Icons.circle, color: color, size: 10),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
