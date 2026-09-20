# Agent Note: 书架展示用窄视图类型替代 drift 行

Status: implemented

## Problem

presentation 直接依赖 drift 生成的 `ShelfBook`：9 个文件引 `core/database/app_database.dart`，`ShelfBook` 在 presentation 出现约 30 处（列表、网格项、选择条、详情页、目录抽屉）。`ShelfBook` 是 22 列的数据库行，presentation 只用到其中 8 列左右；后果有三：改表结构会波及 UI，尽管 UI 不关心那些列；widget test 必须构造整行才能 pump 一个卡片，fixture 成本随表结构漂移；`presentation → core/database` 让 UI 仍握着持久化模型。

## Decision

书架展示链路只吃窄视图类型，drift 行只在 application 与 data 之间流转：

- `domain/book_views.dart` 定义 `ShelfBookView`（书架列表项与网格卡片）、`DetailBookView`（详情只读视图）、`EditableBookView`（详情编辑表单）；drift 行到视图的映射在 `application/book_view_mapper.dart`。`EditableBookView` 从 `DetailBookView` 投影，不再回头读行。
- `BookshelfNotifier._loadBooks` 是唯一的映射点：查询结果一次映射成视图，状态、标签页 LRU 缓存与 UI 都只吃视图；`BookshelfState.books` 与 `BookshelfTabCache` 的类型随之改为 `ShelfBookView`。
- 详情路由 `/book/:id` 只传 `fileHash`（即路径参数本身），`BookDetailScreen` 不带 `initialBook`，`bookDetailProvider` 返回 `DetailBookView?`。网格点击前预取该 provider，路由动画结束时数据已就位，详情页不闪加载态。
- 保存与分享按哈希取整行：`BookActions.saveMetadataByHash` / `shareBookByHash` 在 application 内部 `getBookByHash` → `copyWith` → 落库 / 分享，presentation 只提供编辑后的字段与哈希。
- 分享的 MIME 由 `BookFormat.mimeType` 决定，l10n 的 `shareEpub` / `shareEpubFailed` 改名 `shareBook` / `shareBookFailed`：TXT 文件不再被标成 `application/epub+zip`。
- 分层门禁的 `_presentationDriftAllowlist` 清空，presentation 新增 drift 依赖被规则 5 直接拒绝。

## Alternatives considered

**全量 domain 模型 + 映射层（把所有 drift 行都换成领域聚合）** —— 放弃：`docs/design.md` 的 seam 纪律说只有一种实现不建 seam；全量映射层是典型浅模块，且改动面横跨四个 feature。

**只把 `ShelfBook` 移到 `core/`** —— 放弃：位置变了但泄漏没变，UI 仍然依赖 22 列的行类型。

**路由 `extra` 传详情视图，保留 `initialBook` 的瞬时展示** —— 放弃：网格手里的 `ShelfBookView` 是 `DetailBookView` 的子集，构造不出详情视图；把两者并成一个大视图又退回单一宽视图。改为点击前预取 `bookDetailProvider`，瞬时展示由 provider 缓存提供。

**不动，接受 UI 依赖 drift 行** —— 放弃：每次改 schema 都要回看 UI，widget test 的 fixture 成本会随表增长。

## Consequences

- presentation 不再 import `core/database/app_database.dart`：`dart run tool/layer_gates.dart` 的存量计数为 0，名单为空集，新增依赖会被规则 5 拒绝。
- 书架相关 widget test 的 fixture 从 22 列 `ShelfBook` 变成 8 字段记录；`shelfBookView` / `detailBookView` / `editableBookView` 与 `BookFormat.mimeType` 都有单测。
- 详情页不再有 `initialBook` 兜底，无加载态依赖网格预取 `bookDetailProvider`，因此该 provider 保持手写 `FutureProvider.family`（非 autoDispose）：换成 codegen 的 autoDispose 会在路由动画期间丢掉预取结果。
- reader 会话侧的收窄由 [BookQueries 收窄为阅读视图](2026-09-09-book-queries-reader-view.md) 完成：`ReadiumSession` 持 `ReaderBookView` / `ReaderManifestView`，跨 feature seam 不再出现 drift 行类型。
