# Agent Note: 保留现有阅读与数据库技术栈，按证据评估净收益

Status: proposed

## Problem

Synlen 从 Lumina 分化后改用 Readium 与 drift，增加了跨平台桥接、数据迁移和本地依赖补丁。需要区分三件事：选型提供了什么能力，项目通过实现与测试兑现了什么收益，以及哪些性能和维护成本仍没有横向证据。采用通用 SDK 或 SQLite 本身不能证明应用更快、更稳定或维护更便宜。

## Proposal

建议保留 Readium 与 drift。对 EPUB/TXT 阅读、词句学习和持续保留用户数据的目标，Synlen 的底座更适合长期演进；这是基于当前能力边界的工程判断，不是全面胜过 Lumina 的测量结论。drift 的工具链适配与迁移可验证性已有明确收益；Readium 将通用排版交给 SDK 的方向合理，但引入与维护的总成本是否已收回、性能是否更好，尚无共同样本的横向证据。

本次基线为 Synlen `f1c602d1b7dec184008ecf4f68d749a7b40a1186` 与 [Lumina `32f2aa4`](https://github.com/MilkFeng/lumina/commit/32f2aa42c4a8efe153061076a7dac1f5bfdf979b)，核对日期为 2026-09-26。上游更新如何选择吸纳由[独立提案](../process/2026-09-26-selective-lumina-upstream-adoption.md)讨论；本篇只评估技术栈是否值得保留。

### 阅读内核：所有权更合理，维护工作仍然存在

| 维度 | 可确认的收益 | 代价与边界 |
|---|---|---|
| 排版与 EPUB 兼容 | 三 iframe 分页、CSS 兼容补丁、跨章导航与脚注排版的所有权交给 Readium；应用集中处理内容准备、学习与会话。 | SDK 升级和复杂 EPUB 仍需验收；并未消除 WebView 差异。 |
| 阅读位置 | 保存完整 Locator，使用可见短文本与元素位置辅助恢复，能承载主题重排和重开的定位信息。 | 插件需补充定位采样、资源身份与过期回执过滤；布局变更采用拆除视口并重开的路径。 |
| 学习交互 | 小型学习脚本提取词句，宿主与原生共同校验会话和资源归属。 | Dart、JavaScript、Kotlin、Swift 都参与生命周期与桥接，不能把 SDK 当作无需维护的黑盒。 |

以上边界来自 [Readium 引擎决策](../../implemented/architecture/2026-09-20-readium-reader-engine.md)与[插件接口说明](../../../../third_party/flutter_readium/UPSTREAM.md)。该决策记录的 Android / iOS 重排、重开、长表和 SVG 验收支持当前实现的可用性；它们是历史验证，不能当成本次重新执行或任意 EPUB 兼容保证。

当前维护 [flutter_readium 0.5.0 本地分支](../../../../third_party/flutter_readium/UPSTREAM.md)和 [Android Navigator 3.3.0 本地模块](../../../../third_party/flutter_readium/android/readium-navigator/UPSTREAM.md)。普通拖动的落页判断与正文就绪时序分别需要[手势修补](../../implemented/bug-fix/2026-09-20-readium-reader-gestures.md)和[位置回执修补](../../implemented/bug-fix/2026-09-20-android-reader-ready-latency.md)。固定来源、可重放补丁和测试降低了维护风险，但每次 SDK 升级仍要复核补丁，不以 vendored 源码或补丁行数直接判断成本高低。

[出版物准备](../../implemented/architecture/2026-09-20-readium-reader-engine.md)为 TXT 生成派生 EPUB，并校验 EPUB 的长度、CRC 与活动内容。它获得统一阅读路径，也增加了缓存与文件准备工作。[旧数据兼容决策](../../implemented/bug-fix/2026-09-21-preserve-legacy-reader-data.md)记录了初次接入遗漏旧库迁移、在 9 月 21 日补齐的事实；旧章节坐标只能近似转换，不能承诺跨引擎同字恢复。

Readium 的 EPUB 排版底层仍使用 WebView：Android 的 [R2BasicWebView](../../../../third_party/flutter_readium/android/readium-navigator/src/main/java/org/readium/r2/navigator/R2BasicWebView.kt)继承系统 WebView，iOS 插件也通过 WebKit 桥接。使用原生 SDK 不等于采用另一种原生文本排版器，不能据此断言速度或内存占优。

Lumina 的[渲染器](https://github.com/MilkFeng/lumina/blob/32f2aa42c4a8efe153061076a7dac1f5bfdf979b/web_assets/controller.js/renderer/renderer.ts)与[主题管线](https://github.com/MilkFeng/lumina/blob/32f2aa42c4a8efe153061076a7dac1f5bfdf979b/web_assets/controller.js/renderer/theme_manager.ts)直接掌握 DOM、CSS 和手势。对较轻的 EPUB 阅读业务或独特样式，它具有定制直接性的优势；代价是自行承担通用排版、资源兼容与位置模型。这解释了两种取舍，不证明上游当前兼容性更差。

### 数据库：明确收益来自选型与实施共同作用

[迁移决策](../../implemented/architecture/2026-08-10-migrate-isar-to-drift.md)记录了旧 Isar 3.1 generator 与新代码生成工具链冲突的动机。Lumina 当前使用 [Isar Community 3.3.2](https://github.com/MilkFeng/lumina/blob/32f2aa42c4a8efe153061076a7dac1f5bfdf979b/pubspec.yaml)，其[维护分支](https://github.com/isar-community/isar-community)聚焦 v3 修复与小更新；不能沿用旧 Isar 停更的理由，直接否定今天的上游选型。

drift 提供[显式版本迁移](https://drift.simonbinder.eu/migrations/)与[可注入内存或文件数据库的测试方式](https://drift.simonbinder.eu/testing/)。Synlen 的 [AppDatabase](../../../../lib/src/core/database/app_database.dart)把 schema 1/2→3 的列变化和旧进度转换放进事务；[迁移回归](../../../../test/database/migration_test.dart)使用真实旧 SQL 结构检查数据保留、失败回滚及重复打开。收益在于数据演进可以明确描述并验证，不是换包后自动得到正确迁移。

Synlen 的 [LibraryBookStore](../../../../lib/src/features/library/data/library_book_store.dart)让书目与清单双写、恢复合并共用同一事务。Lumina 的 [`_saveTransaction`](https://github.com/MilkFeng/lumina/blob/32f2aa42c4a8efe153061076a7dac1f5bfdf979b/lib/src/features/library/data/services/epub_import_service.dart#L160-L185)仍先后调用两个仓库，失败后删除书目补偿。这是当前实现质量的差异；[Isar 也提供 ACID 事务](https://isar-community.dev/v3/transactions.html)，并非做不到原子双写。文件补偿、备份合并、删除语义和针对性回归属于[本地写入设计](../../implemented/architecture/2026-09-19-library-write-consistency.md)，不能全部记作 SQLite 的收益。

drift 的成本也很具体：清单中的 spine、TOC、资源清单与阅读位置通过 JSON TypeConverter 存储；书目与清单没有外键，完整性由应用编排维护；迁移 SQL、Companion 和视图映射需要持续维护，生成器仍受[工具链约束](../../implemented/process/2026-08-11-pin-toolchain-and-dependency-ceiling.md)。Lumina 的 [embedded 清单对象](https://github.com/MilkFeng/lumina/blob/32f2aa42c4a8efe153061076a7dac1f5bfdf979b/lib/src/features/library/domain/book_manifest.dart)与[自动 schema 迁移](https://isar-community.dev/v3/recipes/data_migration.html)对当前对象存取较直接。双方都能完成藏书业务，没有证据证明数据库读写速度或内存谁更优。

现有迁移回归验证 SQLite schema 升级，不是旧 `.isar` 文件迁入 SQLite。[最初迁移决策](../../implemented/architecture/2026-08-10-migrate-isar-to-drift.md)按当时无线上用户的前提删除了 IsarMigrator；不能把今天的回归扩大为旧 Isar 数据迁移保证。

### 共同技术与尚未测清的收益

Flutter 与 Riverpod 是两边共有的主要技术，不能把它们算成 Synlen 换栈的成绩。[封面读取替代](../../implemented/simplification/2026-09-26-replace-rust-cover-reader.md)移除只服务封面的自有 Rust / FFI，以 Dart 有界读取保留导入能力；该决策以维护简化为理由，不表示 Dart 解压更快。

[9 月 20 日的就绪优化记录](../../implemented/bug-fix/2026-09-20-android-reader-ready-latency.md)中，767.5 ms 首开与 294.0 ms 重开来自单台 Android 真机上的合成 EPUB，是 Readium 栈内优化后的中位数，未测 Lumina。它不能证明换内核提速，也不能外推冷启动、图片密集书籍或 iOS。完整冷启动、导入、翻章和内存基线仍需按[性能手册](../../../../docs/cookbook/measuring-performance.md)补齐。

维护成本也没有同口径统计。SDK 排版所有权减少自研工作，桥接与本地分支增加集成工作；目前可以判断责任划分更适合 Synlen 的目标，不能宣布累计投入已低于继续维护 Lumina 引擎。

### 与已有决策的关系

取代检查覆盖了活跃的数据库迁移、Readium 接入、旧数据保留、手势、就绪与性能笔记。本篇评估选择的收益与证据边界，不改变它们持有的运行契约，也不取代或归档任何已有决策；[选择吸纳上游](../process/2026-09-26-selective-lumina-upstream-adoption.md)继续持有更新策略。

## Alternatives considered

**回到 Lumina 的阅读与数据库实现。** 不建议：没有当前栈不满足产品目标的证据，回迁还需重新处理学习交互、TXT、Locator 与用户数据；已经存在的沉没成本不是唯一理由，实际迁移风险与能力需求才是。

**宣布 Synlen 全面胜出。** 不成立：上游当前数据库仍有维护，嵌套对象与阅读样式定制具有直接性；本地性能和总维护成本缺少横向测量。

**仅按最新版本或技术名重新换栈。** 不建议：不能解决具体缺口，会再引入数据、定位与平台生命周期迁移。收益应以能交付的能力和可复现结果判断。

## Verification

2026-09-26 执行 `flutter test test/database/migration_test.dart test/features/library/data/library_book_store_test.dart test/features/reader/application/readium_session_test.dart --reporter expanded`，23 项通过。前两组验证真实 SQLite 的迁移与事务路径；ReadiumSession 使用 fake gateway 验证会话协议，不是新一轮 Android / iOS 设备验收，也不是与 Lumina 的 A/B。此次仅新增研究笔记，没有产品代码改动。

## Acceptance criteria

- 保留现有栈的判断明确区分框架能力、本地实现质量和未测假设；引用历史验收时保留设备、样本与范围。
- 如需比较性能，在相同设备、构建配置、WebView、书籍与缓存状态下测量完整可用正文、位置恢复、峰值内存和交互，分别报告 EPUB 与 TXT 能力差异，不以视口创建完成代替阅读就绪。
- 如需判断维护净收益，核对真实缺陷修复、SDK 升级及补丁重放所需工作；Rust 留存价值作为独立候选，以实际调用方与替代成本判断。

## Risks

本地回归更充分不能证明框架天然更可靠；跨语言修补也不能仅凭存在就判定选型失败。复杂 EPUB、低端设备和长期升级仍可能暴露新成本。此提案不授权回迁、删依赖或改写已有数据契约，未测部分保留为不确定性。
