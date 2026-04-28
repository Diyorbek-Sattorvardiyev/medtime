import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_colors.dart';
import '../../core/app_settings.dart';
import '../../core/auth_api.dart';
import '../../core/demo_data.dart';
import '../../widgets/app_card.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final _api = ApiClient();
  var _loading = true;
  String? _error;
  final _items = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(strings.notifications),
        actions: [
          IconButton(
            tooltip: 'Yangilash',
            onPressed: _loading ? null : _loadNotifications,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadNotifications,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          children: [
            if (_loading)
              const _NotificationSkeleton()
            else if (_error != null)
              _NotificationError(message: _error!, onRetry: _loadNotifications)
            else if (_items.isEmpty)
              const _NotificationEmpty()
            else
              ..._items.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _NotificationTile(
                    index: entry.key,
                    title: (entry.value['title'] ?? 'Bildirishnoma').toString(),
                    body: (entry.value['body'] ?? '').toString(),
                    date: _formatDate(entry.value['created_at']),
                    status: _statusFrom(
                      entry.value['status'] ?? entry.value['channel'],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _api.getNotifications();
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(items);
      });
    } on AuthApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static MedicineStatus _statusFrom(Object? value) {
    return switch (value?.toString()) {
      'sent' || 'taken' => MedicineStatus.taken,
      'pending' || 'snoozed' || 'email' || 'telegram' => MedicineStatus.later,
      'failed' || 'missed' => MedicineStatus.missed,
      _ => MedicineStatus.pending,
    };
  }

  static String _formatDate(Object? value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) return value?.toString() ?? '';
    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '$day.$month.${parsed.year}  $hour:$minute';
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.index,
    required this.title,
    required this.body,
    required this.date,
    required this.status,
  });
  final int index;
  final String title;
  final String body;
  final String date;
  final MedicineStatus status;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + index * 45),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - value)),
          child: child,
        ),
      ),
      child: AppCard(
        radius: 16,
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: statusColor(status).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(statusIcon(status), color: statusColor(status)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  if (body.isNotEmpty)
                    Text(
                      body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  const SizedBox(height: 6),
                  Text(
                    date,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _StatusChip(status: status),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final MedicineStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: statusColor(status),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        statusLabel(status),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _NotificationSkeleton extends StatelessWidget {
  const _NotificationSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        4,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            radius: 16,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationError extends StatelessWidget {
  const _NotificationError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 16,
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 44),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 10),
          FilledButton(onPressed: onRetry, child: const Text('Qayta urinish')),
        ],
      ),
    );
  }
}

class _NotificationEmpty extends StatelessWidget {
  const _NotificationEmpty();
  @override
  Widget build(BuildContext context) => AppCard(
    radius: 16,
    child: Column(
      children: [
        const Icon(
          Icons.medication_outlined,
          color: AppColors.border,
          size: 74,
        ),
        const SizedBox(height: 12),
        Text(
          'Hozircha bildirishnoma yo‘q',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    ),
  );
}
