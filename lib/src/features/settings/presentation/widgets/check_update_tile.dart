import 'dart:convert';
import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:synlen/l10n/app_localizations.dart';
import 'package:synlen/src/core/config/app_info.dart';
import 'package:synlen/src/core/services/toast_service.dart';
import 'package:synlen/src/core/url_launcher/url_launcher.dart';
import 'package:synlen/src/features/settings/presentation/widgets/settings_info_section.dart';
import 'package:synlen/src/features/settings/presentation/widgets/simple_markdown.dart';

/// Settings tile that checks for application updates from the remote server.
class CheckUpdateTile extends StatefulWidget {
  const CheckUpdateTile({super.key});

  @override
  State<CheckUpdateTile> createState() => _CheckUpdateTileState();
}

class _CheckUpdateTileState extends State<CheckUpdateTile> {
  bool _isChecking = false;

  Future<void> _checkForUpdates() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);

    final l10n = AppLocalizations.of(context)!;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final localVersionStr = packageInfo.version; // e.g. "0.2.2"
      final localBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

      // Split APKs (arm64, armeabi-v7a, x86_64) have an architecture offset
      // added to the base build number (e.g. 1001, 1002, 1003 for build 1).
      // Normalise by taking the remainder of 1000.
      final normalizedBuildNumber = localBuildNumber % 1000;

      final httpClient = HttpClient();
      httpClient.connectionTimeout = const Duration(seconds: 10);
      final request = await httpClient.getUrl(
        Uri.parse(AppInfo.versionEndpoint),
      );
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      httpClient.close();

      final jsonMap = jsonDecode(body) as Map<String, dynamic>;
      if (jsonMap['code'] != 200) {
        throw Exception('Server returned code ${jsonMap['code']}');
      }

      final data = jsonMap['data'] as Map<String, dynamic>;
      final remoteMajor = (data['majorNumber'] as num).toInt();
      final remoteMinor = (data['minorNumber'] as num).toInt();
      final remotePatch = (data['patchNumber'] as num).toInt();
      final remoteBuild = (data['buildNumber'] as num).toInt();
      final updateLog = data['updateLog'] as String? ?? '';
      final lanzouUrl = data['lanzouUrl'] as String? ?? '';
      final lanzouPassword = data['lanzouPassword'] as String? ?? '';
      final githubUrl = data['githubUrl'] as String? ?? '';
      final androidApkUrl = data['androidApkUrl'] as String? ?? '';
      final iosAppStoreUrl = data['iosAppStoreUrl'] as String? ?? '';

      final remoteVersionStr = '$remoteMajor.$remoteMinor.$remotePatch';

      // Parse local version string
      final localParts = localVersionStr
          .split('.')
          .map((e) => int.tryParse(e) ?? 0)
          .toList();
      final localMajor = localParts.isNotEmpty ? localParts[0] : 0;
      final localMinor = localParts.length > 1 ? localParts[1] : 0;
      final localPatch = localParts.length > 2 ? localParts[2] : 0;

      final isNewer = _isNewerVersion(
        remoteMajor,
        remoteMinor,
        remotePatch,
        remoteBuild,
        localMajor,
        localMinor,
        localPatch,
        normalizedBuildNumber,
      );

      if (!mounted) return;

      if (!isNewer) {
        ToastService.showSuccess(l10n.upToDate);
        return;
      }

      await showDialog(
        context: context,
        builder: (context) => _UpdateDialog(
          remoteVersion: 'v$remoteVersionStr+$remoteBuild',
          updateLog: updateLog,
          lanzouUrl: lanzouUrl,
          lanzouPassword: lanzouPassword,
          githubUrl: githubUrl,
          androidApkUrl: androidApkUrl,
          iosAppStoreUrl: iosAppStoreUrl,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      final l10n2 = AppLocalizations.of(context)!;
      ToastService.showError(l10n2.updateCheckFailed);
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  bool _isNewerVersion(
    int rMaj,
    int rMin,
    int rPat,
    int rBuild,
    int lMaj,
    int lMin,
    int lPat,
    int lBuild,
  ) {
    if (rMaj != lMaj) return rMaj > lMaj;
    if (rMin != lMin) return rMin > lMin;
    if (rPat != lPat) return rPat > lPat;
    return rBuild > lBuild;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SettingsInfoTile(
      icon: Icons.system_update_outlined,
      title: l10n.checkForUpdates,
      subtitle: l10n.checkForUpdatesSubtitle,
      trailing: _isChecking
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      onTap: _isChecking ? null : _checkForUpdates,
    );
  }
}

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({
    required this.remoteVersion,
    required this.updateLog,
    required this.lanzouUrl,
    required this.lanzouPassword,
    required this.githubUrl,
    required this.androidApkUrl,
    required this.iosAppStoreUrl,
  });

  final String remoteVersion;
  final String updateLog;
  final String lanzouUrl;
  final String lanzouPassword;
  final String githubUrl;

  /// Android：APK 直链（国内 OSS 分发）
  final String androidApkUrl;

  /// iOS：App Store 链接（上架后由服务端下发）
  final String iosAppStoreUrl;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _downloading = false;
  double _downloadProgress = 0;

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await UrlLauncher.canLaunch(uri)) {
      await UrlLauncher.launch(uri);
    }
  }

  Future<void> _openLanzou(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    if (widget.lanzouPassword.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: widget.lanzouPassword));
      ToastService.showSuccess(l10n.passwordCopied);
    }
    await _launchUrl(widget.lanzouUrl);
  }

  /// Android：下载 APK 到应用缓存目录，再用 FileProvider 触发系统安装
  Future<void> _downloadAndInstall(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    if (widget.androidApkUrl.isEmpty) {
      ToastService.showInfo(l10n.noUpdateChannel);
      return;
    }

    setState(() {
      _downloading = true;
      _downloadProgress = 0;
    });

    try {
      final cacheDir = await getApplicationCacheDirectory();
      final apkDir = Directory('${cacheDir.path}/apk');
      await apkDir.create(recursive: true);
      final apkPath = '${apkDir.path}/synlen-${widget.remoteVersion}.apk';
      // 删除可能存在的旧文件，避免覆盖安装校验失败
      final oldFile = File(apkPath);
      if (oldFile.existsSync()) {
        oldFile.deleteSync();
      }

      await Dio().download(
        widget.androidApkUrl,
        apkPath,
        onReceiveProgress: (received, total) {
          if (total > 0 && mounted) {
            setState(() => _downloadProgress = received / total);
          }
        },
      );

      if (!context.mounted) return;
      ToastService.showSuccess(l10n.downloadCompleted);
      await _installApk(context, apkPath);
    } catch (e) {
      if (!mounted) return;
      ToastService.showError('${l10n.downloadFailed}: $e');
    } finally {
      if (mounted) {
        setState(() => _downloading = false);
      }
    }
  }

  /// 通过 FileProvider 暴露缓存 APK 并拉起系统安装器
  Future<void> _installApk(BuildContext context, String apkPath) async {
    final l10n = AppLocalizations.of(context)!;
    final packageInfo = await PackageInfo.fromPlatform();
    final authority = '${packageInfo.packageName}.fileprovider';
    final fileName = File(apkPath).uri.pathSegments.last;
    final contentUri = 'content://$authority/apk_cache/$fileName';

    final intent = AndroidIntent(
      action: 'android.intent.action.VIEW',
      data: contentUri,
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
      ToastService.showError('${l10n.downloadFailed}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAndroid = Platform.isAndroid;
    final hasDirectLink = isAndroid && widget.androidApkUrl.isNotEmpty;
    final hasAppStore = !isAndroid && widget.iosAppStoreUrl.isNotEmpty;

    return AlertDialog(
      title: Text(l10n.newVersionAvailable),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.remoteVersion,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SimpleMarkdown(text: widget.updateLog),
              if (_downloading) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(value: _downloadProgress),
                const SizedBox(height: 8),
                Text(
                  '${(_downloadProgress * 100).toStringAsFixed(0)}%',
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
            onPressed: _downloading ? null : () => _downloadAndInstall(context),
            child: Text(l10n.downloadAndInstall),
          ),
        if (hasAppStore)
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _launchUrl(widget.iosAppStoreUrl);
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
        if (widget.lanzouUrl.isNotEmpty)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _openLanzou(context);
            },
            child: Text(l10n.updateViaChinaCloud),
          ),
        if (widget.githubUrl.isNotEmpty)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _launchUrl(widget.githubUrl);
            },
            child: Text(l10n.updateViaGithub),
          ),
      ],
    );
  }
}
