# Agent Note: WebView 双通道资源管线合并

Status: implemented

## Problem

`lib/src/features/reader/application/book_webview_handler.dart` 的两条公开方法曾共享完全相同的解析管线——缓存查找 → `isFontRequest` → `_readFontFile` → `_readFileFromEpub` → `_cacheResource`：`handleRequest` 把结果包装成 `WebResourceResponse`，`handleRequestWithCustomScheme` 包装成 `CustomSchemeResponse`。同一约束（书内脚本剥离要对两个入口同时成立）靠注释在两个方法里重复声明，改 EPUB 资源读取规则必须同步两处。

## Decision

抽出私有 `_resolveResource`，承载共享五步管线，返回 `Either<String, _ResolvedResource>`（错误消息 vs 字节 + MIME + 是否缓存命中）。两个公开方法只留各自平台的响应包装与错误形态，签名与对外行为不变：

- Android `handleRequest`：成功带 `_headers`，reasonPhrase 区分 `'OK (Cached)'`/`'OK'`（靠 `_ResolvedResource.fromCache`）；资源错误统一 404，字体错误回退通用 `'Font not found'` 文案（`isFontRequest(requestUrl)` 判定）；外层 catch 返回 500 + `'Error: $e'`。
- iOS `handleRequestWithCustomScheme`：错误统一 `text/plain` 且暴露真实错误消息；外层 catch 文案 `'Error reading file: $e'`。

调用点共四处：`reader_webview.dart:181,192`（两平台 WebView 回调）、`widgets/footnot_popup_overlay.dart:95`（脚注弹层）、`image_viewer.dart:105`（图片查看器），均只依赖公开签名，重构不影响它们。

## Alternatives considered

**两个平台回调合一** —— 落败：Android 与 iOS 回调签名不同，无法合一；能合的只有内部管线。

**不动** —— 落败：改 EPUB 资源读取规则要同步两处，注释已经在重复声明同一条约束，约束应由结构承担而不是由注释。

## Consequences

reader 现有测试与新增管线测试（`test/features/reader/application/book_webview_handler_test.dart`）通过；`flutter analyze` 零 error 零 warning。改 EPUB 资源读取规则现在只需动 `_resolveResource` / `_readFileFromEpub` 单点。

风险：两平台错误响应语义未来分叉。包装层留在各公开方法内，分叉只影响包装代码，不影响共享管线。

## Dev Note

None.
