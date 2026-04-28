import 'package:flutter/material.dart';

import '../core/app_colors.dart';

class MedicineBottleIllustration extends StatelessWidget {
  const MedicineBottleIllustration({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 82.0 : 150.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * 0.72,
            height: size * 0.86,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF6F1),
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          Transform.rotate(
            angle: -0.18,
            child: _Bottle(
              width: size * 0.34,
              height: size * 0.62,
              color: AppColors.primary,
              pillColor: AppColors.secondary,
            ),
          ),
          Positioned(
            right: size * 0.18,
            bottom: size * 0.24,
            child: Transform.rotate(
              angle: 0.16,
              child: _Bottle(
                width: size * 0.27,
                height: size * 0.48,
                color: const Color(0xFFFFC857),
                pillColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HealthChecklistIllustration extends StatelessWidget {
  const HealthChecklistIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned(
            left: 8,
            bottom: 12,
            child: _Person(color: AppColors.primary),
          ),
          const Positioned(
            right: 8,
            bottom: 12,
            child: _Person(color: AppColors.secondary),
          ),
          Container(
            width: 88,
            height: 118,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x18000000),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: List.generate(
                4,
                (index) => Padding(
                  padding: EdgeInsets.only(bottom: index == 3 ? 0 : 9),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        size: 14,
                        color: AppColors.secondary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE1E7EF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HealthyLifeIllustration extends StatelessWidget {
  const HealthyLifeIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 118,
            height: 118,
            decoration: const BoxDecoration(
              color: Color(0xFFE4F7ED),
              shape: BoxShape.circle,
            ),
          ),
          Positioned(
            left: 10,
            bottom: 14,
            child: Icon(
              Icons.local_florist,
              size: 48,
              color: Colors.green.shade400,
            ),
          ),
          const Positioned(
            top: 26,
            child: Icon(Icons.favorite, color: AppColors.secondary, size: 28),
          ),
          Positioned(
            bottom: 16,
            child: Container(
              width: 72,
              height: 92,
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 52),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bottle extends StatelessWidget {
  const _Bottle({
    required this.width,
    required this.height,
    required this.color,
    required this.pillColor,
  });

  final double width;
  final double height;
  final Color color;
  final Color pillColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 4),
      ),
      child: Center(
        child: Container(
          width: width * 0.5,
          height: height * 0.28,
          decoration: BoxDecoration(
            color: pillColor,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}

class _Person extends StatelessWidget {
  const _Person({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: color,
          child: const Icon(Icons.person, size: 18, color: Colors.white),
        ),
        Container(width: 18, height: 46, color: color),
      ],
    );
  }
}
