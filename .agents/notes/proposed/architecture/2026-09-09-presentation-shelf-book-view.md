# Agent Note: 书架展示用窄视图类型替代 drift 行

Status: proposed

## Problem

presentation 直接依赖 drift 生成的 `ShelfBook`：9 个文件引 `core/database/app_database.dart`，`ShelfBook` 在 presentation 出现约 30 处（列表、网格项、选择条、详情页、目录抽屉）。`ShelfBook` 是 22 列的数据库行，presentation 只用到其中 8 列左右；后果有三：

1. 改表结构（加列、改列类型）会波及 UI，尽管 UI 不关心那些列。
2. widget test 必须构造整行才能 pump 一个卡片，fixture 成本高且随表结构漂移。
3. 分层的方向被绕过：`presentation → data` 虽已清零，但 `presentation → core/database` 让 UI 仍握着持久化模型。

## Proposal

给"书架列表项"定义一个 presentation 需要的窄视图类型 `ShelfBookView`（`features/library/domain/`），只含 UI 实际读取的字段（id、fileHash、title、author、coverPath、format、direction、currentChapterIndex、readingProgress、isFinished、groupName、updatedAt 等，按实际读取点收敛）。映射函数放在 `library/application`，由 provider 在把书交给 UI 前完成映射；presentation 只吃 `ShelfBookView`。

分两批落地，每批一个可验证切片（切法经调用点核实后调整过一次）：

1. **展示链路**：`ShelfBookView` + 映射 + `BookshelfState.books` + `LibraryItemsGrid` + `BookGridItem` + `LibrarySelectionBar`，并同步路由 `extra` 契约——网格点击目前把 `ShelfBook` 作为 `extra` 传给 `/book/:id`，详情页的 `initialBook` 也是 `ShelfBook`，所以两屏必须同一批改。
2. **详情内部**：`book_detail_screen` 的编辑 / 分享 / 保存与 `toc_drawer`、`library_actions_mixin`——这些动作需要完整行（保存要走仓库），改为经 application 用例按需取完整 `ShelfBook`，视图只传 id。

## Alternatives considered

**全量 domain 模型 + 映射层（把所有 drift 行都换成领域聚合）** —— 放弃：`docs/design.md` 的 seam 纪律说只有一种实现不建 seam；全量映射层是典型浅模块，且改动面横跨四个 feature。

**只把 `ShelfBook` 移到 `core/`** —— 放弃：位置变了但泄漏没变，UI 仍然依赖 22 列的行类型。

**不动，接受 UI 依赖 drift 行** —— 放弃：每次改 schema 都要回看 UI，且 widget test 的 fixture 成本会随表增长。

## 进度（2026-09-09）

存量从 10 个文件降到 5 个：`TocDrawer`、`GroupSelectionDialog`、`BookGridItem`、`BookDetailEditBody`、`BookDetailViewBody` 已改为只接收展示字段（各带一篇实现笔记）。剩下 5 个是同一簇，必须同批：`library_items_grid`（路由 `extra` 契约）、`book_detail_screen`、`library_app_bar`、`library_tab_view`、`library_actions_mixin`——核心是把 `BookshelfState.books` 与 `availableGroups` 换成视图类型，并同步 `/book/:id` 的 `extra`。

## Acceptance criteria

- `dart run tool/layer_gates.dart` 打印的存量从 10 个文件降到 ≤2（该名单只减不增，门禁会拒绝过期条目）；允许保留仅用 `TocItem` 等值类型的文件。
- `BookshelfState.books` 与 `LibraryItemsGrid` 只吃 `ShelfBookView`。
- 新增 `ShelfBookView` 映射的单测；书架相关 widget test 的 fixture 不再构造 `ShelfBook`。
- `flutter analyze` 零 issue、全量测试绿、`dart run tool/layer_gates.dart` 通过。

## Risks

- 映射点选错会把复杂度推给调用方：映射必须落在 application 的 provider 边界，而不是让每个 widget 自己转。
- 阅读器打开书籍时需要完整 `ShelfBook`（方向、进度、路径），过渡期会出现"两种类型并存"；用同一次改动内的调用点清单收敛，避免长期并存。
- `BookSession` 目前直接持有 `ShelfBook`（reader 侧），本提案不覆盖它——reader 的会话边界另有设计，留待单独评估。
