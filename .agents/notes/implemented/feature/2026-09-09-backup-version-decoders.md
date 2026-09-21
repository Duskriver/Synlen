# Agent Note: 备份格式 version 字段的消费与逐版本分派

Status: implemented

## Problem

导出端从第一版起就在 shelf.json 与每书 manifest 顶层写入 `version: 1`，但恢复端从不读取它：格式演进没有锚点，未来一旦改格式，新应用写出的备份会被旧恢复逻辑按 v1 静默错解，且旧应用也无法识别新备份。

## Decision

- `backup_decoders.dart`（library/data）是 version 的唯一消费点：`decodeShelfBackup` / `decodeManifestBackup` 读取顶层 `version`，经 `_shelfDecoders` / `_manifestDecoders` 注册表分派到对应版本的 decoder；格式 1、2 共用顶层列表与清单解码，进度字段由 mapper 识别。
- `kBackupFormatVersion` 是当前支持的最高版本，导出端两处写入都改用该常量，版本号单一来源。
- 字段缺失视为异常但按 1 处理并记 warning——v1 时代备份始终带该字段，缺失多半是手工构造；版本高于支持上限时抛 `LibraryException`（`backupVersionTooNew`），恢复在任何写库之前中止。
- 用户可见错误按类型化错误码承载（见 [library 错误模型统一](../architecture/2026-09-09-library-typed-error-codes.md)）：`ImportFailure` 携带 `LibraryException`，日志详情只入 appLogger；`progress_dialog.dart` 按 `ProgressLog.error` 的码映射为 l10n 文案，`restore_progress_dialog.dart` 在失败码为 `backupVersionTooNew` 时把结束 toast 换成 `backupVersionTooNew`（双语）。
- v1 decoder 就是既有行为：shelf 取 `groups` / `books` 列表，manifest 委托 [backup_json_mapper](../architecture/2026-09-09-backup-service-split.md) 的 `mapToBookManifest`，反序列化逻辑不复制。

## Alternatives considered

**抛类型化异常穿透到 mixin 弹 toast（同 `BackupArchiveViolationException`）** —— 放弃：恢复失败走进度流（`ImportFailure` 事件）是既有契约，`LibraryNotifier.importLibraryFromFolder` 会把流异常吞成错误日志；穿透需要改三层错误模型，属于 #13 的错误模型统一范畴。

**只在恢复端校验，导出端继续写字面量 1** —— 放弃：两处写入同一语义却各自硬编码，未来升版本必然漏改一处。

**把分派做进 `backup_json_mapper.dart`** —— 放弃：mapper 是逐字段硬解的纯函数集（见[恢复服务拆分](../architecture/2026-09-09-backup-service-split.md)），版本分派是策略层，独立文件让 v2 的落点一目了然。

## Consequences

- 导出格式 2 并兼容格式 1；进度兼容由[升级保留数据决策](../bug-fix/2026-09-21-preserve-legacy-reader-data.md)部分补充。回归覆盖完整 Locator、旧坐标往返、高版本拒绝与 version 缺失。
- 恢复中止发生在读元数据阶段，中止时未写任何库行。
- 新格式在注册表中显式登记，导出版本只由 `kBackupFormatVersion` 提供。
