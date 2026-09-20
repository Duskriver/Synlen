# settings

settings 是组合面：唯一允许编排其他 feature `application` 的模块，把跨模块设置集中到一处。本页 owns 设置页的类型、语义与边界；跨 feature 依赖的允许形态见 [architecture.md](../architecture.md#跨-feature-依赖)，决策理由见[组合面决策](../../.agents/notes/implemented/architecture/2026-09-08-composition-surface-cross-feature.md)。

## 职责

- 全局主题：`AppThemeNotifier` 的明暗模式与配色入口。
- 自定义字体：导入、删除与供阅读器选用。
- AI 密钥：DeepSeek 与阿里云 TTS 密钥的读写与连通性检查。
- TTS 音色：当前音色的选择与持久化。
- 缓存清理：一次编排 library 与 learning 两侧的可重建数据清理。
- 备份导出：调 library 的导出用例并交系统分享面板。
- 更新检查：读远端版本清单与本地版本比较。

## 关键类型

| 类型 | 语义 | 位置 |
|---|---|---|
| `SettingsScreen` | 设置页骨架，按小节组合下列 widget | `lib/src/features/settings/presentation/settings_screen.dart` |
| `SettingsAppearanceSection` | 全局主题：明暗模式与配色变体 | `lib/src/features/settings/presentation/widgets/settings_appearance_section.dart` |
| `SettingsTtsVoiceSection` | TTS 音色选择 | `lib/src/features/settings/presentation/widgets/settings_tts_voice_section.dart` |
| `SettingsAiServiceSection` / `ApiKeyDialog` | 两把密钥的配置与连通性检查 | `lib/src/features/settings/presentation/widgets/settings_ai_service_section.dart` |
| `SettingsFontSection` | 自定义字体的导入、删除与选用 | `lib/src/features/settings/presentation/widgets/settings_font_section.dart` |
| `BackupTile` / `CleanCacheTile` / `CheckUpdateTile` | 备份导出、缓存清理与更新检查入口 | `lib/src/features/settings/presentation/widgets/` |
| `SimpleMarkdown` | 设置页信息文本的轻量 Markdown 渲染 | `lib/src/features/settings/presentation/widgets/simple_markdown.dart` |
| `ApiKeyNotifier` / `ApiKeyConfig` | 密钥读写与内存状态，写入串行化 | `lib/src/features/settings/application/api_key_notifier.dart` |
| `apiKeyStorage` | `FlutterSecureStorage` 实例，密钥不落普通偏好存储 | `lib/src/features/settings/data/api_key_storage_provider.dart` |
| `FontManagerNotifier` / `ImportedFont` | 字体导入、删除与列表持久化（`SharedPreferences` 键 `imported_fonts`） | `lib/src/features/settings/application/font_manager_notifier.dart` |
| `importedFontFileNamesProvider` | 已导入字体文件名，供阅读器设置消费 | `lib/src/features/settings/application/imported_font_file_names_provider.dart` |
| `TtsVoiceNotifier` | 当前音色持久化（`SharedPreferences` 键 `tts_voice`） | `lib/src/features/settings/application/tts_voice_notifier.dart` |
| `CacheCleanup` | 组合 library 与 learning 的清理用例，状态携带进度、删除量或失败 | `lib/src/features/settings/application/cache_cleanup.dart` |
| `BackupExport` | 组合 library 的导出用例，只回传错误字符串 | `lib/src/features/settings/application/backup_export.dart` |
| `DeepSeekKeyCheck` / `DeepSeekConnectivity` | 密钥连通性检查状态与结果 | `lib/src/features/settings/application/deep_seek_connectivity.dart` |
| `UpdateCheck` / `UpdateState` | 更新检查与下载的状态流（`AsyncValue`：loading = 检查中，error = `UpdateException`），下载子状态带进度与错误码 | `lib/src/features/settings/application/update_check.dart` |
| `UpdateService` | 读取远端清单与本地版本，校验下载参数并调用 ota_update；平台依赖经构造注入 | `lib/src/features/settings/data/services/update_service.dart` |
| `AppVersion` / `VersionManifest` / `UpdateErrorCode` | 版本值类型、远端清单值类型、更新错误码 | `lib/src/features/settings/domain/` |

## 流程

1. 主题：`SettingsAppearanceSection` → `AppThemeNotifier.setThemeMode` / `setThemeVariant` → `SharedPreferences` + 状态更新。
2. 字体：`SettingsFontSection` → `UnifiedImportService.pickFontFiles` 与 `processFontFile` → `FontManagerNotifier.importFonts` 落到 `fonts/` 并持久化文件名；删除字体时同步移除文件与列表项。
3. 密钥：`SettingsAiServiceSection` → `ApiKeyNotifier.setDeepSeekKey` / `setAliyunTtsKey` → `apiKeyStorage`；连通性检查走 `DeepSeekKeyCheck.check`。
4. 音色：`SettingsTtsVoiceSection` → `TtsVoiceNotifier.setVoice` → 持久化 `voiceParam`，学习模块据此取音色与缓存键。
5. 缓存清理：`CleanCacheTile` → `CacheCleanup.cleanAll` → library 的 `StorageCleanupService`（缓存、孤儿书籍 / 封面、分享文件、孤儿字体）+ learning 的 `LearningCacheCleanupService`。
6. 备份导出：`BackupTile` → `BackupExport.exportToShareSheet` → `ExportBackupService` 压缩并调系统分享面板。
7. 更新检查：`CheckUpdateTile` → `UpdateCheck.checkForUpdates` → `UpdateService` 获取 `version.json` 并比较本地版本。有更新时显示版本与日志；Android 经 `ota_update` 下载、校验并拉起系统安装器，iOS 跳转清单中的 App Store 链接，备用链接交外部浏览器。

## 边界与不变量

- 组合面是唯一允许依赖其他 feature `application` / `data` 的模块；新增组合面必须先改决策记录。
- 密钥只进 `FlutterSecureStorage`，不入源码、构建配置或 `SharedPreferences`。
- `ApiKeyNotifier` 的写入串行化，避免并发覆盖。
- 字体文件名是 `ReaderSettings.fontFileName` 的取值来源；删除字体必须同时清掉该引用。
- 缓存清理只删可重建数据，不动图书与阅读进度。
- 更新直链必须是 HTTPS，摘要必须是 64 位 SHA-256；插件校验失败后删除坏包。APK 位于私有 `files/ota_update/`，使用固定文件名，重试重新下载。
- 更新下载期间禁止替换清单或直接关闭弹窗；取消回执确认原生写入与校验结束后才关闭；取消期间保留终态，取消通道失败后按终态恢复可关闭、可重试的界面。Provider 释放时取消下载，迟到事件不写状态。`installerOpened` 仅表示已拉起系统安装器，不表示安装成功。
- 下载前原子记录目标版本和摘要；Android 启动时先回收再开放更新入口。本地版本达到目标时删除包与记录，否则只删摘要不符的残留，保留完整待安装包；无记录的旧包保守保留。取消和下载失败的残留在启动时回收，清理失败保留记录供下次重试。
- 缓存清理与密钥检查由页面订阅用例，用例订阅服务以覆盖异步等待；退出后释放依赖且忽略迟到结果。清理退出后不启动后续阶段，失败可重试，已删除项不回滚。
- 阅读器自身的样式面板（字号、边距、翻页动画等）归 [reader.md](reader.md)；settings 只提供其消费的字体列表与全局主题。

## 已知限制与待办

- 设置模块的测试覆盖 AI 密钥、连通性、缓存清理、TTS 音色、更新检查与字体导入（`test/features/settings/`）；主题与备份导出仍缺覆盖（[测试分层](../testing.md#分层)）。

## Dev Note

None.
