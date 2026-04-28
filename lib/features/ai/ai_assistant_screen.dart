import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../widgets/app_card.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final _controller = TextEditingController();
  final _messages = <_ChatMessage>[
    const _ChatMessage(
      text:
          'Assalomu alaykum. Dori vaqti, unutib qo‘yish yoki ovqatdan oldin/keyin qabul qilish bo‘yicha savol yozing.',
      fromUser: false,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: const Text('AI yordamchi')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _ChatBubble(message: message, index: index);
              },
            ),
          ),
          _QuickQuestions(onPick: _sendText),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: AppCard(
                radius: 18,
                padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: _sendText,
                        decoration: const InputDecoration(
                          hintText: 'Savolingizni yozing...',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: EdgeInsets.symmetric(horizontal: 4),
                        ),
                      ),
                    ),
                    IconButton.filled(
                      onPressed: () => _sendText(_controller.text),
                      icon: const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _sendText(String rawText) {
    final text = rawText.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_ChatMessage(text: text, fromUser: true));
      _messages.add(_ChatMessage(text: _answerFor(text), fromUser: false));
      _controller.clear();
    });
  }

  String _answerFor(String question) {
    final lower = question.toLowerCase();
    if (lower.contains('unut') ||
        lower.contains('o‘tkaz') ||
        lower.contains("o'tkaz")) {
      return 'Agar dori vaqti o‘tib ketgan bo‘lsa, ilovada “Keyinroq” yoki “O‘tkazdim” ni belgilang. Ikki dozani bir vaqtda ichmang, avval dori yo‘riqnomasini tekshiring.';
    }
    if (lower.contains('ovqat')) {
      return 'Ovqatdan oldin yoki keyin ichish dori turiga bog‘liq. Dori kartasida belgilangan qoidaga amal qiling. Oshqozonni bezovta qiladigan dorilar ko‘pincha ovqatdan keyin ichiladi.';
    }
    if (lower.contains('vaqt') || lower.contains('qachon')) {
      return 'Dorini ilovadagi jadvalda ko‘rsatilgan Toshkent vaqti bo‘yicha iching. Eslatma kelganda “Ichdim” ni bosing yoki kerak bo‘lsa “Keyinroq” qiling.';
    }
    return 'Bu tibbiy maslahat emas. Aniq doza va qabul qilish tartibini shifokor yoki dori yo‘riqnomasi bo‘yicha tekshiring. Ilovada esa jadval, eslatma va qabul statusini yuritishingiz mumkin.';
  }
}

class _QuickQuestions extends StatelessWidget {
  const _QuickQuestions({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    const questions = [
      'Dorini unutib qo‘ysam nima qilaman?',
      'Ovqatdan oldin/keyin farqi nima?',
      'Dorini qachon ichish kerak?',
    ];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) => ActionChip(
          label: Text(questions[index]),
          onPressed: () => onPick(questions[index]),
        ),
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemCount: questions.length,
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message, required this.index});

  final _ChatMessage message;
  final int index;

  @override
  Widget build(BuildContext context) {
    final align = message.fromUser
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final color = message.fromUser
        ? AppColors.primary
        : Theme.of(context).colorScheme.surface;
    final textColor = message.fromUser
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 220 + index * 25),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - value)),
          child: child,
        ),
      ),
      child: Align(
        alignment: align,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 310),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(message.fromUser ? 18 : 5),
              bottomRight: Radius.circular(message.fromUser ? 5 : 18),
            ),
            boxShadow: Theme.of(context).brightness == Brightness.dark
                ? const []
                : AppColors.softShadow,
          ),
          child: Text(
            message.text,
            style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({required this.text, required this.fromUser});

  final String text;
  final bool fromUser;
}
