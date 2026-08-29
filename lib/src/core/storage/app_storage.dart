import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class AppStorage {
  AppStorage._();

  static late String _documentsPath;
  static late String _tempPath;
  static late String _supportPath;

  /// Path to the app's documents directory, where books and covers are stored.
  /// Always ends with a slash.
  static String get documentsPath => _documentsPath;

  /// Path to the app's temporary directory, where transient files can be stored.
  /// Always ends with a slash.
  static String get tempPath => _tempPath;

  /// Path to the app's support directory, where auxiliary files can be stored.
  /// Always ends with a slash.
  static String get supportPath => _supportPath;

  static Future<void> init() async {
    final docDir = await getApplicationDocumentsDirectory();
    _documentsPath = docDir.path;
    if (!_documentsPath.endsWith('/')) {
      _documentsPath += '/';
    }

    final tempDir = await getTemporaryDirectory();
    _tempPath = tempDir.path;
    if (!_tempPath.endsWith('/')) {
      _tempPath += '/';
    }

    final supportDir = await getApplicationSupportDirectory();
    _supportPath = supportDir.path;
    if (!_supportPath.endsWith('/')) {
      _supportPath += '/';
    }
  }

  /// 仅供测试：跳过 path_provider 直接指定目录，语义与 [init] 一致。
  ///
  /// 导入服务等组件以 `documentsPath` 为根落盘，集成测试用临时目录
  /// 指入，避免触碰真实应用存储（同 [AppDatabase.forTesting] 的做法）。
  @visibleForTesting
  static void initForTesting({
    required String documentsPath,
    String? tempPath,
    String? supportPath,
  }) {
    String normalize(String path) => path.endsWith('/') ? path : '$path/';
    _documentsPath = normalize(documentsPath);
    _tempPath = normalize(tempPath ?? documentsPath);
    _supportPath = normalize(supportPath ?? documentsPath);
  }
}
