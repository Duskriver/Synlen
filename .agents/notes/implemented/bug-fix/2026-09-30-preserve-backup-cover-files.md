# Agent Note: 按持久化路径完整导出封面

Status: implemented

## Problem

图片压缩不可用时，导入可保留 GIF、BMP、SVG 等原始封面；导出只枚举少数后缀，会在备份报告成功时遗漏这些文件。持久化封面路径与哈希命名不一致时，仅按哈希查源文件也会取错图片。

## Decision

[ExportBackupService](../../../../lib/src/features/library/data/services/export_backup_service.dart)以 `coverPath` 选择源文件，支持相对与绝对路径。备份内保留原后缀并统一以书籍哈希命名，使现有恢复分类能关联任意源文件名；缺少路径的旧书目保留常见后缀查找。配置路径存在时，同哈希的其他图片不得替代它。

本决策落实[上游吸纳研究](../../proposed/process/2026-09-26-selective-lumina-upstream-adoption.md)的封面候选。[备份版本分派](../feature/2026-09-09-backup-version-decoders.md)、[恢复服务拆分](../architecture/2026-09-09-backup-service-split.md)与[解压完整性](2026-09-09-update-backup-hardening.md)继续拥有各自契约；本决策不改变格式版本、合并语义或校验上限，没有整篇取代的笔记。

## Alternatives considered

**仅增加后缀白名单。** 放弃：仍不能以持久化路径为准，新增图片格式还会再次漏导出。

**沿用源封面文件名写入 ZIP。** 放弃：恢复按去后缀的文件名关联书籍哈希，任意源文件名会失去关联。

## Consequences

真实 ZIP 与 SQLite 回归覆盖 GIF、BMP、SVG 的导出与空存储恢复、原始字节、任意源文件名、旧 JPEG 残留的优先级，以及无路径旧书目和绝对路径。封面仍为可选资源；源文件本身缺失时记录日志并跳过，不生成替代图片。
