# Agent Note: Readium 升级保留旧书库与阅读坐标

Status: implemented

## Problem

v0.3.5 的数据库使用 schema 2，Readium 接入时 schema 3 拒绝旧库升级，旧备份的章节坐标也被忽略。已有用户需要保留藏书与进度，清除数据才能启动不满足升级要求。范围与验收记录在 [issue 49](https://github.com/Duskriver/Synlen/issues/49)。

## Decision

`AppDatabase` 在同一事务内支持 schema 1、2 升级到 3：补格式列、将原始章节序号、章内比例和全书百分比复制到 `progress`，再重建书架表移除旧列。主键、元数据、路径、清单、分组与学习缓存保留；任一步失败回滚，不清库。

`BookProgress` 明确区分完整 Locator 与 `legacy` 坐标，旧数据序列化不伪造文本锚点。`ReadiumSession` 打开出版物后，根据旧清单的章节路径匹配实际阅读资源，以原章内比例近似定位。无法匹配时报告加载失败并保留原值；匹配章节就绪后才由原生 Locator 替换旧坐标。跨引擎不能保证同字定位。

备份格式 2 携带完整 Locator 或尚未恢复的旧坐标；恢复仍接受格式 1 的章节字段，未打开的书也可再次导出。旧客户端会按已有版本检查拒绝格式 2，避免将新进度静默读成书首。

本决策部分取代[Readium 引擎决策](../architecture/2026-09-20-readium-reader-engine.md)中无存量用户、不迁移旧库的前提；其排版、会话和定位所有权保持有效。[备份版本分派](../feature/2026-09-09-backup-version-decoders.md)继续持有高版本拒绝规则。

## Alternatives considered

**清库后重新导入**：丢失书架组织、缓存与进度，无法满足已有用户升级需求。

**迁移时直接生成完整 Locator**：数据库缺少 Readium 阅读顺序与文本锚点，无法证明精确位置。保留旧坐标直到出版物打开，才能核对实际资源。

**只保留书架百分比、从书首打开**：书架显示看似保留，实际阅读位置却丢失，且随后可能覆盖旧进度。

## Consequences

迁移不改写书籍、封面、偏好或安全存储文件。旧比例只能提供近似落点，原生重新分页可能造成页内偏移；成功打开后使用完整 Locator。损坏或缺失章节不会静默归零，需要修复原书或清单。

回归以旧 SQL 结构验证 schema 1、2 的数据保留、事务回滚、重复打开与新定位写入；备份覆盖旧格式恢复及新旧坐标再次导出；会话验证按路径匹配而非照搬阅读顺序下标。Android 阅读 smoke 的 `SYNLEN_LEGACY_MIGRATION_PROBE` 使用真实导入内容与旧版列，重开触发生产迁移，并验证近似落点、完整定位保存和重开。

2026-09-21，226 项数据库、library 与 reader application 定向回归通过；Android ARM64 模拟器的迁移探针通过 TXT 旧章节近似恢复、原生分页、重排、退出重开和 EPUB 阅读。该证据不覆盖所有 EPUB 排版和厂商设备。
