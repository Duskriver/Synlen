# Agent Note: 渲染器控制器与状态栏浮层从 reader_renderer 拆出

Status: implemented

## Problem

`reader_renderer.dart` 580 行里混着三件事：`ReaderRendererController`（`ReaderViewport` 的生产实现，155 行）、三 iframe 渲染 widget 与手势，以及底部状态栏浮层（73 行）。此外控制器里 `preloadCurrentChapter` / `preloadNextChapter` / `preloadPreviousChapter` 三个公开方法除被 `preloadChapter` 分发调用外没有任何调用方，三者代码逐字相同、只有 iframe 名不同。

## Decision

- `reader_renderer_controller.dart`（part）：控制器移出主文件；三个重复的预载方法收敛为 `preloadChapter` 内的槽位到 iframe 名映射，删除三个无调用方的公开方法。
- `widgets/reader_status_bar_overlay.dart`：底部状态栏浮层成为独立 widget，接口只有两个 `ValueListenable` 与两个布尔。
- 预载参数改用 `jsonEncode` 生成 JSON 数组：原先手工拼引号，锚点含引号时会产出非法 JSON。

用 part 而不是独立库：控制器持有 `_ReaderRendererState`，拆成独立库会把宿主 State 的私有成员逼成公开 API。

## Alternatives considered

**保留三个公开预载方法** —— 放弃：它们是只被内部分发调用的死接口，留着既扩大 API 面又要求三处同步修改。

**把状态栏浮层留在主文件** —— 放弃：它只依赖两个 `ValueListenable` 与两个布尔，抽出来后主文件才降到 400 行以内。

**让浮层自己订阅 provider** —— 放弃：内容由渲染器通过 `ValueListenable` 推送以避免整树重建，改成订阅 provider 会破坏这个性能约定。

## Consequences

- `reader_renderer.dart` 由 580 行降到 361 行，reader 的超 400 行清单只剩 `reader_screen.dart`。
- `ReaderRendererController` 的公开面少三个方法，预载路径只有一处实现。
- 行为不变；`jsonEncode` 只让含特殊字符的锚点从"产出非法 JSON"变为正确转义。
