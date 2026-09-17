import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:synlen/src/core/services/app_logger.dart';
import 'package:synlen/src/features/settings/data/services/update_service_provider.dart';
import 'package:synlen/src/features/settings/domain/update_exception.dart';
import 'package:synlen/src/features/settings/domain/version_manifest.dart';

part 'update_check.g.dart';

/// 更新检查阶段。
enum UpdateCheckStatus {
  /// 尚未检查
  idle,

  /// 已是最新版本
  upToDate,

  /// 有新版本（清单见 [UpdateState.manifest]）
  updateAvailable,
}

/// APK 下载阶段。
enum UpdateDownloadStatus { idle, downloading, completed, failed }

/// 下载子状态：进度、产物路径与失败错误码。
class UpdateDownloadState {
  const UpdateDownloadState({
    this.status = UpdateDownloadStatus.idle,
    this.progress = 0,
    this.apkPath,
    this.errorCode,
  });

  final UpdateDownloadStatus status;

  /// 下载进度 0..1（[UpdateDownloadStatus.downloading] 时有效）
  final double progress;

  /// 下载完成并通过校验后的安装包路径
  final String? apkPath;

  /// 失败的类型化错误码，presentation 据此映射 l10n
  final UpdateErrorCode? errorCode;
}

/// 更新流程状态：检查结果 + 下载子状态。
class UpdateState {
  const UpdateState({
    this.checkStatus = UpdateCheckStatus.idle,
    this.manifest,
    this.download = const UpdateDownloadState(),
  });

  final UpdateCheckStatus checkStatus;

  /// 有新版本时的远端清单（供更新对话框渲染）
  final VersionManifest? manifest;

  final UpdateDownloadState download;

  UpdateState copyWith({UpdateDownloadState? download}) {
    return UpdateState(
      checkStatus: checkStatus,
      manifest: manifest,
      download: download ?? this.download,
    );
  }
}

/// 更新检查与下载用例：拉取清单、与本地版本比较、下载并校验 APK。
///
/// 错误在此捕获并转成类型化状态（[UpdateErrorCode]），用户可读文案由
/// presentation 按错误码映射 l10n，内部细节只入日志。
@riverpod
class UpdateCheck extends _$UpdateCheck {
  @override
  AsyncValue<UpdateState> build() {
    // 检查与下载跨越异步等待，必须订阅服务以免 Dio 提前关闭。
    ref.watch(updateServiceProvider);
    return const AsyncValue.data(UpdateState());
  }

  /// 拉取远端清单并与本地版本比较。
  ///
  /// 检查阶段占满整个 [AsyncValue]：loading = 检查中，error = [UpdateException]，
  /// data 携带检查结果。
  Future<void> checkForUpdates() async {
    if (state.isLoading) return;
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
    } on UpdateException catch (e, st) {
      if (!ref.mounted) return;
      appLogger.w('更新检查失败（${e.code.name}）: ${e.details}');
      state = AsyncValue.error(e, st);
    } catch (e, st) {
      if (!ref.mounted) return;
      appLogger.e('更新检查失败', error: e, stackTrace: st);
      state = AsyncValue.error(
        UpdateException(UpdateErrorCode.checkFailed, e),
        st,
      );
    }
  }

  /// 下载当前清单的 APK 并校验；结果写入 [UpdateState.download]。
  ///
  /// 安装本身（FileProvider / Intent）依赖平台插件，由 presentation 薄壳完成。
  Future<void> downloadAndInstall() async {
    final current = state.asData?.value;
    final manifest = current?.manifest;
    if (current == null || manifest == null) return;
    if (current.download.status == UpdateDownloadStatus.downloading) return;

    void emit(UpdateDownloadState download) {
      if (!ref.mounted) return;
      final s = state.asData?.value;
      if (s != null && identical(s.manifest, manifest)) {
        state = AsyncValue.data(s.copyWith(download: download));
      }
    }

    emit(const UpdateDownloadState(status: UpdateDownloadStatus.downloading));
    try {
      final path = await ref
          .read(updateServiceProvider)
          .downloadApk(
            manifest: manifest,
            onProgress: (progress) => emit(
              UpdateDownloadState(
                status: UpdateDownloadStatus.downloading,
                progress: progress,
              ),
            ),
          );
      emit(
        UpdateDownloadState(
          status: UpdateDownloadStatus.completed,
          progress: 1,
          apkPath: path,
        ),
      );
    } on UpdateException catch (e) {
      if (!ref.mounted) return;
      appLogger.w('更新包下载失败（${e.code.name}）: ${e.details}');
      emit(
        UpdateDownloadState(
          status: UpdateDownloadStatus.failed,
          errorCode: e.code,
        ),
      );
    } catch (e, st) {
      if (!ref.mounted) return;
      appLogger.e('更新包下载失败', error: e, stackTrace: st);
      emit(
        const UpdateDownloadState(
          status: UpdateDownloadStatus.failed,
          errorCode: UpdateErrorCode.downloadFailed,
        ),
      );
    }
  }
}
