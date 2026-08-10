# ADR-0002: 数据库从 Isar 迁移到 drift

2026-08-10 决定：将数据持久层从 Isar（3.1.0，2023 年后停更）迁移到 drift（2.34.x，活跃维护的 SQLite ORM），并提供一次性数据迁移。

## Status

accepted

> **2026-08-11 更新**：本项目尚处于开发阶段，**从未对外发布**（v0.2.3 及之前均为内部开发版本，无任何线上用户），设备上不存在需要抢救的存量 `.isar` 数据。因此本 ADR 中的"一次性数据迁移"**无需执行**：`isar` / `isar_flutter_libs` 依赖、`lib/src/core/database/legacy/`（旧模型 + `IsarMigrator`）与 `test/database/isar_migration_test.dart` 应直接删除，无需经过"先发布迁移版本、下个版本再移除"的过渡期。

## Considered Options

1. **保留 Isar + 降级 build_runner**：Isar 停更 3 年，其 `isar_generator` 只支持 source_gen ^1.2，与 riverpod_generator 4.x（source_gen 3+）**无法共存**；且与新 Dart/Flutter 工具链的兼容只会越来越差。放弃。
2. **drift（选定）**：活跃、知名（Simon Binder 维护）、纯 SQLite（稳定可靠）、`drift_dev` 生成器与最新 codegen 链兼容。作为 Isar 的上位替代。
3. **自造轮子**：自行实现持久层。工作量远超收益，且 SQLite 封装是成熟领域，放弃。

## Consequences

- 7 个 Isar 集合改为 drift 表：ShelfBook / ShelfGroup / BookManifest / WordExplanation / WordPronunciation / SentenceAnalysis / SentencePronunciation。
- BookManifest 的嵌套对象（SpineItem/TocItem/Href/ManifestItem）改为纯 Dart 模型，以 JSON 存入 text 列（TypeConverter）。
- 业务规则上移（repositories 变薄），数据类不可变（copyWith/Companion 写入）。
- **用户数据迁移**：`lib/src/core/database/legacy/`（旧 Isar 模型 + isar runtime 依赖）仅用于一次性迁移（`IsarMigrator`），迁移成功后删除该目录与 isar/isar_flutter_libs 依赖。
- drift 数据类作为领域模型使用（presentation 层可感知），后续可考虑下沉 core 或引入 DTO 层。
