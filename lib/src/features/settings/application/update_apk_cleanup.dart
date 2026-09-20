import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:synlen/src/core/services/app_logger.dart';
import 'package:synlen/src/features/settings/data/services/update_service_provider.dart';

part 'update_apk_cleanup.g.dart';

/// Android 启动时回收安装包；失败保留记录供下次启动重试，不阻断使用。
@riverpod
Future<bool> updateApkCleanup(Ref ref) async {
  final service = ref.watch(updateServiceProvider);
  try {
    await service.cleanupDownloadedApk();
    return true;
  } catch (e, st) {
    appLogger.e('启动时回收安装包失败', error: e, stackTrace: st);
    return false;
  }
}
