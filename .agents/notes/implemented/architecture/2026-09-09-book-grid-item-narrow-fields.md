# Agent Note: 书架卡片改为只接收展示字段

Status: implemented

## Problem

`BookGridItem` 持有整行 `ShelfBook`，实际只读 `id` / `title` / `author` / `coverPath` / `readingProgress` / `isFinished` / `isDeleted`——[窄视图类型提案](../../proposed/architecture/2026-09-09-presentation-shelf-book-view.md)里的第三处可独立迁移的依赖。

## Decision

卡片改吃记录类型 `GridBookView`（定义在卡片文件里），字段与原读取点一一对应；`LibraryItemsGrid` 在构造处把 `ShelfBook` 映射成它。门禁存量名单随之删掉该文件。

## Alternatives considered

**抽 `ShelfBookView` 类并同时改网格与路由 `extra`** —— 放弃：那要求网格、详情页与路由契约同批改，属于提案第一批的整体范围；本处先用记录类型收窄叶子组件。

**让卡片自己读 provider 拿完整书** —— 放弃：卡片是纯展示组件，数据由列表给。

## Consequences

- presentation 依赖 drift 行类型的存量从 8 个文件降到 7 个。

- 卡片展示逻辑（进度百分比、封面回退、hero tag）逐字保留，行为不变。
