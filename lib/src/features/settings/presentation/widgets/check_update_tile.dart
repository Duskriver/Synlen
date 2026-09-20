import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synlen/l10n/app_localizations.dart';
import 'package:synlen/src/core/services/toast_service.dart';
import 'package:synlen/src/core/url_launcher/url_launcher.dart';
import 'package:synlen/src/features/settings/application/update_check.dart';
import 'package:synlen/src/features/settings/domain/update_exception.dart';
import 'package:synlen/src/features/settings/domain/version_manifest.dart';
import 'package:synlen/src/features/settings/presentation/widgets/settings_info_section.dart';
import 'package:synlen/src/features/settings/presentation/widgets/simple_markdown.dart';

/// 按更新错误码映射用户可读文案；内部细节已在 application 层入日志。
String _updateErrorMessage(AppLocalizations l10n, UpdateErrorCode? code) {
  return switch (code) {
    UpdateErrorCode.noUpdateChannel => l10n.noUpdateChannel,
    UpdateErrorCode.insecureUrl => l10n.updateInsecureUrl,
    UpdateErrorCode.downloadFailed => l10n.downloadFailed,
    UpdateErrorCode.checksumMismatch => l10n.updateChecksumMismatch,
    UpdateErrorCode.invalidChecksum => l10n.updateInvalidChecksum,
    UpdateErrorCode.installFailed => l10n.updateInstallFailed,
    UpdateErrorCode.installPermissionDenied =>
      l10n.installUnknownSourcesRequired,
    UpdateErrorCode.checkFailed || null => l10n.updateCheckFailed,
  };
}

/// 更新检查入口：只余 UI 与状态订阅，检查 / 下载 / 校验逻辑在
/// application 与 data 层（[UpdateCheck]）。
class CheckUpdateTile extends ConsumerWidget {
  const CheckUpdateTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isChecking = ref.watch(updateCheckProvider).isLoading;
    return SettingsInfoTile(
      icon: Icons.system_update_outlined,
      title: l10n.checkForUpdates,
      subtitle: l10n.checkForUpdatesSubtitle,
      trailing: isChecking
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      onTap: isChecking ? null : () => _checkForUpdates(context, ref),
    );
  }

  Future<void> _checkForUpdates(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    await ref.read(updateCheckProvider.notifier).checkForUpdates();
    if (!context.mounted) return;
    ref
        .read(updateCheckProvider)
        .when(
          data: (update) {
            switch (update.checkStatus) {
              case UpdateCheckStatus.upToDate:
                ToastService.showSuccess(l10n.upToDate);
              case UpdateCheckStatus.updateAvailable:
                final manifest = update.manifest;
                if (manifest != null) {
                  showDialog<void>(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => _UpdateDialog(manifest: manifest),
                  );
                }
              case UpdateCheckStatus.idle:
                break;
            }
          },
          error: (error, _) => ToastService.showError(
            _updateErrorMessage(
              l10n,
              error is UpdateException ? error.code : null,
            ),
          ),
          // await 返回后状态必非 loading；列出该分支保持三态齐全
          loading: () {},
        );
  }
}

class _UpdateDialog extends ConsumerWidget {
  const _UpdateDialog({required this.manifest});

  final VersionManifest manifest;

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await UrlLauncher.canLaunch(uri)) {
      await UrlLauncher.launch(uri);
    }
  }

  Future<void> _openLanzou(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    if (manifest.lanzouPassword.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: manifest.lanzouPassword));
      ToastService.showSuccess(l10n.passwordCopied);
    }
    await _launchUrl(manifest.lanzouUrl);
  }

  Future<void> _downloadAndInstall(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    await ref.read(updateCheckProvider.notifier).downloadAndInstall();
    if (!context.mounted) return;
    final download = ref
        .read(updateCheckProvider)
        .when(
          data: (update) => update.download,
          error: (_, _) => const UpdateDownloadState(
            status: UpdateDownloadStatus.failed,
            errorCode: UpdateErrorCode.downloadFailed,
          ),
          loading: () => const UpdateDownloadState(),
        );
    switch (download.status) {
      case UpdateDownloadStatus.installerOpened:
        ToastService.showInfo(l10n.updateInstallerOpened);
      case UpdateDownloadStatus.failed:
        ToastService.showError(_updateErrorMessage(l10n, download.errorCode));
      case UpdateDownloadStatus.idle ||
          UpdateDownloadStatus.downloading ||
          UpdateDownloadStatus.canceling ||
          UpdateDownloadStatus.canceled:
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final download = ref
        .watch(updateCheckProvider)
        .when(
          data: (update) => update.download,
          error: (_, _) => const UpdateDownloadState(),
          loading: () => const UpdateDownloadState(),
        );
    final downloading = download.isBusy;
    final platform = Theme.of(context).platform;
    final isAndroid = platform == TargetPlatform.android;
    final hasDirectLink = isAndroid && manifest.androidApkUrl.isNotEmpty;
    final hasAppStore =
        platform == TargetPlatform.iOS && manifest.iosAppStoreUrl.isNotEmpty;

    return PopScope(
      canPop: !downloading,
      child: AlertDialog(
        title: Text(l10n.newVersionAvailable),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  manifest.versionLabel,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SimpleMarkdown(text: manifest.updateLog),
                if (downloading) ...[
                  const SizedBox(height: 16),
                  LinearProgressIndicator(value: download.progress),
                  const SizedBox(height: 8),
                  if (download.progress case final progress?)
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}%',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          if (hasDirectLink)
            FilledButton(
              onPressed: downloading
                  ? null
                  : () => _downloadAndInstall(context, ref),
              child: Text(l10n.downloadAndInstall),
            ),
          if (hasAppStore)
            FilledButton(
              onPressed: downloading
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      _launchUrl(manifest.iosAppStoreUrl);
                    },
              child: Text(l10n.goToAppStore),
            ),
          if (!hasDirectLink && !hasAppStore)
            TextButton(
              onPressed: downloading
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      ToastService.showInfo(l10n.noUpdateChannel);
                    },
              child: Text(l10n.goToAppStore),
            ),
          if (manifest.lanzouUrl.isNotEmpty)
            TextButton(
              onPressed: downloading
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      _openLanzou(context);
                    },
              child: Text(l10n.updateViaChinaCloud),
            ),
          if (manifest.githubUrl.isNotEmpty)
            TextButton(
              onPressed: downloading
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      _launchUrl(manifest.githubUrl);
                    },
              child: Text(l10n.updateViaGithub),
            ),
          TextButton(
            onPressed: download.status == UpdateDownloadStatus.canceling
                ? null
                : () async {
                    if (downloading) {
                      await ref
                          .read(updateCheckProvider.notifier)
                          .cancelDownload();
                      if (!context.mounted) return;
                      final busy =
                          ref
                              .read(updateCheckProvider)
                              .asData
                              ?.value
                              .download
                              .isBusy ??
                          false;
                      if (busy) return;
                      // 等待 PopScope 接收已取消状态，再关闭路由。
                      await WidgetsBinding.instance.endOfFrame;
                      if (!context.mounted) return;
                    }
                    Navigator.of(context).pop();
                  },
            child: Text(downloading ? l10n.cancel : l10n.close),
          ),
        ],
      ),
    );
  }
}
