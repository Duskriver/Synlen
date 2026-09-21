# library

library 模块负责藏书：把书籍文件变成书架条目，管理分组、排序、备份与详情。本页 owns 这些类型、语义与边界；导入与阅读的数据流见 [architecture.md](../architecture.md#数据流)。

## 职责

- 导入：EPUB 走 stream-from-zip（压缩存盘、内存解析 OPF 与封面），TXT 解码归一化为 UTF-8 单文件后建虚拟章节。
- 书架：扁平分组、7 种排序、视图密度、多选移动与软删除。
- 备份：导出单文件 ZIP 交系统分享面板；恢复支持 ZIP 与文件夹两种来源。
- 详情页：读元数据、编辑保存、分享书籍文件。
- 对外接口：`BookQueries` 供 reader 宿主读书目与写进度，`BookActions` 供详情页与分享。

## 关键类型

| 类型 | 语义 | 位置 |
|---|---|---|
| `BookQueries` / `RepositoryBookQueries` | 跨 feature 书目接口：`findBook`、`findManifest`、`saveProgress`；宿主只依赖它 | `lib/src/features/library/application/book_queries.dart` |
| `BookActions` / `bookDetailProvider` | 详情页用例：按哈希取详情视图、保存元数据、按格式给 MIME 分享文件 | `lib/src/features/library/application/book_actions.dart` |
| `ShelfBookView` / `DetailBookView` / `EditableBookView` | 书架与详情消费的窄视图类型；drift 行到视图的映射在 `application/book_view_mapper.dart` | `lib/src/features/library/domain/book_views.dart` |
| `ReaderBookView` / `ReaderManifestView` | 阅读会话消费的窄视图类型；`BookQueries` 只返回它们，跨 feature seam 不外泄 drift 行 | `lib/src/features/library/domain/book_views.dart` |
| `BookshelfNotifier` / `BookshelfState` / `ViewMode` | 书架状态：排序、分组过滤、多选；状态值对象在 `bookshelf_state.dart`，多选纯函数在 `bookshelf_selection.dart`，标签页 LRU 缓存在 `bookshelf_tab_cache.dart` | `lib/src/features/library/application/bookshelf_notifier.dart` |
| `LibraryNotifier` / `ImportProgress` / `ImportStatus` | 导入编排：`importPipelineStream`（逐文件缓存 → 导入 → 清理）与 `importLibraryFromFolder` | `lib/src/features/library/application/library_notifier.dart` |
| `BookImportService` | 导入流水线编排：去重 → 落盘 → 解析 → 封面 → 落库；格式探测、文件落盘与封面提取分别在 `BookFileProbe` / `BookFileStore` / `CoverExtractor` | `lib/src/features/library/data/services/book_import_service.dart` |
| `ImportWorkers` / `ParseParams` / `ParseResult` | 在 isolate 中运行的 EPUB 解析、TXT 解析与图片压缩 | `lib/src/features/library/data/services/epub_import_workers.dart` |
| `EpubZipParser` / `EpubZipParseResult` | 直接从 ZIP 读 OPF、spine、TOC 与 manifest，不整包解压；OPF 元数据、TOC、路径解析与 encryption.xml 判定按 part 文件分组 | `lib/src/features/library/data/parsers/epub_zip_parser.dart` |
| `TxtDecoder` / `TxtEncoding` / `TxtDecodeResult` | TXT 编码识别：BOM → UTF-8 严格 → GBK 兜底，并用控制字符占比拦二进制内容 | `lib/src/features/library/data/parsers/txt_decoder.dart` |
| `TxtChapterSplitter` / `TxtChapter` | 章节切分：标题行正则、引导块、无标题时按体积分割 | `lib/src/features/library/data/parsers/txt_chapter_splitter.dart` |
| `TxtBookParser` / `TxtBookParseResult` | TXT 解析：产出 spine（`txt/chapter_N.xhtml` + 字节范围）、TOC 与归一化 UTF-8 | `lib/src/features/library/data/parsers/txt_book_parser.dart` |
| `ImportBackupService` / `LibraryBookStore` | 恢复：读 `shelf.json`、逐本事务合并书目与清单；元数据与进度分别取较新 | `lib/src/features/library/data/services/import_backup_service.dart` |
| `ExportBackupService` / `ExportResult` | 导出：临时目录拼装备份文件夹 → `ZipFileEncoder` 流式压缩 → 分享面板 | `lib/src/features/library/data/services/export_backup_service.dart` |
| `StorageCleanupService` | 清理孤儿书籍 / 封面 / 字体、缓存与分享临时文件 | `lib/src/features/library/data/services/storage_cleanup_service.dart` |
| `ShelfBookRepository` | 书与分组读写、软删除、进度更新、排序查询 | `lib/src/features/library/data/shelf_book_repository.dart` |
| `BookManifestRepository` | 阅读清单读写 | `lib/src/features/library/data/book_manifest_repository.dart` |
| `LibraryBookStore` | 书架跨表写编排：书与清单在同一事务双写、启动一致性修复（`libraryConsistencyRepairProvider` 触发） | `lib/src/features/library/data/library_book_store.dart` |
| `BookFormat` | `epub` / `txt`，决定解析器与阅读时内容供给的分支 | `lib/src/features/library/domain/book_format.dart` |
| `ShelfBookSortBy` | 7 种排序依据 | `lib/src/features/library/domain/shelf_book_sort_by.dart` |
| `ProgressLog` / `ImportResult` / `BackupImportProgress` | 导入与恢复的进度事件与结果值对象，data / application / presentation 共用 | `lib/src/features/library/domain/import_progress.dart` |
| `LibraryErrorCode` / `LibraryException` | import / backup 主链路的类型化错误：错误码供 presentation 映射 l10n，`details` 仅入日志；进度事件经 `ProgressLog.error` 携带 | `lib/src/features/library/domain/library_exception.dart` |
| `BookManifest` / `SpineItem` / `TocItem` / `ManifestItem` / `Href` | 阅读清单结构；`SpineItem.sourceRange` 记录 TXT 章节在归一化字节流中的范围 | `lib/src/features/library/domain/book_manifest.dart` |
| `BookFileChanges` | 导入与恢复的文件补偿：保留旧文件副本，事务失败恢复，成功清理副本 | `lib/src/features/library/data/services/book_file_changes.dart` |
| `BookDeletion` | 原子写入墓碑并删清单，再清理文件；清理失败等待存储清理重试 | `lib/src/features/library/application/book_deletion.dart` |

## 流程

1. 导入：`libraryProvider.importPipelineStream(paths)` 逐文件 `processEpub` → `BookImportService.importBook`，`finally` 立即删除缓存文件。
2. EPUB 导入：哈希 → 查重 → 复制到 `books/{hash}.epub` → isolate 解析 → 提取封面 → 建 `ShelfBook` 与 `BookManifest` → 事务落库；解析或落库失败时回滚已落盘的文件。
3. TXT 导入：isolate 解码归一化 → 写 `books/{hash}.txt` → spine 与 TOC 落库，无封面。
4. 恢复：ZIP 来源先解压到导入缓存区（`cleanupDir` 在流结束后删除），再走 `importLibraryFromFolder`；文件夹来源直接读。
5. 导出：`exportLibraryAsFile` 在临时目录组装 `synlen-backup-{timestamp}/`（books / covers / manifests / shelf.json），压缩后交分享面板。
6. 详情：`bookDetailProvider` 按 `fileHash` 返回 `DetailBookView`（网格点击前预取，详情页进入时无加载态）；编辑保存走 `BookActions.saveMetadataByHash`，分享走 `BookActions.shareBookByHash`（MIME 取自 `BookFormat.mimeType`，临时文件在分享结束后删除）。

## 边界与不变量

- 导入与恢复的书目和清单在同一事务中提交；文件补偿只覆盖运行中异常，不保证跨进程崩溃原子性。
- 删除事务失败不触碰文件；提交后的文件清理失败保留墓碑，书架按已删除处理，残留文件由存储清理重试。

- `LibraryNotifier` 必须 keepAlive：`importPipelineStream` 是 `async*`，方法体推迟到对话框订阅流之后才执行。
- `ShelfBook` 与 `BookManifest` 是持久化行，只在 `application` 与 `data` 之间流转；presentation 与 reader 只吃 `book_views.dart` 的视图类型。完整清单只在打开阅读器时查询。
- 新书（`id = 0`）落库时主键缺席走自增，避免覆盖已有行。
- 书与清单靠相同 `fileHash` 关联（数据库层无外键），双写在同一事务中完成；启动时跑一次一致性修复：硬删无清单的未删除书与无书的清单，软删除墓碑行不动，被删书的物理文件由 `StorageCleanupService` 清理。
- 删除文件的方法同时接受相对与绝对路径；回滚路径必须等待删除完成。
- 分组为扁平结构，不支持嵌套；`filterGroupId` 为 `-1` 表示未分组，`null` 表示全部。
- 备份 ZIP 的解压目录由调用方在流结束后删除，恢复服务自身不清理；解压前的上限与路径校验在 core 的 `backup_archive_guard.dart`（见 [core](core.md#关键类型)）。
- 导出备份格式为 2，恢复兼容格式 1 的旧坐标和格式 2 的完整 Locator／待恢复旧坐标。shelf.json 与每书 manifest 顶层的 `version` 由 `backup_decoders.dart` 按版本分派 decoder：字段缺失按 1 处理并记 warning，高于当前支持版本（`kBackupFormatVersion`）时恢复中止，抛 `LibraryException`（`backupVersionTooNew`）。
- 导入进度事件落在 `domain`，使 data 发事件、application 编排、presentation 渲染都不产生逆向依赖。
- 含 `META-INF/encryption.xml` 的 EPUB：仅当每个 EncryptedData 都是 IDPF / Adobe 字体混淆算法且目标是字体 media-type 时放行（`epub_encryption.dart`）；其余按 DRM 拒绝（`LibraryErrorCode.drmProtected`）。放行书籍的混淆字体在阅读时由 Rust 侧现场还原（见 [rust.md](rust.md#职责)）。
- import / backup 主链路的错误是 `Either<LibraryException, T>` 或携带 `LibraryException` 的进度事件；presentation 只按错误码映射 l10n（`library_error_mapper.dart`），不匹配消息内容。分组 CRUD、删除、清理等其余链路仍是 `Either<String, T>`，迁移时往 `LibraryErrorCode` 补码。

## 已知限制与待办

## Dev Note

None.
