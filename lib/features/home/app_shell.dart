import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_settings.dart';
import '../add/add_medicine_screen.dart';
import '../medicines/medicine_list_screen.dart';
import '../profile/profile_screen.dart';
import '../stats/statistics_screen.dart';
import 'home_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  var _index = 0;
  late final List<Widget> _pages = [
    const HomeScreen(),
    MedicineListScreen(onAddTap: _openAddMedicineSheet),
    const SizedBox.shrink(),
    const StatisticsScreen(),
    const ProfileScreen(),
  ];

  void _setIndex(int value) {
    if (value == 2) {
      _openAddMedicineSheet();
      return;
    }
    if (_index == value) return;
    setState(() => _index = value);
  }

  Future<void> _openAddMedicineSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final topGap = MediaQuery.paddingOf(context).top + kToolbarHeight + 10;
        return Padding(
          padding: EdgeInsets.only(top: topGap),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: const AddMedicineScreen(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(index: _index, children: _pages),
          IgnorePointer(
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              alignment: Alignment((_index - 2) * 0.08, 1),
              child: const SizedBox.shrink(),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        width: 58,
        height: 58,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.brandGradient,
          boxShadow: AppColors.floatingShadow,
        ),
        child: IconButton(
          onPressed: () => _setIndex(2),
          icon: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: BottomAppBar(
            height: 72,
            color: (dark ? const Color(0xFF111827) : Colors.white).withValues(
              alpha: 0.94,
            ),
            notchMargin: 8,
            shape: const CircularNotchedRectangle(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.home_outlined,
                  label: strings.home,
                  selected: _index == 0,
                  onTap: () => _setIndex(0),
                ),
                _NavItem(
                  icon: Icons.medication_outlined,
                  label: strings.medicines,
                  selected: _index == 1,
                  onTap: () => _setIndex(1),
                ),
                const SizedBox(width: 56),
                _NavItem(
                  icon: Icons.bar_chart_outlined,
                  label: strings.stats,
                  selected: _index == 3,
                  onTap: () => _setIndex(3),
                ),
                _NavItem(
                  icon: Icons.person_outline,
                  label: strings.profile,
                  selected: _index == 4,
                  onTap: () => _setIndex(4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        width: 56,
        height: 54,
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: selected
                  ? AppColors.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
                color: selected
                    ? AppColors.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
