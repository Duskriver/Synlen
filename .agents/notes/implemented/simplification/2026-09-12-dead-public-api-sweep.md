# Agent Note: 死 public API 批量清理

Status: implemented

## Problem

`lib/` 有一批 public API 没有生产调用方。这里的"调用方"只统计 `lib/` 内的生产代码；仅命中 `test/`、`docs/`、codegen 产物（`.g.dart`、mockito 生成的 mocks）不算生产调用方。

## Decision

逐项删除以下 6 个无生产调用方的 public API：

- 删 `importCacheManagerProvider`（原 `lib/src/core/providers/unified_import_service_provider.dart:16`）。`ImportCacheManager` 类本身保留：`lib/src/core/file_handling/unified_import_service.dart:40` 与 `lib/src/core/file_handling/storage_cleanup_service.dart:82` 直接 new，死的只是这层 provider 包装。
- 删 `BookWebViewHandler.getFontUrl`（`lib/src/features/reader/application/book_webview_handler.dart:351`），同步删 `test/features/reader/application/book_webview_handler_test.dart:35-37` 的对应测试。原有虚拟域字体供给后续由 [Readium 引擎决策](../../implemented/architecture/2026-09-20-readium-reader-engine.md)替代，字体由 `ReadiumLayout` 转为原生注册参数。
- 删 `FreeDictionaryService.getWordEntries`（原 `lib/src/features/learning/data/services/free_dictionary_service.dart:60`），保留生产使用的发音能力；当前 `getPronunciationAudio` 由 `WordRepository` 调用。发音获取接口由[词卡反馈与直连发音](../bug-fix/2026-09-20-word-popover-feedback-and-pronunciation.md)取代，未使用的词典正文接口仍不保留。
- 删公开的 `LibraryActionsMixin.importPaths`（`lib/src/features/library/presentation/mixins/library_actions_mixin.dart:75`），保留私有 `_importPaths`；`handleScanFolder` 与 `handleImportFiles` 走私有版。
- 删 `AppThemeSettings.presetFor` 与 `AppThemeSettings.resolvedColorScheme`（`lib/src/core/theme/app_theme_settings.dart`）。
- 删 `ShelfBookRepository.updateBookGroup`（`lib/src/features/library/data/shelf_book_repository.dart:222`）；批量移动走 `moveBooksToGroup`（同文件 :244）。删除后重新生成 mocks：`dart run build_runner build --delete-conflicting-outputs`。

原提案第 7 条（删 `BackupArchiveViolation` 枚举与 `BackupArchiveViolationException.violation` 字段）**已否决、未执行**，理由见 `## Consequences`。

## Alternatives considered

**保留作为"将来可能用"的预留** —— 落败：无调用方的 public API 即投机泛化；真需要时从 git 历史恢复的成本远低于长期维护面。

**每项单独一篇笔记** —— 落败：这些都是同一类决策的小删除，一篇 sweep 笔记足够。仓库有先例：commit f947117 一次性删除 14 个死方法。

## Consequences

- `flutter analyze` 零 error 零 warning；`flutter test` 全量通过；各项删除后在 `lib/` 内生产命中为 0；mocks 已重新生成且不包含被删方法。
- 纯删除、无行为变更，合计约 90 行。
- **第 7 条否决记录**：`BackupArchiveViolation` 是 `validateBackupArchiveEntries` 的公开返回类型，被 `docs/subsystems/core.md` 记载，且有 8 处测试断言用它区分 zip bomb / 路径越界等违规类型——它不是死 payload，而是对外契约的一部分。异常类型 `BackupArchiveViolationException` 还被 `library_actions_mixin.dart` catch。将来若有人再提议删除该枚举或 `violation` 字段，此记录即为否决依据。
- 提案原文中 `ImportCacheManager` 的路径笔误（写作 `core/services/`）已在上文修正为 `core/file_handling/`。
