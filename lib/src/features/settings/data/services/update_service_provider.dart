import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:synlen/src/core/config/app_info.dart';

import 'update_service.dart';

part 'update_service_provider.g.dart';

/// 提供 [UpdateService] 实例；清单端点见 [AppInfo.versionEndpoint]。
@riverpod
UpdateService updateService(Ref ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
  ref.onDispose(() => dio.close(force: true));
  return UpdateService(
    dio: dio,
    versionEndpoint: AppInfo.versionEndpoint,
    readPackageInfo: PackageInfo.fromPlatform,
    cacheDirectory: getApplicationCacheDirectory,
  );
}
