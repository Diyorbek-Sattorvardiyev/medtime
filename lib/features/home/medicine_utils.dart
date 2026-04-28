import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/demo_data.dart';

IconData statusIcon(MedicineStatus status) {
  return switch (status) {
    MedicineStatus.taken => Icons.check_circle_outline,
    MedicineStatus.missed => Icons.highlight_off,
    MedicineStatus.later => Icons.alarm,
    MedicineStatus.pending => Icons.medication_outlined, // Use a medicine icon for pending
  };
}

Color statusColor(MedicineStatus status) {
  return switch (status) {
    MedicineStatus.taken => AppColors.primary,
    MedicineStatus.missed => AppColors.error,
    MedicineStatus.later => AppColors.accent,
    MedicineStatus.pending => Colors.grey, // Grey for pending/default
  };
}