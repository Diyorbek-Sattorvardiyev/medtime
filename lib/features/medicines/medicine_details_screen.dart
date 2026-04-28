import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_colors.dart';
import '../../core/app_routes.dart';
import '../../core/auth_api.dart';
import '../../core/demo_data.dart';
import '../../core/storage/offline_action_queue.dart';
import '../../core/utils/app_events.dart';
import '../../widgets/app_button.dart';
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

    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _ErrorView(message: _error!, onRetry: _loadDetails)
            : medicine == null
            ? const Center(child: Text('Dori topilmadi'))
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Row(
                      children: [
                        IconButton.filledTonal(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Expanded(
                          child: Text(
                            'Dori tafsilotlari',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        IconButton.filledTonal(
                          onPressed: _editMedicine,
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        const SizedBox(width: 6),
                        IconButton.filledTonal(
                          onPressed: _deleteMedicine,
                          icon: const Icon(
                            Icons.delete_outline,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      children: [
                        AppCard(
                          radius: 18,
                          child: Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: AppColors.border.withValues(
                                    alpha: 0.65,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  Icons.medication_outlined,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (medicine['name'] ?? 'Dori').toString(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text((medicine['dosage'] ?? '').toString()),
                                    Text(
                                      'Intake type: ${medicine['intake_type'] ?? ''}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        AppCard(
                          radius: 14,
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Qabul qilish jadvali',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: schedules
                                    .map(
                                      (schedule) => _TinyChip(
                                        '${schedule['time']} | ${(schedule['repeat_days'] as List? ?? const []).join(', ')}',
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        AppCard(
                          radius: 14,
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(
                                medicine['refill_needed'] == true
                                    ? Icons.warning_amber
                                    : Icons.inventory_2_outlined,
                                color: medicine['refill_needed'] == true
                                    ? AppColors.accent
                                    : AppColors.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
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
                        const SizedBox(height: 12),
                        Text(
                          'Tarix',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        if (_history.isEmpty)
                          const Text('Bu dori uchun tarix yo‘q')
                        else
                          ..._history.map(
                            (item) => _HistoryLine(
                              color: statusColor(_statusFrom(item['status'])),
                              text:
                                  '${item['planned_at'] ?? ''} - ${item['status'] ?? ''}',
                            ),
                          ),
                        const SizedBox(height: 12),
                        AppCard(
                          radius: 14,
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Izoh',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 5),
                              Text((medicine['notes'] ?? '').toString()),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SafeArea(
                    top: false,
                    minimum: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: 'Ichdim',
                            onPressed: () => _mark(MedicineStatus.taken),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppButton(
                            label: 'Keyin',
                            style: AppButtonStyle.soft,
                            onPressed: () => _mark(MedicineStatus.later),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppButton(
                            label: "O'tkazdim",
                            style: AppButtonStyle.outline,
                            onPressed: () => _mark(MedicineStatus.missed),
                          ),
                        ),
                      ],
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
    final plannedAt =
        '${DateTime.now().toIso8601String().substring(0, 10)}T${schedule['time']}:00';
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
      _ => MedicineStatus.later,
    };
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
  const _TinyChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.border.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
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
