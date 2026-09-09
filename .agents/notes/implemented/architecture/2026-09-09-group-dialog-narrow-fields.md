# Agent Note: 分组选择对话框改为只接收 id 与名称

Status: implemented

## Problem

`GroupSelectionDialog` 持有 `List<ShelfGroup>`，实际只用 `id` 与 `name`——[窄视图类型笔记](2026-09-09-presentation-shelf-book-view.md)里第二处可独立迁移的依赖。

## Decision

对话框改吃 `List<GroupOption>`（`({int id, String name})` 记录类型，定义在对话框文件里）；调用方 `library_actions_mixin` 在传入前把 `state.availableGroups` 映射成该形状。门禁存量名单随之删掉该文件。

## Alternatives considered

**在 domain 新建 `ShelfGroupView` 类** —— 放弃：两个标量用记录类型即可，等第二处也需要分组视图时再提类型。

**让对话框自己读 provider** —— 放弃：对话框是纯展示组件，状态由调用方给。

## Consequences

- presentation 依赖 drift 行类型的存量从 9 个文件降到 8 个。

- 行为不变：选项顺序、文案与返回值语义逐字保留。
