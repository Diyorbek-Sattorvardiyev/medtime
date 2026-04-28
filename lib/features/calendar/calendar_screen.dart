import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/api_client.dart';
import '../../core/app_colors.dart';
import '../../core/app_routes.dart';
import '../../core/auth_api.dart';
import '../../core/demo_data.dart';
import '../../core/utils/app_events.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _api = ApiClient();
  var _month = DateTime(DateTime.now().year, DateTime.now().month);
  late var _selectedDay = _month.day;
  var _loading = true;
  String? _error;
  final _days = <String, Map<String, dynamic>>{};
  final _items = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    AppEvents.medicineChanged.addListener(_loadCalendar);
    _loadCalendar();
  }

  @override
  void dispose() {
    AppEvents.medicineChanged.removeListener(_loadCalendar);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kalendar'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _goToday,
            icon: const Icon(Icons.today_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kalendar',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Dorilar jadvali',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonal(
                  onPressed: _goToday,
                  child: const Text('Today'),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: _loadCalendar,
                  icon: const Icon(Icons.calendar_month_outlined),
                ),
              ],
            ),
            const SizedBox(height: 18),
            AppCard(
              radius: 22,
              padding: const EdgeInsets.all(10),
              child: TableCalendar<Map<String, dynamic>>(
                firstDay: DateTime(DateTime.now().year - 2),
                lastDay: DateTime(DateTime.now().year + 2, 12, 31),
                focusedDay: _month,
                selectedDayPredicate: (day) =>
                    day.year == _month.year &&
                    day.month == _month.month &&
                    day.day == _selectedDay,
                calendarFormat: CalendarFormat.month,
                startingDayOfWeek: StartingDayOfWeek.monday,
                availableCalendarFormats: const {CalendarFormat.month: 'Month'},
                eventLoader: (day) {
                  final status = _statusForDate(day);
                  return status == null
                      ? const []
                      : [
                          {'status': status.name},
                        ];
                },
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _month = DateTime(focusedDay.year, focusedDay.month);
                    _selectedDay = selectedDay.day;
                  });
                  _loadCalendar();
                },
                onPageChanged: (focusedDay) {
                  setState(() {
                    _month = DateTime(focusedDay.year, focusedDay.month);
                    _selectedDay = 1;
                  });
                  _loadCalendar();
                },
                headerStyle: const HeaderStyle(
                  titleCentered: true,
                  formatButtonVisible: false,
                  leftChevronIcon: Icon(Icons.chevron_left),
                  rightChevronIcon: Icon(Icons.chevron_right),
                ),
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    border: Border.all(color: AppColors.primary, width: 2),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  markerDecoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                  outsideDaysVisible: false,
                ),
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, day, events) {
                    final status = _statusForDate(day);
                    if (status == null) return const SizedBox.shrink();
                    return Positioned(
                      bottom: 6,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: statusColor(status),
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Bugungi dorilar',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              TextButton(onPressed: _loadCalendar, child: Text(_error!))
            else if (_items.isEmpty)
              const _CalendarEmptyState()
            else
              ..._items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _CalendarMedicine(
                    name: (item['name'] ?? 'Dori').toString(),
                    subtitle: _itemTime(item),
                    status: _statusFrom(item['status']),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  MedicineStatus? _statusForDate(DateTime date) {
    final key =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final data = _days[key];
    final total =
        _int(data?['taken_count']) +
        _int(data?['missed_count']) +
        _int(data?['pending_count']);
    if (data == null || total == 0) return null;
    if (_int(data['missed_count']) > 0) return MedicineStatus.missed;
    if (_int(data['pending_count']) == 0) return MedicineStatus.taken;
    return MedicineStatus.later;
  }

  Future<void> _loadCalendar() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final monthText =
          '${_month.year}-${_month.month.toString().padLeft(2, '0')}';
      final month = await _api.getCalendarMonth(monthText);
      final date = _selectedDate;
      final day = await _api.getCalendarDay(date);
      if (!mounted) return;
      setState(() {
        _days.clear();
        final days = month['days'];
        if (days is List) {
          for (final item in days.whereType<Map<String, dynamic>>()) {
            _days[item['date'].toString()] = item;
          }
        } else if (days is Map) {
          _days.addAll(
            days.map(
              (key, value) => MapEntry(
                key.toString(),
                Map<String, dynamic>.from(value as Map),
              ),
            ),
          );
        }
        _items
          ..clear()
          ..addAll(
            (day['items'] as List? ?? const [])
                .whereType<Map<String, dynamic>>(),
          );
      });
    } on AuthApiException catch (error) {
      if (mounted) setState(() => _error = error.userMessage);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goToday() {
    final now = DateTime.now();
    setState(() {
      _month = DateTime(now.year, now.month);
      _selectedDay = now.day;
    });
    _loadCalendar();
  }

  String get _selectedDate {
    return '${_month.year}-${_month.month.toString().padLeft(2, '0')}-${_selectedDay.toString().padLeft(2, '0')}';
  }

  static MedicineStatus _statusFrom(Object? value) {
    return switch (value?.toString()) {
      'taken' => MedicineStatus.taken,
      'missed' => MedicineStatus.missed,
      _ => MedicineStatus.later,
    };
  }

  static int _int(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _itemTime(Map<String, dynamic> item) {
    final schedule = item['schedule'];
    if (schedule is Map && schedule['time'] != null) {
      return schedule['time'].toString();
    }
    final plannedAt = item['planned_at']?.toString() ?? '';
    final parsed = DateTime.tryParse(plannedAt);
    if (parsed != null) {
      return '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
    }
    return plannedAt;
  }
}

class _CalendarMedicine extends StatelessWidget {
  const _CalendarMedicine({
    required this.name,
    required this.subtitle,
    required this.status,
  });
  final String name;
  final String subtitle;
  final MedicineStatus status;
  @override
  Widget build(BuildContext context) => AppCard(
    radius: 14,
    padding: const EdgeInsets.all(10),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.border.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.medication_outlined),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: Theme.of(context).textTheme.titleMedium),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Icon(statusIcon(status), color: statusColor(status), size: 30),
      ],
    ),
  );
}

class _CalendarEmptyState extends StatelessWidget {
  const _CalendarEmptyState();
  @override
  Widget build(BuildContext context) => AppCard(
    radius: 18,
    child: Column(
      children: [
        const Icon(
          Icons.receipt_long_outlined,
          color: AppColors.border,
          size: 64,
        ),
        const SizedBox(height: 14),
        Text(
          "Bu kunda dori yo'q",
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        AppButton(
          label: "Dori qo'shish",
          onPressed: () => Navigator.pushNamed(context, AppRoutes.addMedicine),
          expand: false,
        ),
      ],
    ),
  );
}
