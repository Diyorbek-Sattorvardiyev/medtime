import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const primary = Color(0xFF22C55E);
  static const secondary = Color(0xFF3B82F6);
  static const background = Color(0xFFF8FAFC);
  static const darkBackground = Color(0xFF0F172A);
  static const surface = Colors.white;
  static const accent = Color(0xFFFACC15);
  static const error = Color(0xFFEF4444);
  static const text = Color(0xFF0F172A);
  static const mutedText = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);
  static const successSoft = Color(0xFFDCFCE7);
  static const warningSoft = Color(0xFFFEF9C3);
  static const errorSoft = Color(0xFFFEE2E2);

  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, secondary],
  );

  static const softShadow = [
    BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4)),
  ];

  static const floatingShadow = [
    BoxShadow(color: Color(0x1F000000), blurRadius: 24, offset: Offset(0, 8)),
  ];
}
