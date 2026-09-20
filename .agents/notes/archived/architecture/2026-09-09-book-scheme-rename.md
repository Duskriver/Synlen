# Agent Note: 虚拟域从 epub:// 改为 book://

Status: implemented
Archived: 2026-09-20

## Problem

`EpubWebViewHandler.virtualScheme` 是 `'epub'`，但该虚拟域同时供给 EPUB 与 TXT 章节（TXT 被包装成 XHTML 后经同一虚拟域交给渲染引擎）。这是[格式中立命名提案](../../implemented/architecture/2026-09-09-format-neutral-book-naming.md)的第三步。

## Decision

`virtualScheme` 由 `'epub'` 改为 `'book'`；同步改 Dart 侧字面量（`link_handling_mixin` 的书内链接判定）、JS 资源（`theme_manager.ts` 的字体 URL）、l10n 的 ARB 描述与 `docs/` 中的现状描述，并重跑 `dart run tool/build_web_assets.dart` 与 `flutter gen-l10n` 更新生成物。

## Alternatives considered

**保留 `epub://`** —— 放弃：TXT 章节走同一域，名字继续撒谎。

**只改 Dart 常量** —— 放弃：JS 侧字体 URL 与书内链接判定各自写着字面量，漏改会让字体与内部跳转失效（只在阅读器运行时可见）。

## Consequences

- `rg 'epub://' lib web_assets/controller.js docs` 为空（生成物已重建）。
- 测试里断言 URL 的用例同步改为 `book://`；全量测试绿。
- 提案三步骤已全部交付（Dart 类型名、原生通道方法名、虚拟域）；剩余验证只有真机冒烟。
