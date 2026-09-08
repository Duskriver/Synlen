# Agent Note: 书架状态、多选与标签页缓存分文件

Status: implemented

## Problem

`bookshelf_notifier.dart` 423 行里，notifier 与三样不属于它的东西挤在一起：状态值对象（`ViewMode` + `BookshelfState`，68 行）、四条纯状态迁移（进入/退出多选、切换单本、全选、清空）、以及标签页 LRU 缓存的顺序管理。后两者都是纯逻辑，却只能通过 Provider 容器间接验证。

## Decision

- `bookshelf_state.dart`：`ViewMode` 与 `BookshelfState`；`bookshelf_notifier.dart` 以 `export` 保留原有导入路径，调用方不动。
- `bookshelf_selection.dart`：`withSelectionModeToggled` / `withBookSelectionToggled` / `withAllBooksSelected` / `withSelectionCleared`，纯函数，notifier 方法只做取值与写回。
- `bookshelf_tab_cache.dart`：`BookshelfTabCache` 独占淘汰顺序，`put` / `remove` 返回快照（复制），避免状态与缓存共享同一 Map。

## Alternatives considered

**直接改所有调用方的导入路径** —— 放弃：12 个文件里既有只引 provider 的，也有引状态与枚举的，逐个改会放大 diff；先以 `export` 保持路径，等下次真正触碰这些文件时再迁移。

**把缓存留成两个私有方法与一个顺序列表** —— 放弃：淘汰语义（最近使用、上限、删除分组）没有独立入口，测试要绕 notifier。

**把 `_loadBooks` 也拆出去** —— 放弃：它依赖仓库、prefs 与当前状态三者，是 notifier 的核心编排，拆出去只会变成需要注入一堆依赖的"服务"。

## Consequences

- `bookshelf_notifier.dart` 由 423 行降到 304 行；library 已无超 400 行文件。
- 多选语义与缓存淘汰有独立单元测试（`bookshelf_selection_test.dart` / `bookshelf_tab_cache_test.dart`）。
- `BookshelfState.cachedBooks` 现在始终是缓存快照，历史状态不会被后续写入改动。
