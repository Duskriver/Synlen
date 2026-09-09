# core

`lib/src/core/` 是跨模块共享工具箱：被 ≥2 个 feature 使用的能力才下沉到这里。本页 owns 这些类型、语义与边界；分层与依赖方向见 [architecture.md](../architecture.md#分层)。

## 职责

- 数据库：drift 单库 `AppDatabase`，藏书与学习缓存共 7 张表，schema 迁移集中在此。
- 路由：`appRouterProvider` 用 go_router 定义页面路由，并把系统转来的文件位置交给导入流程。
- 主题：全局 `AppThemeSettings`、`SynlenThemePreset`、`ColorScheme` 常量与 `AppThemeNotifier`。
- 存储：`AppStorage` 提供 documents / temp / support 绝对路径，`AppStorageConstants` 定义磁盘布局。
- 服务：`appLogger` 与 `ToastService` 是日志与提示的唯一出口。
- provider：数据库、`SharedPreferences`、导入服务与封面文件的注入点。
- 文件处理：跨 Android SAF / iOS 文件系统的选择、缓存与哈希。
- 外链与配置：`UrlLauncher`、`AppInfo`。

## 关键类型

| 类型 | 语义 | 位置 |
|---|---|---|
| `AppDatabase` | drift 数据库入口，`schemaVersion` 为 2；`AppDatabase.forTesting` 注入测试执行器 | `lib/src/core/database/app_database.dart` |
| `ShelfGroups` / `ShelfBooks` / `BookManifests` | 藏书与阅读清单表；`ShelfBooks` 与 `BookManifests` 的 `format` 列默认 `epub`，v1 存量数据经迁移补列 | 同上 |
| `WordExplanations` / `WordPronunciations` / `SentenceAnalyses` / `SentencePronunciations` | 学习缓存表，主键为 FNV-1a 64 位确定性哈希 | 同上 |
| `kLearningTextPromptVersion` | 学习文本缓存的 prompt 版本；改 LLM 输出契约时递增，使旧缓存自然失效 | 同上 |
| `AppTheme` | `ThemeData` 构建（Material 3、无阴影、无 splash）与动画时长常量 | `lib/src/core/theme/app_theme.dart` |
| `AppThemeSettings` | 全局主题值对象：`AppThemeMode` + `AppThemeVariant`，派生明暗 `ColorScheme` 与 `ThemeData` | `lib/src/core/theme/app_theme_settings.dart` |
| `SynlenThemePreset` | 16 个主题预设（8 变体 × 明暗）；枚举声明顺序即持久化索引，不得重排或删除 | 同上 |
| `AppThemeNotifier` | 全局主题持久化与修改（`SharedPreferences` 键 `app_theme_mode` / `app_theme_variant`） | `lib/src/core/theme/app_theme_notifier.dart` |
| `kLightColorScheme` 等 16 个常量 | 各主题变体的 `ColorScheme`，由 `SynlenThemePreset` 引用 | `lib/src/core/theme/color_schemes.dart` |
| `AppStorage` | documents / temp / support 目录绝对路径，始终以 `/` 结尾 | `lib/src/core/storage/app_storage.dart` |
| `AppStorageConstants` | 磁盘布局常量：`books`、`covers`、`manifests`、`fonts`、`shelf.json` | `lib/src/core/storage/app_storage_constants.dart` |
| `appLogger` | 全局 `Logger` 实例，日志唯一出口 | `lib/src/core/services/app_logger.dart` |
| `ToastService` | 基于 overlay 的提示，并持有 `navigatorKey` 供跨页面弹窗使用 | `lib/src/core/services/toast_service.dart` |
| `UnifiedImportService` | 导入门面：缓存与哈希、备份 ZIP 解压、字体缓存；选择器调用委托 `NativeFilePicker` | `lib/src/core/file_handling/unified_import_service.dart` |
| `NativeFilePicker` | 平台选择器适配：MethodChannel 调用与 Android SAF / iOS UIDocumentPicker 分支 | `lib/src/core/file_handling/native_file_picker.dart` |
| `ImportCacheManager` | 导入缓存目录与 SHA-256 哈希（`createCacheAndHash` / `createRawCacheFile` / `clearAll`） | `lib/src/core/file_handling/import_cache_manager.dart` |
| `PlatformPath` / `AndroidUriPath` / `IOSFilePath` | 平台路径抽象：Android 用 SAF `content://`，iOS 用文件系统路径 | `lib/src/core/file_handling/platform_path.dart` |
| `ImportableEpub` | 缓存文件 + 哈希 + 原始文件名 | `lib/src/core/file_handling/importable_epub.dart` |
| `BackupPaths` / `BackupPathsForBook` / `classifyBackupEntries` / `buildBackupBookPaths` | 备份根目录、`shelf.json` 与按哈希索引的书 / 清单 / 封面路径；分桶与装配是纯函数 | `lib/src/core/file_handling/backup_paths.dart` |
| `validateBackupArchiveEntries` / `BackupArchiveViolation` | 备份 ZIP 解压前校验：条目数 ≤ 10000、单条目 ≤ 512 MiB、总量 ≤ 4 GiB、拒绝绝对路径与 `..`；纯函数 | `lib/src/core/file_handling/backup_archive_guard.dart` |
| `UrlLauncher` | 用系统外部应用打开 URL | `lib/src/core/url_launcher/url_launcher.dart` |
| `AppInfo` | 应用名、作者、版本检查端点与许可资源路径 | `lib/src/core/config/app_info.dart` |

## 流程

1. 选书：`UnifiedImportService.pickFiles` / `pickFolder` 经 MethodChannel `com.tanglei.synlen/native_picker` 取平台路径，`processEpub` 落缓存并算哈希；Android 的 SAF 数字文档 ID 另查 `getDisplayName` 兜底文件名。
2. 备份恢复：`pickBackupZipFile` + `processBackupZip` 把 ZIP 流式解压到导入缓存区，`_classifyBackupFiles` 分桶为 `BackupPaths`；解压前先经 `validateBackupArchiveEntries` 静态校验，违规抛 `BackupArchiveViolationException` 中止恢复。文件夹来源走 `pickBackupFolder`。
3. 主题：`AppThemeNotifier` 读写 `SharedPreferences`，`AppThemeSettings` 映射为 `ThemeData`，`SynlenThemeExtension` 把当前预设注入 widget 树。
4. 数据库：`appDatabaseProvider` 为 keepAlive，迁移在 `migration.onUpgrade` 内按版本号追加列。

## 边界与不变量

- `core/` 只放被 ≥2 个 feature 使用的能力；单 feature 专用留在所属 feature。
- `sharedPreferencesProvider` 必须在 `main.dart` 用 `overrideWithValue` 注入，否则抛 `UnimplementedError`。
- `AppStorage` 路径以 `/` 结尾，调用方直接拼接 `${AppStorage.documentsPath}$relativePath`。
- `SynlenThemePreset` 的枚举顺序是持久化契约，只能追加。
- iOS 选取文件后必须调 `releaseIosAccess`，否则安全作用域泄漏。
- `ImportCacheManager` 的缓存目录是 `AppStorage.tempPath` 下的 `import_cache`，不随书籍长期保留。

## 已知限制与待办

- `avoid_print` 只拦 `print`，不覆盖 `debugPrint`；要让 CI 拦住 `debugPrint`，需引入 `custom_lint` 自定义规则。
- 打开方式与分享进入的注册和接收不对称：`android/app/src/main/AndroidManifest.xml` 的 `ACTION_VIEW` / `ACTION_SEND` 与 `ios/Runner/Info.plist` 的 `CFBundleDocumentTypes` 都已注册，Dart 侧只有 `lib/src/global_share_handler.dart` 的 `GlobalShareHandler` 经路由重定向把 `content://` / `file://` 转入导入；`MainActivity` 没有 `onNewIntent`，也不读取 `Intent.EXTRA_STREAM`，分享进入没有接收路径。
- 修复方向：接入 intent 接收（如 `receive_sharing_intent` / `app_links`），把 content URI 交给 `importPipelineStream`，并在真机验证 SAF 权限与时序。
- 超 400 行的 core 文件：`color_schemes.dart`。复现：

```sh
find lib/src/core -name '*.dart' ! -name '*.g.dart' -exec wc -l {} + | sort -rn | head
```

- 旧模块注释仍有英文；按 Boy Scout Rule 路过即译，不做一次性批量翻译（[注释与文档语言](../development.md#注释与文档语言)）。

## Dev Note

None.
