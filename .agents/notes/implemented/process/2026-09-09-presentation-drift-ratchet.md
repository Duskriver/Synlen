# Agent Note: 分层门禁加 presentation 依赖 drift 的存量闸门

Status: implemented

## Problem

presentation 有 10 个文件直接引 drift 生成的 `ShelfBook` / `ShelfGroup`（其中 2 个是本次重构拆 `LibraryTabView` / `LibraryItemsGrid` 时带出来的）。这层依赖在[窄视图类型笔记](../architecture/2026-09-09-presentation-shelf-book-view.md)落地前会继续扩散——每拆一个新组件都可能顺手多引一次。

## Decision

`tool/layer_gates.dart` 新增规则 5：presentation 引 `core/database/app_database.dart` 只允许出现在存量名单里；名单只减不增，且过期条目会让门禁失败（文件不再引 drift 时必须删名单行）。门禁同时打印当前存量数，作为提案的机器可检目标。

## Alternatives considered

**等提案落地再上闸门** —— 放弃：迁移分两批、跨多个回合，期间新组件会继续扩散，先立闸门才有净减少。

**直接禁止（不给名单）** —— 放弃：10 处存量会让门禁立刻红，被迫在同一个提交里做完整个迁移。

## Consequences

- 新增 presentation→drift 依赖会立刻失败（已自测：临时加一行即报错）；存量数随迁移单调下降。

- 名单过期会失败，避免迁完忘删留下的假存量。
