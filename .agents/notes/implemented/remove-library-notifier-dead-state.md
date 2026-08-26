# 删除 LibraryNotifier 的死状态族(LibraryState / LibraryLoaded / LibraryError)

Status: implemented

## Problem

- `libraryProvider` 的全部生产用法只有 3 处 `.read(libraryProvider.notifier)`(`lib/src/global_share_handler.dart:71`、`lib/src/features/library/presentation/mixins/library_actions_mixin.dart:48,333`),**没有任何地方读取它的 state**(watch/read `libraryProvider` 本体为零)。
- 因此 `LibraryState` sealed 族(`library_notifier.dart:46-56`)整体无消费方:书架 UI 数据源实际是 `bookshelfProvider`(26 处引用)。这是被 bookshelfProvider 取代后的遗留;上一轮清理(6c537ae)已删除族内同样无引用的 `LibraryInitial`/`LibraryLoading`。
- 死状态不是零成本:`build()`/`_loadBooks()` 每次 provider 构建都做一次全表 `getAllBooks()`;`importPipelineStream`/`importLibraryFromFolder` 尾部的 `await refresh()` 再查一次全表并把结果写入无人读的 state。而调用方(global_share_handler:87、library_actions_mixin:66,361)在流结束后已各自调用 `bookshelfProvider.notifier.refresh()` 完成真正的 UI 刷新。

## Proposal

- 删除 `LibraryState` / `LibraryLoaded` / `LibraryError` / `_loadBooks` / `refresh`。
- **顺带删除零调用方的 `deleteBook`**(`rg '\.deleteBook\('` 全仓无一处调用它;真实删除路径是 `bookshelf_notifier.dart:330` 直连 `_importService.deleteBook`,此实现是同一编排的重复副本),并随之移除仅被它使用的 `fpdart` 与 `shelf_book_repository_provider.dart` import。
- `LibraryNotifier.build()` 改为 `void build() {}`(codegen 生成 `Notifier<void>`),导入编排方法(`importLibraryFromFolder` / `importPipelineStream`)保持不变,方法尾部 `await refresh()` 一并删除。
- 重跑 `dart run build_runner build --delete-conflicting-outputs`。

## Why not keep it

保留的真实成本:每次导入流水线多一次全表查询 + 两套"书架数据源"并存误导后来者(libraryProvider 的 state 看起来像数据源,实际是 bookshelf)。删除的风险:无消费方,行为等价;唯一回退成本是想让 libraryProvider 持有状态时需重建——但现行架构已选 bookshelf,不该走回头路。

## Acceptance criteria

- `rg '\bLibraryState\b|\bLibraryLoaded\b|\bLibraryError\b' lib` 清零;`rg 'deleteBook' lib/src/features/library/application/library_notifier.dart` 清零。
- `flutter analyze` 零 error 零 warning;全量 `flutter test` 全绿。
- 手测一次导入:进度条正常、结束后书架刷新正常(验证 bookshelf 刷新链路不依赖被删的 refresh)。

## Risks

- codegen 从 AsyncNotifier 变 Notifier,需确认 `_$LibraryNotifier` 生成形态;`import '...app_database.dart'` 等只为状态类引入的 import 需同步清理。
