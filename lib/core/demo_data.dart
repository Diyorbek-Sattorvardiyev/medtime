import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'tashkent_time.dart';

enum MedicineStatus { pending, taken, later, missed }

class Medicine {
  const Medicine({
    this.id,
    this.scheduleId,
    this.plannedAt,
    this.imageUrl,
    required this.name,
    required this.dose,
    required this.time,
    required this.status,
    required this.color,
  });

  final int? id;
  final int? scheduleId;
  final String? plannedAt;
  final String? imageUrl;
  final String name;
  final String dose;
  final String time;
  final MedicineStatus status;
  final Color color;

  Medicine copyWith({MedicineStatus? status}) {
    final nextStatus = status ?? this.status;
    return Medicine(
      id: id,
      scheduleId: scheduleId,
      plannedAt: plannedAt,
      imageUrl: imageUrl,
      name: name,
      dose: dose,
      time: time,
      status: nextStatus,
      color: statusColor(nextStatus),
    );
  }

  factory Medicine.fromJson(Map<String, dynamic> json) {
    final schedules = json['schedules'];
    final directSchedule = json['schedule'];
    final firstSchedule = schedules is List && schedules.isNotEmpty
        ? schedules.first
        : directSchedule;
    final schedule = firstSchedule is Map
        ? Map<String, dynamic>.from(firstSchedule)
        : <String, dynamic>{};
    final status = _statusFrom(json['status'] ?? schedule['status']);
    final plannedAt =
        (json['planned_at'] ?? schedule['planned_at'])?.toString() ??
        _todayPlannedAt(schedule['time']);
    return Medicine(
      id: _intFrom(json['id'] ?? json['medicine_id']),
      scheduleId: _intFrom(schedule['id'] ?? schedule['schedule_id']),
      plannedAt: plannedAt,
      imageUrl: (json['image_url'] ?? json['image_path'])?.toString(),
      name: (json['name'] ?? json['medicine_name'] ?? 'Dori').toString(),
      dose: (json['dosage'] ?? json['dose'] ?? '').toString(),
      time: _displayTime(
        schedule['time'] ?? json['time'] ?? json['planned_at'],
      ),
      status: status,
      color: statusColor(status),
    );
  }
}

String? _todayPlannedAt(Object? time) {
  final text = time?.toString();
  if (text == null || text.length < 5 || !text.contains(':')) return null;
  final now = tashkentNow();
  return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}T${text.substring(0, 5)}:00';
}

int? _intFrom(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '');
}

MedicineStatus _statusFrom(Object? value) {
  return switch (value?.toString()) {
    'taken' => MedicineStatus.taken,
    'missed' => MedicineStatus.missed,
    'snoozed' => MedicineStatus.later,
    'pending' => MedicineStatus.pending,
    _ => MedicineStatus.pending,
  };
}

String _displayTime(Object? value) {
  final text = value?.toString() ?? '';
  if (text.contains('T')) {
    final parsed = DateTime.tryParse(text);
    if (parsed != null) {
      return '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
    }
  }
  if (text.length >= 5 && text.contains(':')) return text.substring(0, 5);
  return text;
}

const demoMedicines = [
  Medicine(
    name: 'Paracetamol',
    dose: '500 mg',
    time: '08:00',
    status: MedicineStatus.taken,
    color: AppColors.primary,
  ),
  Medicine(
    name: 'Vitamin D',
    dose: '1 kapsula',
    time: '13:30',
    status: MedicineStatus.later,
    color: AppColors.accent,
  ),
  Medicine(
    name: 'Omega-3',
    dose: '2 dona',
    time: '21:00',
    status: MedicineStatus.missed,
    color: AppColors.error,
  ),
];

String statusLabel(MedicineStatus status) {
  return switch (status) {
    MedicineStatus.pending => 'Kutilmoqda',
    MedicineStatus.taken => 'Ichildi',
    MedicineStatus.later => 'Keyinroq',
    MedicineStatus.missed => "O'tkazildi",
  };
}

Color statusColor(MedicineStatus status) {
  return switch (status) {
    MedicineStatus.pending => AppColors.secondary,
    MedicineStatus.taken => AppColors.primary,
    MedicineStatus.later => AppColors.accent,
    MedicineStatus.missed => AppColors.error,
  };
}

IconData statusIcon(MedicineStatus status) {
  return switch (status) {
    MedicineStatus.pending => Icons.radio_button_unchecked,
    MedicineStatus.taken => Icons.check_circle,
    MedicineStatus.later => Icons.schedule,
    MedicineStatus.missed => Icons.cancel,
  };
}
