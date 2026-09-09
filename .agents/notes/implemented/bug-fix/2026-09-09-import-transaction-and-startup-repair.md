# Agent Note: 书籍导入双写改真事务并补启动一致性修复

Status: implemented

## Problem

`BookImportService` 导入落库是先写 `ShelfBook` 再写 `BookManifest` 的两步顺序写：第二步失败时手工 `deleteBook` 补偿，且补偿的返回值未检查——补偿失败就留下"有书无清单"的孤儿行，书在书架上可见却无法打开。反向的"有清单无书"孤儿同样没有任何清理路径，全库也没有外键兜底。

## Decision

- 新增 data 层 `LibraryBookStore`（`lib/src/features/library/data/library_book_store.dart`，注入 `AppDatabase`），`saveBookWithManifest` 把双写包进 `_db.transaction()`：任一步抛错整体回滚，不再手工补偿。`BookImportService` 改调它；保存失败后的文件清理由调用方照旧负责。对外接口 `importBook` 签名不变。
- 启动一致性修复：`LibraryBookStore.repairOrphanRecords` 在单事务内扫描两表、按 fileHash 互查，删除两个方向的孤儿。删除方向：无清单的未删除书硬删（缺清单无法打开阅读，是旧版导入半路失败的残留）；无书的清单删除（任何路径不可达的纯垃圾）。软删除的墓碑行不动（备份恢复与同步语义依赖它），清单对应的软删除书行存在时也不动（恢复导入会覆盖重建）。
- 接入点：`application/library_consistency_repair.dart` 的 `libraryConsistencyRepairProvider` 编排并记日志，`main.dart` 在建 ProviderContainer 后 fire-and-forget 触发，不阻塞首屏。只在启动时跑一次，此时不可能有导入在进行，不会误删导入中的记录。
- 不给 `BookManifests.fileHash` 加对 `ShelfBooks.fileHash` 的外键（无 schema v3）。
- 被删孤儿书的物理文件不在本次修复里删，交给既有手动触发的 `StorageCleanupService.cleanOrphanFiles`。

## Alternatives considered

**保留两步写、把补偿删除的返回值检查补上** —— 放弃：补偿本身也会失败，治标不治本；SQLite 事务是现成且已被本仓库（`updateGroupName` / `deleteGroup`）使用的机制。

**schema v3：`BookManifests.fileHash` 加 `references(ShelfBooks, #fileHash)`** —— 放弃。一、引用非主键的 unique 文本列，drift 会重建整张表做迁移，而存量库恰恰可能存在本 issue 要清理的孤儿行，带 FK 的表重建会直接在孤儿数据上失败，迁移前还得先跑一遍清理逻辑，鸡生蛋。二、收益增量小：双写真事务已封住新孤儿产生的路径，启动修复清理存量；FK 只剩防御未来回归。三、代价实：每写一次清单多一次父表查找，且 soft-delete 流程（删清单留书行）与 FK 方向的交互需要逐一验证。若未来再次出现孤儿残留事故，可重新评估。

**修复例程阻塞首屏（await 后再 runApp）** —— 放弃：扫描两表通常毫秒级但无必要挡首屏；失败也只影响下一次清理，fire-and-forget + 日志足够。

**修复时连带删除孤儿书的物理文件** —— 放弃：物理文件清理已有 `StorageCleanupService` 负责，修复例程只管 DB 一致性，职责不重叠。

## Consequences

- 导入落库的原子性由 SQLite 事务保证，手工补偿路径删除；`txt_import_test.dart` 的回滚用例改为断言"双写失败时不调 deleteBook 补偿"。
- 墓碑行语义成为不变量：软删除的书不视为孤儿，后续改删除流程时不得让墓碑行失去清单以外的其他依赖语义。
- `ShelfBookRepository.deleteBook`（硬删除）在导入路径不再被调用，但仍是合法 CRUD 原语，保留。
- 备份恢复链路（`BackupMerger`）仍是书与清单分步 upsert，未纳入本次事务化；如出现同类问题再处理。

## Testing

- `test/features/library/data/library_book_store_test.dart`：双写成功落库；拆掉清单表使第二步写入抛错，验证书架表随事务回滚不留记录；修复例程覆盖两个孤儿方向各一用例、软删除墓碑保留、健康数据不误删且计数为 (0, 0)。
- `test/features/library/data/services/txt_import_test.dart`：双写失败只清理已落盘文件、不做补偿删除；既有 TXT 导入用例适配新的双写 seam 后全绿。
- `flutter analyze` 零问题；`flutter test test/features/library test/database test/epub_import_test.dart` 全绿；`dart run tool/layer_gates.dart` 通过。
