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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Kalendar')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 116),
          children: [
            _AnimatedEntry(
              child: Row(
                children: [
                  IconButton(
                    onPressed: _previousMonth,
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Text(
                      '${_month.month.toString().padLeft(2, '0')}.${_month.year}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _nextMonth,
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            _AnimatedEntry(
              delay: 80,
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
                daysOfWeekHeight: 30,
                rowHeight: 36,
                headerStyle: const HeaderStyle(
                  headerMargin: EdgeInsets.only(bottom: 2),
                  titleTextStyle: TextStyle(fontSize: 0),
                  leftChevronVisible: false,
                  rightChevronVisible: false,
                  formatButtonVisible: false,
                ),
                calendarStyle: CalendarStyle(
                  defaultTextStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                  weekendTextStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                  outsideTextStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.black.withValues(alpha: 0.18),
                  ),
                  todayDecoration: const BoxDecoration(
                    color: AppColors.successSoft,
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
                  selectedTextStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                  todayTextStyle: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                  outsideDaysVisible: true,
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: TextStyle(
                    fontSize: 11,
                    color: Colors.black.withValues(alpha: 0.45),
                    fontWeight: FontWeight.w700,
                  ),
                  weekendStyle: TextStyle(
                    fontSize: 11,
                    color: Colors.black.withValues(alpha: 0.45),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: _calendarDayBuilder,
                  selectedBuilder: _calendarDayBuilder,
                  todayBuilder: _calendarDayBuilder,
                  outsideBuilder: _calendarDayBuilder,
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
            const SizedBox(height: 16),
            if (_loading)
              const _CalendarSkeleton()
            else if (_error != null)
              TextButton(onPressed: _loadCalendar, child: Text(_error!))
            else if (_items.isEmpty)
              const _CalendarEmptyState()
            else ...[
              _AnimatedEntry(
                delay: 120,
                child: _SelectedDayPreview(
                  item: _items.first,
                  onTap: () => _openMedicine(_items.first),
                ),
              ),
              const SizedBox(height: 16),
              ..._items.asMap().entries.map(
                (entry) => _AnimatedEntry(
                  delay: 160 + entry.key * 55,
                  child: _TimelineMedicine(
                    item: entry.value,
                    status: _statusFrom(entry.value['status']),
                    onTap: () => _openMedicine(entry.value),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget? _calendarDayBuilder(
    BuildContext context,
    DateTime day,
    DateTime focusedDay,
  ) {
    final status = _statusForDate(day);
    final selected =
        day.year == _month.year &&
        day.month == _month.month &&
        day.day == _selectedDay;
    if (status == null && !selected) return null;
    final color = selected
        ? AppColors.primary
        : status == null
        ? Colors.transparent
        : statusColor(status);
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Text(
          '${day.day}',
          style: TextStyle(
            color: selected || status != null ? Colors.white : Colors.black,
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
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

  void _previousMonth() {
    setState(() {
      _month = DateTime(_month.year, _month.month - 1);
      _selectedDay = 1;
    });
    _loadCalendar();
  }

  void _nextMonth() {
    setState(() {
      _month = DateTime(_month.year, _month.month + 1);
      _selectedDay = 1;
    });
    _loadCalendar();
  }

  void _openMedicine(Map<String, dynamic> item) {
    final id = _int(item['id'] ?? item['medicine_id']);
    if (id == 0) return;
    Navigator.pushNamed(context, AppRoutes.details, arguments: id);
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

class _SelectedDayPreview extends StatelessWidget {
  const _SelectedDayPreview({required this.item, required this.onTap});

  final Map<String, dynamic> item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = _CalendarScreenState._statusFrom(item['status']);
    return AppCard(
      radius: 14,
      padding: const EdgeInsets.all(10),
      onTap: onTap,
      child: Row(
        children: [
          _MedicineIcon(status: status, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (item['name'] ?? 'Paracetamol').toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  statusLabel(status),
                  style: TextStyle(
                    color: statusColor(status),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.mutedText),
        ],
      ),
    );
  }
}

class _TimelineMedicine extends StatelessWidget {
  const _TimelineMedicine({
    required this.item,
    required this.status,
    required this.onTap,
  });

  final Map<String, dynamic> item;
  final MedicineStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Column(
              children: [
                Text(
                  _monthLabel(item['planned_at']),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  _yearLabel(item['planned_at']),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.black.withValues(alpha: 0.45),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 9,
            height: 9,
            margin: const EdgeInsets.only(top: 5, right: 8),
            decoration: BoxDecoration(
              color: statusColor(status),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    _MedicineIcon(status: status, size: 28),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (item['name'] ?? 'Paracetamol').toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            _CalendarScreenState._itemTime(item),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _StatusPill(status: status),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _monthLabel(Object? value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    const labels = [
      'Jan.',
      'Feb.',
      'Mar.',
      'Apr.',
      'May.',
      'Jun.',
      'Jul.',
      'Aug.',
      'Sep.',
      'Oct.',
      'Nov.',
      'Dec.',
    ];
    if (parsed == null) return 'Jan.';
    return labels[parsed.month - 1];
  }

  static String _yearLabel(Object? value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    return parsed?.year.toString() ?? '';
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final MedicineStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor(status).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        statusLabel(status),
        style: TextStyle(
          color: statusColor(status),
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MedicineIcon extends StatelessWidget {
  const _MedicineIcon({required this.status, required this.size});

  final MedicineStatus status;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size + 14,
      height: size + 14,
      decoration: BoxDecoration(
        color: statusColor(status).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(
        Icons.medication_outlined,
        color: statusColor(status),
        size: size,
      ),
    );
  }
}

class _AnimatedEntry extends StatelessWidget {
  const _AnimatedEntry({required this.child, this.delay = 0});

  final Widget child;
  final int delay;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _CalendarSkeleton extends StatelessWidget {
  const _CalendarSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppCard(
            radius: 14,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(8),
                    ),
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
