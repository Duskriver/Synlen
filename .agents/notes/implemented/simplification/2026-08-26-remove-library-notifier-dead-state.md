# Agent Note: 删除 LibraryNotifier 的死状态族

Status: implemented

## Problem

`libraryProvider` 的全部生产用法只有 3 处 `.read(libraryProvider.notifier)`，**没有任何地方读取它的 state**。因此 `LibraryState` sealed 族（`LibraryLoaded` / `LibraryError`）整体无消费方：书架 UI 的数据源实际是 `bookshelfProvider`。这是被 `bookshelfProvider` 取代后的遗留。

死状态不是零成本：`build()` / `_loadBooks()` 每次 provider 构建都做一次全表 `getAllBooks()`，导入流水线尾部再查一次全表并把结果写进无人读的 state；而调用方在流结束后已各自调用 `bookshelfProvider.notifier.refresh()` 完成真正的 UI 刷新。

## Decision

删除 `LibraryState` / `LibraryLoaded` / `LibraryError` / `_loadBooks` / `refresh`，并顺带删除零调用方的 `deleteBook`（真实删除路径由 `bookshelf_notifier.dart` 经 `BookDeletion` 编排，此处是同一编排的重复副本），随之移除仅被它使用的 `fpdart` 与 `shelf_book_repository_provider.dart` import。`LibraryNotifier.build()` 改为 `void build() {}`，导入编排方法保持不变。

## Alternatives considered

**保留状态族** —— 放弃：两套"书架数据源"并存会误导后来者（`libraryProvider` 的 state 看起来像数据源，实际是 `bookshelfProvider`），且每次导入多一次全表查询。

## Consequences

- `rg '\bLibraryState\b|\bLibraryLoaded\b|\bLibraryError\b' lib` 清零。
- 回退成本：若日后要让 `libraryProvider` 持有状态需重建——但现行架构已选 `bookshelfProvider`，不该走回头路。
- codegen 从 `AsyncNotifier` 变 `Notifier`，需确认 `_$LibraryNotifier` 生成形态并同步清理只为状态类引入的 import。
