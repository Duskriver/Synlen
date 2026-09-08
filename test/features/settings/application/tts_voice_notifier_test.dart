import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synlen/src/core/providers/shared_preferences_provider.dart';
import 'package:synlen/src/features/learning/domain/aliyun_tts_voice.dart';
import 'package:synlen/src/features/settings/application/tts_voice_notifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> buildContainer([
    Map<String, Object> initial = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(initial);
    final prefs = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  }

  test('未持久化时回退默认音色', () async {
    final container = await buildContainer();
    addTearDown(container.dispose);

    expect(container.read(ttsVoiceProvider), AliyunTtsVoice.defaultVoice);
  });

  test('读取已持久化的音色', () async {
    const target = AliyunTtsVoice.stella;
    final container = await buildContainer({'tts_voice': target.voiceParam});
    addTearDown(container.dispose);

    expect(container.read(ttsVoiceProvider), target);
  });

  test('未知音色参数回退默认值', () async {
    final container = await buildContainer({'tts_voice': 'not-a-voice'});
    addTearDown(container.dispose);

    expect(container.read(ttsVoiceProvider), AliyunTtsVoice.defaultVoice);
  });

  test('setVoice 持久化并更新状态', () async {
    const target = AliyunTtsVoice.ethan;
    final container = await buildContainer();
    addTearDown(container.dispose);

    await container.read(ttsVoiceProvider.notifier).setVoice(target);

    expect(container.read(ttsVoiceProvider), target);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('tts_voice'), target.voiceParam);
  });
}
