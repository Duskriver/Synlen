# Agent Note: 目录抽屉改为只接收书目字段

Status: implemented

## Problem

`TocDrawer` 持有整行 `ShelfBook`，实际只读 `title` / `author` / `coverPath` / `totalChapters` 四个字段——这是[窄视图类型笔记](2026-09-09-presentation-shelf-book-view.md)里的第一处可独立迁移的依赖。

## Decision

`TocDrawer` 改为接收四个字段；调用方 `reader_screen` 从会话取书后拆开传入。`tool/layer_gates.dart` 的存量名单随之删掉该文件（门禁会拒绝过期条目）。

## Alternatives considered

**直接引入 `ShelfBookView`** —— 放弃：本处只读四个标量，传字段比引入类型更窄，也避免在提案第一批落地前先铺一层类型。

**留在存量名单里** —— 放弃：抽屉与持久化模型解耦后，继续留在名单里只会让名单虚高。

## Consequences

- presentation 依赖 drift 行类型的存量从 10 个文件降到 9 个；门禁自动拒绝过期条目这一机制得到首次实战验证。

- 行为不变：抽屉展示的字段与回退逻辑逐字保留。
