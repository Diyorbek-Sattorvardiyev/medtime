import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_routes.dart';
import '../../widgets/app_button.dart';
import '../../widgets/medicine_illustrations.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  var _index = 0;

  final _pages = const [
    _OnboardingData(
      title: 'Dorini unutma',
      description:
          "Ilova sizga dorilarni vaqtida eslatadi\nva sog'lig'ingizni nazorat qiladi",
      illustration: HealthyLifeIllustration(),
    ),
    _OnboardingData(
      title: 'Nazorat qil',
      description:
          "Har kuni dorilarni qabul qilish holatini\nkuzating va natijani ko'ring",
      illustration: HealthChecklistIllustration(),
    ),
    _OnboardingData(
      title: 'Oson va qulay',
      description: 'Bir necha bosishda barcha\ndorilarni boshqaring',
      illustration: MedicineBottleIllustration(),
    ),
  ];

  void _next() {
    if (_index == _pages.length - 1) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 12, top: 6),
                child: TextButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).pushReplacementNamed(AppRoutes.login),
                  child: const Text("O'tkazish"),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (value) => setState(() => _index = value),
                itemBuilder: (context, index) =>
                    _OnboardingPage(data: _pages[index]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(
                      context,
                    ).pushReplacementNamed(AppRoutes.login),
                    child: const Text("O'tkazish"),
                  ),
                  const Spacer(),
                  Row(
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: _index == index ? 18 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: _index == index
                              ? AppColors.primary
                              : const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton(onPressed: _next, child: const Text('Keyingi')),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
              child: AppButton(label: 'Boshlash', onPressed: _next),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingData {
  const _OnboardingData({
    required this.title,
    required this.description,
    required this.illustration,
  });

  final String title;
  final String description;
  final Widget illustration;
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data});

  final _OnboardingData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Expanded(
            flex: 6,
            child: Center(
              child: SizedBox(
                width: 210,
                height: 190,
                child: data.illustration,
              ),
            ),
          ),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Text(
            data.description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}
