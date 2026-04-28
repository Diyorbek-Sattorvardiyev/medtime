import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_colors.dart';
import '../../core/auth_api.dart';
import '../../core/reminder_service.dart';
import '../../core/storage/offline_medicine_queue.dart';
import '../../core/utils/app_events.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_chip.dart';

class AddMedicineScreen extends StatefulWidget {
  const AddMedicineScreen({
    super.key,
    this.initialMedicine,
    this.initialFamilyMemberId,
  });

  final Map<String, dynamic>? initialMedicine;
  final int? initialFamilyMemberId;

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  final _api = ApiClient();
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  final _stockController = TextEditingController();
  final _refillThresholdController = TextEditingController(text: '5');
  var _dose = '1 tabletka';
  var _intake = 'Ovqatdan oldin';
  var _reminderOn = true;
  var _reminderBeforeMinutes = 30;
  var _refillReminderOn = false;
  var _startDate = DateTime.now();
  DateTime? _endDate;
  var _loading = false;
  String? _error;
  int? _familyMemberId;
  final _familyMembers = <Map<String, dynamic>>[];
  final _days = {'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'};
  final _times = ['08:00', '14:00'];
  bool get _editing => widget.initialMedicine?['id'] != null;

  @override
  void initState() {
    super.initState();
    _prefill();
    _loadFamilyMembers();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    _stockController.dispose();
    _refillThresholdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 116),
          children: [
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      _editing ? 'Dorini tahrirlash' : "Dori qo'shish",
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: _loading ? null : _saveMedicine,
                  icon: const Icon(Icons.save_outlined),
                ),
              ],
            ),
            const SizedBox(height: 18),
            FutureBuilder<int>(
              future: OfflineMedicineQueue.pendingCount(),
              builder: (context, snapshot) {
                final count = snapshot.data ?? 0;
                if (count == 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _OfflineQueueBanner(
                    count: count,
                    onSync: _syncPendingMedicines,
                  ),
                );
              },
            ),
            if (_familyMembers.isNotEmpty) ...[
              _Section(
                title: "KIM UCHUN",
                child: DropdownButtonFormField<int?>(
                  initialValue: _familyMemberId,
                  decoration: const InputDecoration(
                    hintText: "O'zim uchun",
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text("O'zim uchun"),
                    ),
                    ..._familyMembers.map(
                      (member) => DropdownMenuItem<int?>(
                        value: int.tryParse(member['id'].toString()),
                        child: Text(member['full_name'].toString()),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _familyMemberId = value),
                ),
              ),
              const SizedBox(height: 16),
            ],
            _DarkInput(
              controller: _nameController,
              label: 'MEDICINE NAME',
              hint: 'Dori nomini kiriting',
              error: _error,
              suffix: Icons.edit,
            ),
            const SizedBox(height: 16),
            _Section(
              title: 'DOSE (DOZASI)',
              child: Wrap(
                spacing: 8,
                children: ['1 tabletka', '2 tabletka', '5 ml', 'Custom']
                    .map(
                      (dose) => _ChoicePill(
                        label: dose,
                        selected: _dose == dose,
                        onTap: () => setState(() => _dose = dose),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),
            _Section(
              title: 'TIME PICKER',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Qabul qilish vaqti',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ..._times.map(
                        (time) => InputChip(
                          label: Text(time),
                          avatar: const Icon(Icons.schedule, size: 16),
                          onDeleted: _times.length == 1
                              ? null
                              : () => setState(() => _times.remove(time)),
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: "Vaqt qo'shish",
                        onPressed: _showTimePicker,
                        icon: const Icon(Icons.add),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.timelapse, size: 17),
                        label: const Text("Oraliq"),
                        onPressed: _showIntervalPicker,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _Section(
              title: 'REPEAT SCHEDULE',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                        .map((day) {
                          final selected = _days.contains(day);
                          return _ChoicePill(
                            label: day,
                            selected: selected,
                            onTap: () => setState(
                              () =>
                                  selected ? _days.remove(day) : _days.add(day),
                            ),
                          );
                        })
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Har kuni',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Switch(
                        value: _days.length == 7,
                        onChanged: (value) => setState(() {
                          _days
                            ..clear()
                            ..addAll(
                              value
                                  ? [
                                      'Mon',
                                      'Tue',
                                      'Wed',
                                      'Thu',
                                      'Fri',
                                      'Sat',
                                      'Sun',
                                    ]
                                  : ['Mon'],
                            );
                        }),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _Section(
              title: 'DATE RANGE',
              child: Row(
                children: [
                  Expanded(
                    child: _DateBox(
                      label: 'Start date',
                      value: _dateOnly(_startDate),
                      onTap: _pickStartDate,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DateBox(
                      label: 'End date',
                      value: _endDate == null
                          ? 'Cheklanmagan'
                          : _dateOnly(_endDate!),
                      onTap: _pickEndDate,
                      onClear: _endDate == null
                          ? null
                          : () => setState(() => _endDate = null),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _Section(
              title: 'INTAKE TYPE',
              child: Wrap(
                spacing: 8,
                children: ['Ovqatdan oldin', 'Ovqatdan keyin', "Farqi yo'q"]
                    .map(
                      (item) => _ChoicePill(
                        label: item,
                        selected: _intake == item,
                        onTap: () => setState(() => _intake = item),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),
            _Section(
              title: 'REMINDER SETTINGS',
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Turn reminder ON',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Switch(
                        value: _reminderOn,
                        onChanged: (v) => setState(() => _reminderOn = v),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Delay options',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [0, 5, 10, 30]
                        .map(
                          (minute) => _ChoicePill(
                            label: minute == 0 ? 'vaqtida' : '$minute min',
                            selected: _reminderBeforeMinutes == minute,
                            onTap: () =>
                                setState(() => _reminderBeforeMinutes = minute),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _Section(
              title: 'REFILL REMINDER',
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Dori tugashini eslatish',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Switch(
                        value: _refillReminderOn,
                        onChanged: (v) => setState(() => _refillReminderOn = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _stockController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Hozir nechta qoldi',
                            prefixIcon: Icon(Icons.inventory_2_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _refillThresholdController,
                          keyboardType: TextInputType.number,
                          enabled: _refillReminderOn,
                          decoration: const InputDecoration(
                            labelText: 'Nechtada eslatish',
                            prefixIcon: Icon(Icons.notification_important),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _DarkInput(
              controller: _notesController,
              label: 'NOTES (OPTIONAL)',
              hint: "Qo'shimcha izoh yozing",
              minLines: 3,
            ),
            const SizedBox(height: 16),
            AppButton(
              label: _loading
                  ? 'Saqlanmoqda...'
                  : _editing
                  ? 'Yangilash'
                  : 'Saqlash',
              onPressed: _loading ? null : _saveMedicine,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadFamilyMembers() async {
    try {
      final members = await _api.getFamilyMembers();
      if (mounted) {
        setState(() {
          _familyMembers
            ..clear()
            ..addAll(members);
        });
      }
    } on AuthApiException {
      // Dori qo'shish o'z profiliga bog'liq holda ishlayveradi.
    }
  }

  void _prefill() {
    final medicine = widget.initialMedicine;
    if (medicine == null) {
      _familyMemberId = widget.initialFamilyMemberId;
      return;
    }
    _nameController.text = (medicine['name'] ?? '').toString();
    _notesController.text = (medicine['notes'] ?? '').toString();
    _dose = (medicine['dosage'] ?? _dose).toString();
    _intake = _intakeLabel(medicine['intake_type']);
    _stockController.text = (medicine['stock_quantity'] ?? '').toString();
    _refillThresholdController.text = (medicine['refill_threshold'] ?? '5')
        .toString();
    _refillReminderOn = medicine['refill_reminder_enabled'] == true;
    _familyMemberId = _int(medicine['family_member_id']);
    _startDate =
        DateTime.tryParse((medicine['start_date'] ?? '').toString()) ??
        DateTime.now();
    _endDate = DateTime.tryParse((medicine['end_date'] ?? '').toString());

    final schedules = (medicine['schedules'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    if (schedules.isNotEmpty) {
      _times
        ..clear()
        ..addAll(
          schedules
              .map((item) => (item['time'] ?? '').toString())
              .where((time) => time.length >= 5)
              .map((time) => time.substring(0, 5)),
        );
      final days = schedules.first['repeat_days'];
      if (days is List && days.isNotEmpty) {
        _days
          ..clear()
          ..addAll(days.map((day) => _dayLabel(day.toString())));
      }
      _reminderBeforeMinutes =
          _int(schedules.first['reminder_before_minutes']) ?? 30;
      _reminderOn = _reminderBeforeMinutes > 0;
    }
  }

  void _showTimePicker() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Time Picker', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children:
                  [
                        '08:00',
                        '14:00',
                        '21:00',
                        '15:00',
                        '22:00',
                        '10:00',
                        '16:00',
                        '23:00',
                      ]
                      .map(
                        (t) => _TimeSheetChip(
                          label: t,
                          selected: _times.contains(t),
                          onTap: () {
                            setState(() {
                              if (!_times.contains(t)) {
                                _times.add(t);
                                _times.sort();
                              }
                            });
                            Navigator.pop(context);
                          },
                        ),
                      )
                      .toList(),
            ),
            const SizedBox(height: 18),
            TextButton.icon(
              onPressed: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (picked == null || !mounted) return;
                final value =
                    '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                setState(() {
                  if (!_times.contains(value)) {
                    _times.add(value);
                    _times.sort();
                  }
                });
                if (context.mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.add),
              label: const Text("Vaqt qo'shish"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked == null) return;
    setState(() {
      _startDate = picked;
      if (_endDate != null && _endDate!.isBefore(_startDate)) {
        _endDate = _startDate;
      }
    });
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate.add(const Duration(days: 7)),
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked == null) return;
    setState(() => _endDate = picked);
  }

  void _showIntervalPicker() {
    var start = const TimeOfDay(hour: 8, minute: 0);
    var end = const TimeOfDay(hour: 22, minute: 0);
    var intervalHours = 6;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> pickStart() async {
            final picked = await showTimePicker(
              context: context,
              initialTime: start,
            );
            if (picked != null) setSheetState(() => start = picked);
          }

          Future<void> pickEnd() async {
            final picked = await showTimePicker(
              context: context,
              initialTime: end,
            );
            if (picked != null) setSheetState(() => end = picked);
          }

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(
                    "Vaqt oralig'i",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _IntervalTile(
                        label: 'Boshlanish',
                        value: _timeText(start),
                        onTap: pickStart,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _IntervalTile(
                        label: 'Tugash',
                        value: _timeText(end),
                        onTap: pickEnd,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Har necha soatda',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [2, 3, 4, 6, 8, 12]
                      .map(
                        (hours) => _ChoicePill(
                          label: '$hours soat',
                          selected: intervalHours == hours,
                          onTap: () =>
                              setSheetState(() => intervalHours = hours),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 18),
                AppButton(
                  label: 'Vaqtlarni yaratish',
                  onPressed: () {
                    final generated = _generateIntervalTimes(
                      start: start,
                      end: end,
                      intervalHours: intervalHours,
                    );
                    if (generated.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Vaqt oralig'i noto'g'ri tanlandi"),
                        ),
                      );
                      return;
                    }
                    setState(() {
                      _times
                        ..clear()
                        ..addAll(generated);
                    });
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _saveMedicine() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Majburiy maydon');
      return;
    }
    if (_days.isEmpty || _times.isEmpty) {
      setState(() => _error = 'Kamida bitta kun va vaqt tanlang');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final body = _medicineBody(name);
      final created = _editing
          ? await _api.updateMedicine(
              _int(widget.initialMedicine?['id'])!,
              body,
            )
          : await _api.createMedicine(body);
      if (!mounted) return;
      unawaited(ReminderService.instance.scheduleMedicine(created));
      AppEvents.notifyMedicineChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_editing ? 'Dori yangilandi' : 'Dori saqlandi')),
      );
      if (_editing) {
        Navigator.pop(context, true);
      } else {
        _clearForm();
      }
    } on AuthApiException catch (error) {
      if (!mounted) return;
      if (!_editing && error.kind == AuthApiErrorKind.network) {
        final body = _medicineBody(name);
        await OfflineMedicineQueue.enqueueCreate(body);
        if (!mounted) return;
        setState(() => _error = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Internet yo‘q. Dori offline saqlandi va keyin sync qilinadi.',
            ),
          ),
        );
        _clearForm();
      } else {
        setState(() => _error = error.userMessage);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _clearForm() {
    _nameController.clear();
    _notesController.clear();
    _stockController.clear();
    _refillThresholdController.text = '5';
    _refillReminderOn = false;
  }

  Map<String, dynamic> _medicineBody(String name) {
    return {
      'family_member_id': _familyMemberId,
      'name': name,
      'dosage': _dose,
      'intake_type': _intakeType,
      'notes': _notesController.text.trim(),
      'stock_quantity': _optionalInt(_stockController.text),
      'refill_threshold': _refillReminderOn
          ? (_optionalInt(_refillThresholdController.text) ?? 0)
          : null,
      'refill_reminder_enabled': _refillReminderOn,
      'start_date': _dateOnly(_startDate),
      'end_date': _endDate == null ? null : _dateOnly(_endDate!),
      'schedules': _times
          .map(
            (time) => {
              'time': time,
              'repeat_days': _days.map(_repeatDay).toList()..sort(),
              'reminder_before_minutes': _reminderOn
                  ? _reminderBeforeMinutes
                  : 0,
            },
          )
          .toList(),
    };
  }

  Future<void> _syncPendingMedicines() async {
    try {
      final count = await OfflineMedicineQueue.sync(api: _api);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count == 0
                ? 'Sync qilinadigan offline dori yo‘q'
                : '$count ta offline dori sync qilindi',
          ),
        ),
      );
      setState(() {});
    } on AuthApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.userMessage)));
    }
  }

  String get _intakeType {
    return switch (_intake) {
      'Ovqatdan oldin' => 'before_food',
      'Ovqatdan keyin' => 'after_food',
      _ => 'no_matter',
    };
  }

  static String _repeatDay(String day) {
    return switch (day) {
      'Mon' => 'MON',
      'Tue' => 'TUE',
      'Wed' => 'WED',
      'Thu' => 'THU',
      'Fri' => 'FRI',
      'Sat' => 'SAT',
      'Sun' => 'SUN',
      _ => day.toUpperCase(),
    };
  }

  static String _dateOnly(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  static int? _int(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  static int? _optionalInt(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return int.tryParse(trimmed);
  }

  static String _intakeLabel(Object? value) {
    return switch (value?.toString()) {
      'before_food' => 'Ovqatdan oldin',
      'after_food' => 'Ovqatdan keyin',
      _ => "Farqi yo'q",
    };
  }

  static String _dayLabel(String value) {
    return switch (value.toUpperCase()) {
      'MON' => 'Mon',
      'TUE' => 'Tue',
      'WED' => 'Wed',
      'THU' => 'Thu',
      'FRI' => 'Fri',
      'SAT' => 'Sat',
      'SUN' => 'Sun',
      _ => value,
    };
  }

  static String _timeText(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  static List<String> _generateIntervalTimes({
    required TimeOfDay start,
    required TimeOfDay end,
    required int intervalHours,
  }) {
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    if (endMinutes < startMinutes || intervalHours <= 0) return const [];

    final result = <String>[];
    for (
      var minutes = startMinutes;
      minutes <= endMinutes;
      minutes += intervalHours * 60
    ) {
      final hour = minutes ~/ 60;
      final minute = minutes % 60;
      result.add(
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
      );
    }
    return result;
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );
}

class _OfflineQueueBanner extends StatelessWidget {
  const _OfflineQueueBanner({required this.count, required this.onSync});

  final int count;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.warningSoft,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.accent.withValues(alpha: 0.6)),
    ),
    child: Row(
      children: [
        Icon(
          Icons.cloud_off_outlined,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '$count ta dori offline queue’da turibdi',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        TextButton(onPressed: onSync, child: const Text('Sync')),
      ],
    ),
  );
}

class _DarkInput extends StatelessWidget {
  const _DarkInput({
    this.controller,
    required this.label,
    required this.hint,
    this.error,
    this.suffix,
    this.minLines = 1,
  });
  final TextEditingController? controller;
  final String label;
  final String hint;
  final String? error;
  final IconData? suffix;
  final int minLines;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: controller,
        minLines: minLines,
        maxLines: minLines,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          suffixIcon: suffix == null
              ? null
              : Icon(
                  suffix,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          fillColor: Theme.of(context).inputDecorationTheme.fillColor,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: error == null ? Colors.transparent : AppColors.error,
            ),
          ),
        ),
      ),
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            error!,
            style: const TextStyle(color: AppColors.error, fontSize: 12),
          ),
        ),
    ],
  );
}

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({required this.label, this.selected = false, this.onTap});
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) =>
      AppChip(label: label, selected: selected, onTap: onTap);
}

class _DateBox extends StatelessWidget {
  const _DateBox({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });
  final String label;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            Theme.of(context).inputDecorationTheme.fillColor ??
            Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          if (onClear != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: onClear,
              icon: const Icon(Icons.close, size: 16),
            )
          else
            Icon(
              Icons.calendar_month,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: 18,
            ),
        ],
      ),
    ),
  );
}

class _IntervalTile extends StatelessWidget {
  const _IntervalTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.schedule, size: 18),
              const SizedBox(width: 8),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _TimeSheetChip extends StatelessWidget {
  const _TimeSheetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 82,
    child: AppChip(
      label: label,
      selected: selected,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 12),
    ),
  );
}
