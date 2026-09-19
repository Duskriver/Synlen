# Agent Note: library 错误模型统一到类型化错误码

Status: implemented

## Problem

library/data 约 30 处 `Either<String, T>`：错误码、内部细节、用户文案混在一个字符串里，presentation 靠 `String.contains(标记)` 分支（`drmProtectedErrorMarker` / `backupVersionTooNewErrorMarker`），toast 甚至直接上屏 `e.toString()` 的内部细节。learning 的 `LearningErrorCode` 与 settings 的 `UpdateErrorCode` 已验证「enum 错误码 + exception（details 仅入日志）」范式。

## Decision

**错误模型**：`lib/src/features/library/domain/library_exception.dart` 定义 `LibraryErrorCode`（11 码）与 `LibraryException(code, details)`，`details` 仅入日志不上屏。码表按 import / backup 主链路的失败语义盘点既有 String 消息后定：

- import：`fileUnreadable`（读取/哈希）、`parseFailed`（EPUB/TXT 解析）、`drmProtected`、`duplicateBook`、`fileWriteFailed`（落盘）、`saveFailed`（写库）、`importFailed`（兜底）。
- backup：`backupVersionTooNew`、`backupArchiveInvalid`（ZIP 解压前校验不过）、`backupCorrupted`（JSON 损坏/结构不一致）、`restoreFailed`（兜底）。

**保留 `Either`，只换 Left 类型**：import 主链路（`EpubZipParser`、`TxtBookParser`、`ImportWorkers`、`BookFileProbe`、`BookFileStore`、`BookImportService.importBook`）从 `Either<String, T>` 改为 `Either<LibraryException, T>`。恢复链路本就走进度事件流：`ImportFailure` 改持 `LibraryException`，`ProgressLog` 增加 `error` 字段，application（`LibraryNotifier`）把 Left 与兜底异常转成事件携带的类型化错误。

**presentation 只按码映射**：`library_error_mapper.dart` 的 `libraryErrorMessage` 把码映射为 l10n；`ProgressDialog` 日志面板与 `RestoreProgressDialog` 的版本过新判定不再做字符串匹配。core 的 `BackupArchiveViolationException` 留在 `core/file_handling`（共享校验器），在 `library_actions_mixin` 桥接为 `backupArchiveInvalid` 码。`BackupVersionTooNewException` 删除，`backup_decoders.dart` 直接抛 `LibraryException`。

**标记字符串模式废除**：`drmProtectedErrorMarker` / `backupVersionTooNewErrorMarker` 删除，两条链路迁入类型化错误。

**范围纪律**：分组 CRUD、详情编辑、删除、清理等其余链路保持 `Either<String, T>` 不动，迁移时往 `LibraryErrorCode` 补码。

## Alternatives considered

**主链路改为抛 `LibraryException`** —— 放弃：调用方（`LibraryNotifier` 的 fold、批量测试的 unwrap）全部要改成 try/catch，diff 更大；且单本导入失败是预期控制流（继续下一本），Either 的形状更贴切，与模块内未迁移区域风格一致。

**全模块一次性迁移** —— 放弃：违反增量重构约定（见 [incremental-refactor-over-big-bang](2026-08-10-incremental-refactor-over-big-bang.md)）；分组 CRUD 的 String 错误没有上屏匹配逻辑，迁移收益低。

**保留标记字符串做兼容** —— 放弃：标记的全部生产与消费点都在本次迁移范围内，保留会出现两套并行机制。

## Consequences

- l10n：`importFailed` / `restoreFailed` 去掉 `{error}` / `{message}` 参数（不再上屏内部细节），新增 `importFileUnreadable`、`importParseFailed`、`importDuplicateBook`、`importFileWriteFailed`、`importSaveFailed`、`backupDataCorrupted` 六个 key，双语同批。
- 新增错误码时必须同步 `library_error_mapper.dart` 的 switch 与双语 l10n；switch 穷举由编译器保证。
- 未迁移区域（后续 issue 收）：`ShelfBookRepository` / `BookManifestRepository` / `LibraryBookStore` 的 `Either<String, T>`、`ExportBackupService` 的 `ExportFailure(String message)`、分组 CRUD 与 `StorageCleanupService`。
- core 的 `backup_archive_guard.dart` 未动；若未来其他 feature 消费备份恢复，桥接点需要下沉。

## Testing

- `test/features/library/data/services/txt_import_test.dart`：重复导入、解析失败、写库失败分别断言 `duplicateBook` / `parseFailed` / `saveFailed` 码。
- `test/features/library/data/parsers/epub_encryption_test.dart`：DRM 三条拒绝路径断言 `drmProtected` 码与 details。
- `test/features/library/data/services/import_backup_service_test.dart`：版本过新两条链路断言 `backupVersionTooNew` 码。
- `test/features/library/presentation/library_error_mapper_test.dart`（新增）：全码表双语文案非空，DRM / 版本过新 / 归档非法三码映射断言，未知异常回退且 details 不上屏。
- `flutter analyze` 零 error 零 warning；`flutter test test/features/library test/core` 全绿；`dart run tool/layer_gates.dart` 与 `dart run tool/doc_gates.dart` 通过。

## Related

- [EPUB 字体混淆放行与 DRM 拒绝](../feature/2026-09-09-epub-font-obfuscation.md)：DRM 判定规则的来源，本次只改错误携带方式。
- [备份版本分派 decoder](../feature/2026-09-09-backup-version-decoders.md)：版本语义的来源，本次只改错误携带方式。
- [更新检查与 APK 下载移出 presentation](2026-09-09-update-flow-out-of-presentation.md)：`UpdateErrorCode` 范式参照。
