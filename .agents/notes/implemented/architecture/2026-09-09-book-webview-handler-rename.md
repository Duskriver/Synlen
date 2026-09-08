# Agent Note: EpubWebViewHandler 改名为 BookWebViewHandler

Status: implemented

## Problem

`EpubWebViewHandler` 按 `BookFormat` 分发 EPUB 与 TXT 的内容供给（TXT 章节经 `book://` 虚拟域交给同一渲染引擎），名字却写着 Epub。这是[格式中立命名提案](../../proposed/architecture/2026-09-09-format-neutral-book-naming.md)第一步的第二半。

## Decision

类名与文件改为 `BookWebViewHandler` / `book_webview_handler.dart`，测试文件同步改名；调用方（reader 的 session factory、渲染器、WebView 封装、脚注与图片组件）与文档一并更新。

## Alternatives considered

**保留旧名** —— 放弃：名字继续暗示 EPUB 专属，而 TXT 章节走的就是它。

**与虚拟域改名合并** —— 放弃：虚拟域牵动 JS 资源与生成物，已在独立提交完成；类名改名是纯 Dart。

## Consequences

- `rg 'EpubWebViewHandler|epub_webview_handler' lib test docs` 为空。

- 纯改名，行为不变；全量测试与门禁通过。

- 格式中立命名的三步骤至此全部落地，剩余只有真机冒烟（EPUB 与 TXT 各导入、翻章、字体、外链）。
