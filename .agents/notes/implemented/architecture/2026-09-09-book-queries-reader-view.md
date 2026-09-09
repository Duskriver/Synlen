# Agent Note: BookQueries 收窄为阅读视图，seam 不再外泄 drift 行

Status: implemented

## Problem

`BookQueries` 是 library 暴露给 reader 的跨 feature seam，但 `findBook` / `findManifest` 直接返回 drift 生成的 `ShelfBook` / `BookManifest` 行：接口文件 import `core/database/app_database.dart`，reader 的 `BookSession` 也因此握着 22 列的持久化行。这与书架链路已完成的收窄（见 [书架展示用窄视图类型替代 drift 行](2026-09-09-presentation-shelf-book-view.md)）是同一个问题的 reader 半场：改表结构会波及 reader，reader 的测试 fixture 必须构造整行，跨 feature 契约由生成代码定义而非由领域定义。

## Decision

`BookQueries` 的读取方法只返回定义在 `domain/book_views.dart` 的窄视图，接口文件不再 import `app_database.dart`：

- `ReaderBookView`：`id`、`title`、`author`、`coverPath`、`filePath`、`totalChapters`、`direction`、`currentChapterIndex`、`chapterScrollPosition`。
- `ReaderManifestView`：`spine`、`toc`。
- 行 → 视图的映射收在 `application/book_view_mapper.dart` 的 `readerBookView` / `readerManifestView`，与既有 `shelfBookView` 等映射同一处。
- `BookSession._book` / `_manifest` 改持视图；`saveProgress` 仍按行主键 `id` 落库，错误语义不变（仓库 `Either` 失败仍翻译为 `StateError`，不引入 `LibraryException`——进度落库不在 import / backup 错误模型统一的范围内）。

## 字段取舍

进视图的字段全部由 reader 侧实际调用点决定：

- `id`：`saveProgress` 的落库主键，必要。
- `title`：TOC 查找表回退标签、目录抽屉标题、舞台标题。
- `direction`：渲染方向。
- `currentChapterIndex` / `chapterScrollPosition`：初始阅读位置。
- `filePath`：EPUB 后端按路径取条目（脚注与封面链路，`epubPath`）。
- `author` / `coverPath` / `totalChapters`：目录抽屉的书目头部展示。

明确不进视图的数据库语义：

- `readingProgress` / `lastOpenedDate`：reader 不读；唯一消费方是 `reading_progress_persistence_test` 的持久化断言，改为直接经 `ShelfBookRepository` 读行验证。
- `isDeleted`（软删除标志）：reader 从不判定；打开已软删书籍的语义维持原样，不在本次改动中收紧。
- `fileHash`：会话自带路由参数，不重复携带。
- `ReaderManifestView` 不带 `id` / `opfRootPath` / `epubVersion` / `format` / `lastUpdated`：reader 只用 `spine` 与 `toc`。

## Alternatives considered

**reader 自建视图类型放在 reader/domain** —— 放弃：视图的字段由 library 的行结构映射而来，所有权属于 library；放 reader 会让 library 的 application 依赖 reader 的 domain，方向倒置。

**复用 `DetailBookView` 喂 reader** —— 放弃：两者字段集不同（reader 要 `filePath` 与进度位置，详情要 `authors` / `description` / `format`），合并即退回单一宽视图。

**`findManifest` 保留 drift 行** —— 放弃：`BookManifest` 同样是生成行；只收窄 `findBook` 则接口文件仍须 import `app_database.dart`，本笔记的目标不成立。

**行 → 视图映射下沉到 data 层仓库** —— 放弃：仓库返回行是 data 层的一致约定（导入、备份、清理都消费整行）；映射留在 application 与既有 `book_view_mapper.dart` 同处。

## Consequences

- `lib/` 中跨 feature seam 的签名不再出现 drift 行类型；reader 侧只有测试 fixture 变化，行为不变。
- reader 相关测试 fixture 从 22 列 `ShelfBook` 整行变为 9 字段记录；`readerBookView` / `readerManifestView` 与 `RepositoryBookQueries` 的映射各有单测。
- `reading_progress_persistence_test` 的持久化断言直接读仓库行，不再经会话对象。

## 其他外泄核查

对 settings、learning、reader 的 application 层与 `global_share_handler.dart` 逐一核查，签名中外泄 drift 行类型的只有本 seam：

- `library/application/book_actions.dart`、`library_notifier.dart`、`book_view_mapper.dart` 仍 import `app_database.dart`，但三者只被 library 内部消费（presentation / application 同 feature），不是跨 feature 外泄。
- settings 组合面与 learning 的跨 feature 接口签名均为领域类型或基础类型。

## Deferred

- 打开软删除书籍的行为是否应拒绝（`isDeleted` 判定）留待会话边界设计时一并处理。
- `application` 层直接 import `app_database.dart`（映射器与编排器）是否也收窄，超出本 issue 范围。

## Related

- [书架展示用窄视图类型替代 drift 行](2026-09-09-presentation-shelf-book-view.md)（同一收窄运动的 presentation 半场）
- [组合面允许依赖其他 feature 的 application 层](2026-09-08-composition-surface-cross-feature.md)（分层门禁的跨 feature 规则来源）

## Dev Note

None.
