import 'package:flutter/services.dart';

class VoiceService {
  VoiceService._();

  static final instance = VoiceService._();
  static const _channel = MethodChannel('medtime/voice');

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    try {
      await _channel.invokeMethod<void>('speak', {'text': text});
    } on MissingPluginException {
      // Voice reminder is Android-native in this app.
    }
  }
}
