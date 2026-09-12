# Agent Note: 文件哈希编码统一为 hex

Status: implemented

## Problem

同一 SHA-256 内容哈希存在 hex 与 base62 两种编码表示。主链路是 hex：`lib/src/core/file_handling/import_cache_manager.dart` 的 `sha256.bind(stream).first.toString()` → `ImportableEpub.hash` → `lib/src/features/library/application/library_notifier.dart` 的 `precomputedHash` → 直接成为 `ShelfBook.fileHash`。备用路径是 base62：`epub_import_workers.dart` 的 `ImportWorkers.calculateFileHash` 把同一 SHA-256 经 `BigInt` 转 `_toBase62`，再经 `BookFileProbe.calculateHash` 成为 `BookImportService.importBook` 的 `precomputedHash ??` 兜底。`importBook` 全库唯一生产调用点总是携带 hex 的 `precomputedHash`，base62 分支生产不可达（仅测试命中）；一旦走达，产出的 `fileHash` 与导入管线、备份清单里的 hex 哈希永不匹配，去重与恢复比对静默失效。

## Decision

备用哈希路径没有独立价值，整体删除：`ImportWorkers.calculateFileHash` / `_toBase62` 与 `BookFileProbe.calculateHash` 全部移除。`BookImportService.importBook` 的 `precomputedHash` 从可空兜底改为 `required`——调用方在导入前经主链路算好 hex 哈希传入，编码单一来源。`importBook` 仍可独立使用，但哈希必须由调用方负责计算。`fileHash` 全链路（`ShelfBook`、文件名 `books/{fileHash}.epub`、导入缓存、备份导出/恢复/合并）只有 hex 一种编码。

## Alternatives considered

**统一成 base62** —— 落败：备份清单与导入缓存的存量哈希都是 hex，迁移面更大。

**保留双编码、在比较点归一化** —— 落败：比较点分散在去重、恢复、备份多处，归一化容易漏——这正是现状的失效来源，不是解法。

## Consequences

- `fileHash` 全链路单一 hex 编码；全库无 `_toBase62`。
- `BookFileProbe` 只负责格式探测，类职责收窄；`ImportWorkers` 只负责 isolate 内的解析与图片压缩。
- `importBook` 不再自行读文件算哈希，I/O 职责完全上移到调用方。
- 存量 base62 数据核查结论：仓库内不存在携带 `file_hash` 的 SQLite 数据库文件或测试夹具（`git ls-files` 无 `.db`/`.sql` 类文件；测试均用内存数据库；非 64 字符的哈希样字符串只出现在 `web_assets/controller.js/package-lock.json` 的 npm integrity base64 与 base62 字符集字面量中，与 `file_hash` 无关）。代码史上 base62 分支生产不可达，无存量 base62，无需迁移脚本。
