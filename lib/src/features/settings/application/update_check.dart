import 'dart:async';

import 'package:ota_update/ota_update.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:synlen/src/core/services/app_logger.dart';
import 'package:synlen/src/features/settings/data/services/update_service.dart';
import 'package:synlen/src/features/settings/data/services/update_service_provider.dart';
import 'package:synlen/src/features/settings/domain/update_exception.dart';
import 'package:synlen/src/features/settings/domain/version_manifest.dart';

part 'update_check.g.dart';

/// 更新检查阶段。
enum UpdateCheckStatus { idle, upToDate, updateAvailable }

/// installerOpened 只表示已拉起系统安装器，不代表安装成功。
enum UpdateDownloadStatus {
  idle,
  downloading,
  canceling,
  installerOpened,
  canceled,
  failed,
}

class UpdateDownloadState {
  const UpdateDownloadState({
    this.status = UpdateDownloadStatus.idle,
    this.progress,
    this.errorCode,
  });

  final UpdateDownloadStatus status;

  /// 0..1；总长度未知时为 null，UI 显示不定进度。
  final double? progress;
  final UpdateErrorCode? errorCode;

  bool get isBusy =>
      status == UpdateDownloadStatus.downloading ||
      status == UpdateDownloadStatus.canceling;
}

/// 下载失败保留版本清单，允许在同一弹窗里重试。
class UpdateState {
  const UpdateState({
    this.checkStatus = UpdateCheckStatus.idle,
    this.manifest,
    this.download = const UpdateDownloadState(),
  });

  final UpdateCheckStatus checkStatus;
  final VersionManifest? manifest;
  final UpdateDownloadState download;

  UpdateState copyWith({UpdateDownloadState? download}) => UpdateState(
    checkStatus: checkStatus,
    manifest: manifest,
    download: download ?? this.download,
  );
}

/// 更新检查与安装用例；插件事件和异常只在此转成类型化状态。
@riverpod
class UpdateCheck extends _$UpdateCheck {
  StreamIterator<OtaEvent>? _events;
  Future<void>? _canceling;

  @override
  AsyncValue<UpdateState> build() {
    final service = ref.watch(updateServiceProvider);
    ref.onDispose(() {
      final events = _events;
      if (events != null && _canceling == null) {
        unawaited(_cancel(service, events));
      }
    });
    return const AsyncValue.data(UpdateState());
  }

  /// 检查期间使用 AsyncValue 三态；下载期间不允许替换清单。
  Future<void> checkForUpdates() async {
    if (state.isLoading || _events != null || _canceling != null) return;
    state = const AsyncValue.loading();
    try {
      final service = ref.read(updateServiceProvider);
      final manifest = await service.fetchManifest();
      final local = await service.localVersion();
      if (!ref.mounted) return;
      state = AsyncValue.data(
        manifest.version.isNewerThan(local)
            ? UpdateState(
                checkStatus: UpdateCheckStatus.updateAvailable,
                manifest: manifest,
              )
            : const UpdateState(checkStatus: UpdateCheckStatus.upToDate),
      );
    } catch (e, st) {
      if (!ref.mounted) return;
      appLogger.e('更新检查失败', error: e, stackTrace: st);
      state = AsyncValue.error(
        e is UpdateException
            ? e
            : UpdateException(UpdateErrorCode.checkFailed, e),
        st,
      );
    }
  }

  Future<void> downloadAndInstall() async {
    final current = state.asData?.value;
    final manifest = current?.manifest;
    if (manifest == null || _events != null || _canceling != null) return;
    final service = ref.read(updateServiceProvider);
    _emit(const UpdateDownloadState(status: UpdateDownloadStatus.downloading));
    StreamIterator<OtaEvent>? events;
    try {
      events = StreamIterator(service.downloadAndInstall(manifest));
      _events = events;
      while (await events.moveNext()) {
        if (!ref.mounted) break;
        if (_canceling != null) continue;
        final event = events.current;
        switch (event.status) {
          case OtaStatus.DOWNLOADING:
            final percent = double.tryParse(event.value ?? '');
            _emit(
              UpdateDownloadState(
                status: UpdateDownloadStatus.downloading,
                progress: percent != null && percent.isFinite
                    ? (percent / 100).clamp(0, 1)
                    : null,
              ),
            );
          case OtaStatus.INSTALLING || OtaStatus.INSTALLATION_DONE:
            _emit(
              const UpdateDownloadState(
                status: UpdateDownloadStatus.installerOpened,
                progress: 1,
              ),
            );
          case OtaStatus.CANCELED:
            _emit(
              const UpdateDownloadState(status: UpdateDownloadStatus.canceled),
            );
          case OtaStatus.CHECKSUM_ERROR:
            try {
              await service.deleteDownloadedApk();
            } catch (e, st) {
              // 清理失败保留记录供启动时重试，不覆盖原始校验错误。
              appLogger.e('清理校验失败的安装包失败', error: e, stackTrace: st);
            }
            throw UpdateException(
              UpdateErrorCode.checksumMismatch,
              event.value,
            );
          case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
            throw UpdateException(
              UpdateErrorCode.installPermissionDenied,
              event.value,
            );
          // 7.1.0 的 Dart 与 Java 把这两个枚举次序对调，统一按安装失败处理。
          case OtaStatus.ALREADY_RUNNING_ERROR || OtaStatus.INSTALLATION_ERROR:
            throw UpdateException(UpdateErrorCode.installFailed, event.value);
          case OtaStatus.INTERNAL_ERROR || OtaStatus.DOWNLOAD_ERROR:
            throw UpdateException(UpdateErrorCode.downloadFailed, event.value);
        }
      }
      if (ref.mounted &&
          _canceling == null &&
          state.asData?.value.download.status ==
              UpdateDownloadStatus.downloading) {
        throw const UpdateException(
          UpdateErrorCode.downloadFailed,
          '插件流结束但未拉起安装器',
        );
      }
    } catch (e, st) {
      if (ref.mounted && _canceling == null) {
        appLogger.e('更新下载安装失败', error: e, stackTrace: st);
        _emit(
          UpdateDownloadState(
            status: UpdateDownloadStatus.failed,
            errorCode: e is UpdateException
                ? e.code
                : UpdateErrorCode.downloadFailed,
          ),
        );
      }
    } finally {
      await events?.cancel();
      if (identical(_events, events)) _events = null;
    }
  }

  /// 取消原生下载后才允许关闭弹窗或重试。
  Future<void> cancelDownload() {
    final pending = _canceling;
    if (pending != null) return pending;
    final events = _events;
    if (events == null) return Future.value();
    _emit(const UpdateDownloadState(status: UpdateDownloadStatus.canceling));
    return _canceling = _cancel(
      ref.read(updateServiceProvider),
      events,
    ).whenComplete(() => _canceling = null);
  }

  Future<void> _cancel(
    UpdateService service,
    StreamIterator<OtaEvent> events,
  ) async {
    try {
      await service.cancelDownload();
      await events.cancel();
      if (identical(_events, events)) _events = null;
      _emit(const UpdateDownloadState(status: UpdateDownloadStatus.canceled));
    } catch (e, st) {
      appLogger.e('取消更新下载失败', error: e, stackTrace: st);
      if (!ref.mounted) {
        await events.cancel();
        return;
      }
      // 取消未确认时保留下载状态，不能让 UI 关闭后原生继续安装。
      _emit(
        const UpdateDownloadState(status: UpdateDownloadStatus.downloading),
      );
    }
  }

  void _emit(UpdateDownloadState download) {
    if (!ref.mounted) return;
    final current = state.asData?.value;
    if (current != null) {
      state = AsyncValue.data(current.copyWith(download: download));
    }
  }
}
