# Agent Note: 数据库从 Isar 迁移到 drift

Status: implemented

## Problem

数据持久层原用 Isar 3.1.0，2023 年后停更；其 `isar_generator` 只支持 `source_gen ^1.2`，与 `riverpod_generator 4.x`（`source_gen 3+`）无法共存，且与新 Dart / Flutter 工具链的兼容只会越来越差。

## Decision

持久层用 drift（2.34.x，活跃维护的 SQLite ORM）。7 个集合改为 drift 表：ShelfBook、ShelfGroup、BookManifest、WordExplanation、WordPronunciation、SentenceAnalysis、SentencePronunciation。`BookManifest` 的嵌套对象（`SpineItem` / `TocItem` / `Href` / `ManifestItem`）改为纯 Dart 模型，以 JSON 存入 text 列（TypeConverter）。

**无需一次性数据迁移**：项目从未对外发布（v0.2.3 及之前均为内部开发版本，无线上用户），设备上不存在需要抢救的存量 `.isar` 数据。因此旧 Isar 模型、`IsarMigrator` 与迁移测试直接删除，不经过"先发布迁移版本、下个版本再移除"的过渡期。

## Alternatives considered

**保留 Isar + 降级 build_runner** —— 放弃：Isar 停更 3 年，且降级会锁死整条 codegen 链。

**自造持久层** —— 放弃：SQLite 封装是成熟领域，工作量远超收益。

## Consequences

- 业务规则上移，repository 变薄；数据类不可变（`copyWith` / `Companion` 写入）。
- drift 数据类直接作为领域模型使用（presentation 层可感知）；如果日后需要隔离，可下沉 `core` 或引入 DTO 层。
- schema 变更走 drift 的单调版本号，见 `lib/src/core/database/app_database.dart`。
