# Agent Note: ReaderRenderer 用回调值对象收窄接口

Status: implemented

## Problem

`ReaderRenderer` 的构造参数有 23 个，其中 11 个是把 JS 事件逐个转发给 `ReaderWebView` 的回调；渲染器内部还要把这 11 个重新拼成一个 `ReaderWebViewCallbacks`（已有的值对象）再传给 WebView。接口面积与实际职责不符：调用方每加一个事件都要改渲染器签名。

## Decision

`ReaderRenderer` 只收一个 `callbacks`（`ReaderWebViewCallbacks`）加渲染相关的 12 个参数；内部用 `callbacks.withTap(_handleTapZone)` 注入自己的区域点击处理，再交给 `ReaderWebView`。`ReaderWebViewCallbacks` 增加 `withTap`，其余字段原样复制。

## Alternatives considered

**保持 11 个独立参数** —— 放弃：事件是成组出现的，拆开只会让渲染器成为转发层。

**让调用方把 `onTap` 也一起传** —— 放弃：区域点击依赖渲染器的 `MediaQuery` 与翻页会话，必须由渲染器接管。

**给 `ReaderWebViewCallbacks` 加 `copyWith`** —— 放弃：只有"换点击回调"这一种用法，`withTap` 更明确且不会让人误以为其它字段可变。

## Consequences

- `ReaderRenderer` 参数由 23 个降到 13 个，新增 JS 事件只改值对象与调用方。
- 行为不变：事件名、参数顺序与 `onTap` 由渲染器接管的方式逐字保留。
