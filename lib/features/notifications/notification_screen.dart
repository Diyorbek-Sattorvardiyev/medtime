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
      appBar: AppBar(title: Text(strings.notifications)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            TextButton(onPressed: _loadNotifications, child: Text(_error!))
          else if (_items.isEmpty)
            const _NotificationEmpty()
          else
            ..._items.map(
              (item) => _HistoryTile(
                title: (item['title'] ?? 'Notification').toString(),
                subtitle: '${item['body'] ?? ''}\n${item['created_at'] ?? ''}',
                status: _statusFrom(item['channel']),
              ),
            ),
        ],
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
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.title,
    required this.subtitle,
    required this.status,
  });
  final String title;
  final String subtitle;
  final MedicineStatus status;
  @override
  Widget build(BuildContext context) => AppCard(
    radius: 12,
    padding: const EdgeInsets.all(12),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(subtitle, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
        Icon(statusIcon(status), color: statusColor(status)),
      ],
    ),
  );
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
          AppStrings.of(context).notifications,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    ),
  );
}
