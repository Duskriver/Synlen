# Agent Note: 详情页错误占位拆成 BookDetailErrorView

Status: implemented

## Problem

`book_detail_screen.dart` 在上一轮映射下沉后仍有 403 行，其中 30 行是错误占位 UI（图标 + 标题 + 消息），与屏幕的加载 / 编辑 / 保存编排无关。

## Decision

错误占位抽成 `BookDetailErrorView(message)`（单参数，纯展示）；屏幕的 `_buildErrorBody` 只做转调。

## Alternatives considered

**抽 `_bodyForBook` 分发器** —— 放弃：它要接收两个视图对象加四个控制器与回调，九参数的分发器比保留在屏幕里更浅。

**只压缩样式表达式** —— 放弃：`dart format` 会还原，且不改结构。

## Consequences

- `book_detail_screen.dart` 由 403 行降到 374 行，library 重新没有超 400 行文件。

- 错误占位可单独 pump，样式与文案逐字保留。
