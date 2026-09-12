import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:synlen/src/core/file_handling/file_handling.dart';

part 'unified_import_service_provider.g.dart';

/// 统一导入服务的 provider：跨 Android SAF / iOS 文件系统提供同一套选书与入缓存接口。
///
/// 能力：多选文件、选文件夹递归扫描、把选中文件转成带哈希的 ImportableEpub。
/// 该服务被 library、settings 与分享入口共同消费，因此 provider 落在 core/providers。
@riverpod
UnifiedImportService unifiedImportService(Ref ref) {
  return UnifiedImportService();
}
