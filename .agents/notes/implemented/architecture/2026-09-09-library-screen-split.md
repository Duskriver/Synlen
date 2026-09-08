# Agent Note: 书架主视图拆出标签页视图与网格

Status: implemented

## Problem

`library_screen.dart` 454 行里，屏幕 State 同时管三件事：标签控制器与书架状态的同步、主视图骨架（顶栏 + TabBarView + 多选操作条）、网格渲染（空态、两种视图模式的网格参数、点击与长按语义）。后两者都是纯渲染，却因为写在 State 私有方法里而无法单独 pump。

## Decision

- `LibraryTabView`（`presentation/widgets/library_tab_view.dart`）：顶栏、标签页内容与多选操作条；自己读 `bookshelfProvider` 做排序面板、全选与退出多选，只把需要宿主弹窗的三件事经回调交回：编辑分组、移动分组、删除选中。
- `LibraryItemsGrid`（`presentation/widgets/library_items_grid.dart`）：空态、网格参数与点击 / 长按语义，读 `bookshelfProvider` 处理选择与跳转。
- `library_screen.dart` 保留标签控制器同步、`AsyncValue` 三态与选择态遮罩。

## Alternatives considered

**只拆网格** —— 放弃：454 → 380 行仍超限，且主视图骨架本来就可以独立于屏幕 State 渲染。

**把标签控制器同步也抽成独立类** —— 放弃：它需要 `vsync`、`ref` 与 State 生命周期三者配合，抽出去只会换来一层转发；等它有第二个使用方再说。

**让子 widget 接更多回调（排序、选择）** —— 放弃：这些动作只依赖 provider，让子 widget 自己读比层层传参更窄。

## Consequences

- `library_screen.dart` 由 454 行降到 247 行，library 的超 400 行清单少一项。
- `LibraryItemsGrid` 有 widget test 覆盖空态、网格项与紧凑模式。
- 回调接口只有 3 个（编辑分组、移动分组、删除选中），其余交互不跨组件边界。
