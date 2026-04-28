import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_chip.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  var _question = 'Bu dorini qachon ichish kerak?';

  @override
  Widget build(BuildContext context) {
    final answer = _answerFor(_question);
    return Scaffold(
      appBar: AppBar(title: const Text('AI yordamchi')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          AppCard(
            radius: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Savol tanlang',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      [
                            'Bu dorini qachon ichish kerak?',
                            'Dorini unutib qo‘ysam nima qilaman?',
                            'Ovqatdan oldin/keyin farqi nima?',
                          ]
                          .map(
                            (item) => AppChip(
                              label: item,
                              selected: _question == item,
                              onTap: () => setState(() => _question = item),
                            ),
                          )
                          .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppCard(
            radius: 18,
            floating: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.auto_awesome,
                  color: AppColors.primary,
                  size: 32,
                ),
                const SizedBox(height: 10),
                Text(
                  'Qisqa javob',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(answer, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 12),
                const Text(
                  'Bu tibbiy maslahat emas. Aniq dozani shifokor yoki dori yo‘riqnomasiga qarab belgilang.',
                  style: TextStyle(fontSize: 12, color: AppColors.error),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _answerFor(String question) {
    if (question.contains('unutib')) {
      return 'Agar dori vaqti o‘tib ketgan bo‘lsa, ilovada “Keyinroq” yoki “O‘tkazdim” ni belgilang. Ikki dozani bir vaqtda ichmang, avval yo‘riqnomani tekshiring.';
    }
    if (question.contains('Ovqatdan')) {
      return 'Ba’zi dorilar oshqozonni bezovta qilmasligi uchun ovqatdan keyin, ayrimlari esa yaxshi so‘rilishi uchun ovqatdan oldin ichiladi.';
    }
    return 'Dori kartasida belgilangan vaqt va ovqat turi bo‘yicha iching. Eslatma kelganda “Ichdim” deb belgilang, kechiktirish kerak bo‘lsa “Keyinroq” ni tanlang.';
  }
}
