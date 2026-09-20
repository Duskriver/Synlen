import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synlen/l10n/app_localizations.dart';
import 'package:synlen/src/core/services/toast_service.dart';
import 'api_key_dialog.dart';
import '../../application/deep_seek_connectivity.dart';
import 'package:synlen/src/features/settings/application/api_key_notifier.dart';
import 'settings_info_section.dart';

/// AI 服务设置分组：配置 DeepSeek 与阿里云 TTS 的 API Key（用户自填）
class SettingsAiServiceSection extends ConsumerWidget {
  const SettingsAiServiceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final config = ref.watch(apiKeyProvider);
    return config.when(
      skipLoadingOnRefresh: false,
      loading: () => SettingsInfoSection(
        title: l10n.aiService,
        children: [
          ListTile(
            title: Text(l10n.loading),
            leading: const CircularProgressIndicator(),
          ),
        ],
      ),
      error: (_, _) => SettingsInfoSection(
        title: l10n.aiService,
        children: [
          ListTile(
            title: Text(l10n.apiKeyLoadFailed),
            trailing: TextButton(
              onPressed: () => ref.invalidate(apiKeyProvider),
              child: Text(l10n.retry),
            ),
          ),
        ],
      ),
      data: (config) => _buildConfigured(context, ref, config),
    );
  }

  Widget _buildConfigured(
    BuildContext context,
    WidgetRef ref,
    ApiKeyConfig config,
  ) {
    final l10n = AppLocalizations.of(context)!;

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
            providerName: 'DeepSeek',
            initialValue: config.deepSeekKey,
            onSave: (value) =>
                ref.read(apiKeyProvider.notifier).setDeepSeekKey(value),
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
            providerName: l10n.aliyunDashScopeName,
            initialValue: config.aliyunTtsKey,
            onSave: (value) =>
                ref.read(apiKeyProvider.notifier).setAliyunTtsKey(value),
          ),
        ),
        _DeepSeekConnectivityCheckTile(apiKey: config.deepSeekKey),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
          child: Text(
            l10n.aiServicePrivacyNote,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _editKeyDialog(
    BuildContext context, {
    required String title,
    required String providerName,
    required String initialValue,
    required Future<bool> Function(String value) onSave,
  }) => showDialog<void>(
    context: context,
    builder: (_) => ApiKeyDialog(
      title: title,
      providerName: providerName,
      initialValue: initialValue,
      onSave: onSave,
    ),
  );
}

/// DeepSeek 连通性检查：GET /models 不消耗 tokens，验证密钥与网络。
class _DeepSeekConnectivityCheckTile extends ConsumerWidget {
  const _DeepSeekConnectivityCheckTile({required this.apiKey});

  final String apiKey;

  Future<void> _check(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    await ref.read(deepSeekKeyCheckProvider.notifier).check(apiKey);
    if (!context.mounted) return;
    ref
        .read(deepSeekKeyCheckProvider)
        .when(
          data: (outcome) {
            switch (outcome) {
              case DeepSeekConnectivity.ok:
                ToastService.showSuccess(l10n.deepSeekCheckOk);
              case DeepSeekConnectivity.notConfigured:
                ToastService.showError(l10n.apiKeyNotConfigured);
              case DeepSeekConnectivity.invalidKey:
                ToastService.showError(l10n.deepSeekCheckBadKey);
              case DeepSeekConnectivity.unreachable:
                ToastService.showError(l10n.deepSeekCheckFailed);
              case null:
                break;
            }
          },
          error: (_, _) => ToastService.showError(l10n.deepSeekCheckFailed),
          loading: () {},
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final checking = ref.watch(deepSeekKeyCheckProvider).isLoading;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
      leading: checking
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              Icons.network_check_outlined,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      title: Text(l10n.deepSeekCheckConnectivity),
      onTap: checking ? null : () => _check(context, ref),
    );
  }
}
