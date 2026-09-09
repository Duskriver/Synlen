# Agent Note: 详情编辑表单改为只接收主键与封面路径

Status: implemented

## Problem

`BookDetailEditBody` 持有整行 `ShelfBook`，实际只用 `id`（封面 hero tag）与 `coverPath`——[窄视图类型笔记](2026-09-09-presentation-shelf-book-view.md)里的又一处可独立迁移的依赖。

## Decision

表单改吃 `EditableBookView`（`({int id, String? coverPath})`，定义在表单文件里）；详情页在构造处映射。门禁存量名单随之删掉该文件。

## Alternatives considered

**与 `BookDetailViewBody`（11 个字段）一起改** —— 放弃：后者接近完整视图类型，属于提案第一批的整体范围，留待与 `BookshelfState` 同批。

## Consequences


- presentation 依赖 drift 行类型的存量从 7 个文件降到 6 个。

- 表单的控制器所有权、校验回调节奏与展示内容逐字保留。
