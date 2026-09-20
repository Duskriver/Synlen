# Agent Note: WebView 封装按控制器与 JS 事件拆成 part 文件

Status: implemented
Archived: 2026-09-20

## Problem

`reader_webview.dart` 544 行里，三件事挤在一个库：控制器门面与回调结构（`ReaderWebViewController` / `ReaderWebViewCallbacks`）、12 个 JS 事件的注册（约 124 行重复的"取参 → 转类型 → 转调回调"），以及 WebView 宿主 State（资源拦截、主题、截图）。定位任意一件事都要在 500 行里翻。

## Decision

拆成同一库的三个文件：

- `reader_webview.dart`：WebView 宿主 State 与 `defaultSettings`。
- `reader_webview_controller.dart`（part）：`ReaderWebViewController` 与 `ReaderWebViewCallbacks`。
- `reader_webview_js_handlers.dart`（part）：顶层函数 `_registerJavaScriptHandlers(state, controller)`，把 JS 事件转成宿主回调。

用 part 而不是独立库：控制器持有 `_ReaderWebViewState`，宿主 State 的私有成员与 JS 注册函数互相需要，独立库会把它们逼成公开 API。

## Alternatives considered

**只拆 JS 事件注册** —— 放弃：544 → 420 行仍超限，且控制器与回调结构本来就不属于宿主 State。

**让 JS 注册函数成为公开 API 的独立库** —— 放弃：它只服务这个 State，公开后等于把 WebView 内部协议暴露给全仓库。

**把 JS 事件协议下沉到 data 层** —— 放弃：参数解析用的是 `Rect` / `WebResourceResponse` 等 Flutter 类型，下沉会把 UI 类型带进 data 层。

## Consequences

- 由 1 个 544 行文件变成 3 个不超过 324 行的文件，reader 的超 400 行清单少一项。
- 事件解码通过独立的 `ReaderWebEvent` 校验后分发；协议、浏览器与设备验证见[渲染契约](2026-09-19-reader-workflow-render-contract.md)。
- part 共享同一个库，`_ReaderWebViewState` 的私有成员不跨库暴露。
