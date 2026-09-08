# Agent Note: 书目视图类型与映射收进 domain / application

Status: implemented

## Problem

上一轮把详情两个组件改为只吃视图记录类型，但映射内联在 `book_detail_screen` 里，屏幕因此涨到 414 行；映射位置也违背[窄视图类型提案](../../proposed/architecture/2026-09-09-presentation-shelf-book-view.md)的约定（映射属于 application）。

## Decision

视图类型（`DetailBookView` / `EditableBookView`）下沉 `library/domain/book_views.dart`；映射函数 `detailBookView` / `editableBookView` 放 `library/application/book_view_mapper.dart`；两个详情组件与屏幕改为引用它们。

## Alternatives considered

**映射留在 presentation 的文件里** —— 放弃：presentation 会重新握住 drift 行类型，存量闸门会拒绝。

**等列表侧迁移时一起做** —— 放弃：屏幕已越过 400 行，且映射位置是提案的硬要求，先做能立刻消掉这两处问题。

## Consequences

- `book_detail_screen.dart` 由 414 行降到 403 行；映射有独立单测（`book_view_mapper_test.dart`）。

- presentation 依赖 drift 的存量保持 5 个文件（映射移出后没有新增）。
