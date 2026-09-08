# Agent Note: 详情只读视图改为只接收书目字段

Status: implemented

## Problem

`BookDetailViewBody` 持有整行 `ShelfBook`，实际读 11 个字段——[窄视图类型提案](../../proposed/architecture/2026-09-09-presentation-shelf-book-view.md)里字段最多的一处。

## Decision

视图改吃 `DetailBookView`（记录类型，字段与原读取点一一对应，含 `BookFormat` 等 domain 类型）；详情页在构造处映射。门禁存量名单随之删掉该文件。

## Alternatives considered

**把它并入提案第一批的 `ShelfBookView`** —— 放弃：`ShelfBookView` 要覆盖列表与详情两侧，先按本视图实际读取面收窄，等列表侧迁移时再决定是否合并为一个类型。

## Consequences

- presentation 依赖 drift 行类型的存量从 6 个文件降到 5 个。

- 详情页的展示与跳转行为逐字保留。
