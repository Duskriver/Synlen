import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synlen/src/core/config/app_info.dart';
import 'package:synlen/src/core/services/app_logger.dart';
import 'package:synlen/src/core/providers/shared_preferences_provider.dart';
import 'package:synlen/src/core/storage/app_storage.dart';
import 'package:synlen/src/features/reader/data/services/epub_stream_service_provider.dart';
import 'package:synlen/src/features/reader/presentation/reader_webview.dart';
import 'package:synlen/src/rust/frb_generated.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'src/app.dart';
import 'package:synlen/src/core/database/app_database.dart';
import 'package:synlen/src/core/database/providers.dart';

HeadlessInAppWebView? headlessWebView;

void _preWarmWebView() async {
  headlessWebView = HeadlessInAppWebView(
    initialSettings: defaultSettings,
    onWebViewCreated: (controller) {
      appLogger.i("WebView Engine Warmed Up!");
    },
  );
  await headlessWebView?.run();
}

Future<void> _registerBundledLicenses() async {
  final licenseText = await rootBundle.loadString(AppInfo.bundledLicenseAsset);
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      AppInfo.originalProjectName,
      AppInfo.originalAuthor,
    ], licenseText);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _registerBundledLicenses();

  // Initialize Rust FFI runtime (must be called before any Rust API functions)
  await RustLib.init();

  // Initialize app storage paths
  await AppStorage.init();

  // Pre-warm the WebView engine to reduce first load latency
  _preWarmWebView();

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
  container.read(epubStreamServiceProvider);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const SynlenReaderApp(),
    ),
  );
}
