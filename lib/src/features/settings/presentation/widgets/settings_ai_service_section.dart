import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synlen/l10n/app_localizations.dart';
import 'package:synlen/src/core/services/toast_service.dart';
import 'package:synlen/src/features/settings/application/api_key_notifier.dart';
import 'settings_info_section.dart';

/// AI 服务设置分组：配置 DeepSeek 与阿里云 TTS 的 API Key（用户自填）
class SettingsAiServiceSection extends ConsumerWidget {
  const SettingsAiServiceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final config = ref.watch(apiKeyProvider);

    return SettingsInfoSection(
      title: l10n.aiService,
      children: [
        SettingsInfoTile(
          icon: Icons.smart_toy_outlined,
          title: l10n.deepSeekApiKey,
          subtitle: config.deepSeekKey.isEmpty
              ? l10n.apiKeyNotConfigured
              : l10n.deepSeekApiKeySubtitle,
          onTap: () => _editKeyDialog(
            context,
            title: l10n.deepSeekApiKey,
            hint: l10n.deepSeekApiKeySubtitle,
            providerName: 'DeepSeek',
            initialValue: config.deepSeekKey,
            onSave: (value) => ref
                .read(apiKeyProvider.notifier)
                .setDeepSeekKey(value),
          ),
        ),
        SettingsInfoTile(
          icon: Icons.record_voice_over_outlined,
          title: l10n.aliyunTtsApiKey,
          subtitle: config.aliyunTtsKey.isEmpty
              ? l10n.apiKeyNotConfigured
              : l10n.aliyunTtsApiKeySubtitle,
          onTap: () => _editKeyDialog(
            context,
            title: l10n.aliyunTtsApiKey,
            hint: l10n.aliyunTtsApiKeySubtitle,
            providerName: '阿里云 DashScope',
            initialValue: config.aliyunTtsKey,
            onSave: (value) => ref
                .read(apiKeyProvider.notifier)
                .setAliyunTtsKey(value),
          ),
        ),
      ],
    );
  }

  /// 弹出 API Key 编辑对话框（密码模式，可切换明文、可清除）
  Future<void> _editKeyDialog(
    BuildContext context, {
    required String title,
    required String hint,
    required String providerName,
    required String initialValue,
    required Future<void> Function(String value) onSave,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: initialValue);
    var obscure = true;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                obscureText: obscure,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  hintText: l10n.apiKeyInputHint,
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscure ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => obscure = !obscure),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.apiKeyObtainHint(providerName),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
          ),
          actions: [
            if (initialValue.isNotEmpty)
              TextButton(
                onPressed: () async {
                  await onSave('');
                  if (context.mounted) {
                    ToastService.showSuccess(l10n.apiKeyCleared);
                    Navigator.of(context).pop();
                  }
                },
                child: Text(l10n.clearKey),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () async {
                await onSave(controller.text.trim());
                if (context.mounted) {
                  ToastService.showSuccess(l10n.apiKeySaved);
                  Navigator.of(context).pop();
                }
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }
}
