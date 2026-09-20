import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synlen/src/core/config/app_info.dart';
import 'package:synlen/src/core/providers/shared_preferences_provider.dart';
import 'package:synlen/src/core/storage/app_storage.dart';
import 'package:synlen/src/features/library/application/library_consistency_repair.dart';
import 'package:synlen/src/rust/frb_generated.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'src/app.dart';
import 'package:synlen/src/core/database/app_database.dart';
import 'package:synlen/src/core/database/providers.dart';

Future<void> _registerBundledLicenses() async {
  final licenseText = await rootBundle.loadString(AppInfo.bundledLicenseAsset);
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      AppInfo.originalProjectName,
      AppInfo.originalAuthor,
    ], licenseText);
  });

  // flutter_sound 为 MPL-2.0，其许可与声明需随第三方许可一并展示；
  // 资产文件已含包名、版权与来源说明。
  final flutterSoundLicense = await rootBundle.loadString(
    AppInfo.flutterSoundLicenseAsset,
  );
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(['flutter_sound'], flutterSoundLicense);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _registerBundledLicenses();

  // Initialize Rust FFI runtime (must be called before any Rust API functions)
  await RustLib.init();

  // Initialize app storage paths
  await AppStorage.init();

  // Force portrait orientation for mobile
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Preload shared preferences before building the provider container to avoid delays when
  // the UI first accesses them.
  final prefs = await SharedPreferences.getInstance();

  // 初始化数据库
  final database = AppDatabase();

  // Create provider container
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      appDatabaseProvider.overrideWithValue(database),
    ],
  );

  // 启动一致性修复：清理孤儿 DB 记录；fire-and-forget，不阻塞首屏，
  // 失败只在提供器内部记日志
  container.read(libraryConsistencyRepairProvider.future).ignore();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const SynlenReaderApp(),
    ),
  );
}
