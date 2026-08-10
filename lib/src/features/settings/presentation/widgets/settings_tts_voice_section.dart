import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synlen/src/features/learning/domain/aliyun_tts_voice.dart';
import 'package:synlen/src/features/settings/application/tts_voice_notifier.dart';
import 'package:synlen/src/features/settings/presentation/widgets/settings_info_section.dart';

import '../../../../../l10n/app_localizations.dart';

class SettingsTtsVoiceSection extends ConsumerWidget {
  const SettingsTtsVoiceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final voice = ref.watch(ttsVoiceProvider);

    return SettingsInfoSection(
      title: l10n.aiReading,
      children: [
        SettingsInfoTile(
          icon: Icons.record_voice_over_outlined,
          title: l10n.ttsVoice,
          subtitle: '${voice.summary}\n${voice.description}',
          onTap: () => _showVoicePicker(context, ref, voice),
          trailing: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Future<void> _showVoicePicker(
    BuildContext context,
    WidgetRef ref,
    AliyunTtsVoice currentVoice,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(ttsVoiceProvider.notifier);

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.82,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.ttsVoicePickerTitle,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.ttsVoicePickerSubtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: AliyunTtsVoice.values.length,
                    itemBuilder: (context, index) {
                      final voice = AliyunTtsVoice.values[index];
                      final isSelected = voice == currentVoice;
                      return ListTile(
                        selected: isSelected,
                        leading: Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                        ),
                        title: Text(voice.summary),
                        subtitle: Text(voice.description),
                        onTap: () async {
                          await notifier.setVoice(voice);
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
