# Agent Note: 分组列表改为视图类型，标签页与动作去 drift 依赖

Status: implemented

## Problem

`BookshelfState.availableGroups` 是 `List<ShelfGroup>`（drift 行），导致标签页、应用栏与书架动作 mixin 都被迫引 `core/database`——[窄视图类型提案](../../proposed/architecture/2026-09-09-presentation-shelf-book-view.md)里最后一簇结构性依赖的一半。

## Decision

新增 `GroupOption`（`({int id, String name})`，定义在 `domain/book_views.dart`）；`availableGroups` 改为 `List<GroupOption>`，由 `BookshelfNotifier` 在读取分组后映射；标签页、应用栏、动作 mixin 与分组对话框统一用它。

## Alternatives considered

**保留 `List<ShelfGroup>`，只在每个消费者处映射** —— 放弃：映射会散到三处，且每处仍要 import drift。

**等路由 `extra` 契约一起改** —— 放弃：分组与书籍是两条独立链路，先做完分组这条能把存量砍掉一半。

## Consequences

- presentation 依赖 drift 行类型的存量从 5 个文件降到 **2 个**（仅剩路由契约簇：`library_items_grid` 与 `book_detail_screen`），达到提案的验收阈值。

- 行为不变：标签页数量与顺序、分组对话框选项与编辑回调语义逐字保留。
