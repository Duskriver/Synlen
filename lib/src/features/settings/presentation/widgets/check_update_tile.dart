import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:synlen/l10n/app_localizations.dart';
import 'package:synlen/src/core/services/app_logger.dart';
import 'package:synlen/src/core/services/toast_service.dart';
import 'package:synlen/src/core/url_launcher/url_launcher.dart';
import 'package:synlen/src/features/settings/application/update_check.dart';
import 'package:synlen/src/features/settings/domain/update_exception.dart';
import 'package:synlen/src/features/settings/domain/version_manifest.dart';
import 'package:synlen/src/features/settings/presentation/update_install_uri.dart';
import 'package:synlen/src/features/settings/presentation/widgets/settings_info_section.dart';
import 'package:synlen/src/features/settings/presentation/widgets/simple_markdown.dart';

/// 按更新错误码映射用户可读文案；内部细节已在 application 层入日志。
String _updateErrorMessage(AppLocalizations l10n, UpdateErrorCode? code) {
  return switch (code) {
    UpdateErrorCode.noUpdateChannel => l10n.noUpdateChannel,
    UpdateErrorCode.insecureUrl => l10n.updateInsecureUrl,
    UpdateErrorCode.downloadFailed => l10n.downloadFailed,
    UpdateErrorCode.checksumMismatch => l10n.updateChecksumMismatch,
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
      case UpdateDownloadStatus.completed:
        ToastService.showSuccess(l10n.downloadCompleted);
        final apkRelativePath = download.apkRelativePath;
        if (apkRelativePath != null && context.mounted) {
          await _installApk(context, apkRelativePath);
        }
      case UpdateDownloadStatus.failed:
        ToastService.showError(_updateErrorMessage(l10n, download.errorCode));
      case UpdateDownloadStatus.idle || UpdateDownloadStatus.downloading:
        break;
    }
  }

  /// 通过 FileProvider 暴露缓存 APK 并拉起系统安装器。
  ///
  /// 薄壳说明：android_intent_plus 的 canResolveActivity / launch 没有可注入
  /// seam，副作用只是「拉起系统界面」，故与 [UrlLauncher] 同类保留在 UI 侧；
  /// 安装包在缓存内的相对路径由 application 层的下载状态给出。
  Future<void> _installApk(BuildContext context, String apkRelativePath) async {
    final l10n = AppLocalizations.of(context)!;
    final packageInfo = await PackageInfo.fromPlatform();

    final intent = AndroidIntent(
      action: 'android.intent.action.VIEW',
      data: apkContentUri(
        packageName: packageInfo.packageName,
        apkRelativePath: apkRelativePath,
      ),
      type: 'application/vnd.android.package-archive',
      flags: <int>[
        Flag.FLAG_ACTIVITY_NEW_TASK,
        Flag.FLAG_GRANT_READ_URI_PERMISSION,
      ],
    );

    if (await intent.canResolveActivity() != true) {
      ToastService.showError(l10n.downloadFailed);
      return;
    }

    try {
      await intent.launch();
      // 若系统拦截（未允许未知来源），Android 11+ 自带引导对话框
      ToastService.showInfo(l10n.installUnknownSourcesRequired);
    } catch (e) {
      appLogger.e('拉起系统安装器失败', error: e);
      ToastService.showError(l10n.downloadFailed);
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
    final downloading = download.status == UpdateDownloadStatus.downloading;
    final isAndroid = Platform.isAndroid;
    final hasDirectLink = isAndroid && manifest.androidApkUrl.isNotEmpty;
    final hasAppStore = !isAndroid && manifest.iosAppStoreUrl.isNotEmpty;

    return AlertDialog(
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
                Text(
                  '${(download.progress * 100).toStringAsFixed(0)}%',
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
            onPressed: () {
              Navigator.of(context).pop();
              _launchUrl(manifest.iosAppStoreUrl);
            },
            child: Text(l10n.goToAppStore),
          ),
        if (!hasDirectLink && !hasAppStore)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ToastService.showInfo(l10n.noUpdateChannel);
            },
            child: Text(l10n.goToAppStore),
          ),
        if (manifest.lanzouUrl.isNotEmpty)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _openLanzou(context);
            },
            child: Text(l10n.updateViaChinaCloud),
          ),
        if (manifest.githubUrl.isNotEmpty)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _launchUrl(manifest.githubUrl);
            },
            child: Text(l10n.updateViaGithub),
          ),
      ],
    );
  }
}
