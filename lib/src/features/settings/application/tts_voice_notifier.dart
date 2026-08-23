import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synlen/src/core/providers/shared_preferences_provider.dart';
import 'package:synlen/src/features/learning/domain/aliyun_tts_voice.dart';

final ttsVoiceProvider = NotifierProvider<TtsVoiceNotifier, AliyunTtsVoice>(
  TtsVoiceNotifier.new,
);

class TtsVoiceNotifier extends Notifier<AliyunTtsVoice> {
  static const _kTtsVoice = 'tts_voice';

  @override
  AliyunTtsVoice build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return AliyunTtsVoice.fromVoiceParam(prefs.getString(_kTtsVoice));
  }

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  Future<void> setVoice(AliyunTtsVoice voice) async {
    await _prefs.setString(_kTtsVoice, voice.voiceParam);
    state = voice;
  }
}
