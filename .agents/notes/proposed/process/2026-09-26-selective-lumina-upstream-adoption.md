# Agent Note: 按问题与能力选择吸纳 Lumina 更新

Status: proposed

## Problem

Lumina 与 Synlen 仍共享部分导入、字体和藏书代码的来源，但阅读引擎、数据库与产品范围已经分化。只看发布版本或 Git 落后提交数，既可能漏掉仍影响 Synlen 的缺陷，也可能把已经被 Readium 替代的实现重新带回仓库。需要回答哪些更新值得投入，以及什么证据足以支持吸纳。

## Proposal

建议保留独立维护，按问题与能力选择吸纳上游更新。每个候选先核对当前代码是否仍有同一缺口；适用的行为和测试按 Synlen 的模块边界实现，来源记录到对应改动。[字体命名](../../implemented/bug-fix/2026-09-30-import-font-display-names.md)与[封面备份完整性](../../implemented/bug-fix/2026-09-30-preserve-backup-cover-files.md)分别落实对应候选；自有 Rust 依赖许可候选随[封面后端替代](../../implemented/simplification/2026-09-26-replace-rust-cover-reader.md)移除，不再适用。行距、封面编辑和连续滚动按产品需求选择。此文是研究建议，不表示其余改动已经获准实施。

### 调研基线与历史

2026-09-26 核对的 Synlen 基线为 `f1c602d1b7dec184008ecf4f68d749a7b40a1186`，Lumina 基线为 [`32f2aa42c4a8efe153061076a7dac1f5bfdf979b`](https://github.com/MilkFeng/lumina/commit/32f2aa42c4a8efe153061076a7dac1f5bfdf979b)。GitHub 标记的最新稳定版为 [v0.2.5](https://github.com/MilkFeng/lumina/releases/tag/v0.2.5)，发布时间为 2026-09-23 18:36 UTC，即北京时间 9 月 24 日 02:36；下表统一使用北京时间。

Synlen 的 [`3d2bc15`](https://github.com/Duskriver/Synlen/commit/3d2bc159a40d9a2498713121daa1f4d158fc8515) 在 3 月 15 日合入过上游 v0.2.3 并保留学习功能。原始 merge-base 停在 2 月 8 日，不能把因此算出的 109 个上游侧提交当作缺失更新：在两个固定基线之间执行 `git cherry <Synlen基线> <Lumina基线>`，90 个非合并提交为补丁等价，只有 16 个标为新增候选，最早从 3 月 18 日的 `56f134f` 开始。补丁等价证明改动曾被带入，不保证之后仍保留同一行为；16 个候选也不等于 16 个未实现功能。

| 时间 | 上游新增候选 | 与吸纳判断有关的内容 |
|---|---|---|
| 3 月 18 日 | [`56f134f`](https://github.com/MilkFeng/lumina/commit/56f134ff54335037357eb706cd8a9f012dc14cbf)、[`603d1ed`](https://github.com/MilkFeng/lumina/commit/603d1eda82e789c6b1ddbd63a2359ae0bc3c7fb8) | Rust 许可登记、商店与侧载构建区分、旧阅读器脚注样式；后者仅版本号。 |
| 3 月 19 日 | [`e29233b`](https://github.com/MilkFeng/lumina/commit/e29233b3ce6ad04d699ddb485deeb83dd027e775) | 旧阅读器主题与资源管线、脚注交互、设置版本显示。 |
| 9 月 18—19 日 | [`e309522`](https://github.com/MilkFeng/lumina/commit/e3095226a431f083bbd2a825a456fc9ae3ad798b)、[`0c0e146`](https://github.com/MilkFeng/lumina/commit/0c0e146654857e36186264e53e182f1ae5e29e40)、[`0857395`](https://github.com/MilkFeng/lumina/commit/085739589eeea3c172518be8c841c0231d3709fa)、[`d7febcc`](https://github.com/MilkFeng/lumina/commit/d7febcc2336c2d53e2d1a2b6480b363893e09cdf)、[`c1cc9ce`](https://github.com/MilkFeng/lumina/commit/c1cc9ce238cd4396c0e87053616adf3407319b57)、[`aaf9d2f`](https://github.com/MilkFeng/lumina/commit/aaf9d2ff78aa74a28a780d368dab43f5439a2490) | 行距及相关修复、依赖与 AGP 升级、Isar Community、版本号。 |
| 9 月 19 日 | [`9a60101`](https://github.com/MilkFeng/lumina/commit/9a601010d9aa0b8f236dd9e00a880f24513e2908)、[`f018ca4`](https://github.com/MilkFeng/lumina/commit/f018ca40e1f3cf54fa5a662ec0f12e463bff9d33) | 备份格式 2 与清空后恢复；WebDAV 浏览导入、原生字体显示名、下载进度。 |
| 9 月 20—21 日 | [`d3d9078`](https://github.com/MilkFeng/lumina/commit/d3d9078473bff9030778a0806a5e97da0f8077ce)、[`8b04838`](https://github.com/MilkFeng/lumina/commit/8b048382ac5504851cfce32653b6ebcb18e830a4) | 书架菜单与目录交互、封面编辑、刷新体验、按持久化封面路径导出。 |
| 9 月 23—24 日 | [`c5cd609`](https://github.com/MilkFeng/lumina/commit/c5cd6094cce7873f5f9585f54bfe84285eb1d6c8)、[`82c0e58`](https://github.com/MilkFeng/lumina/commit/82c0e584a2f650efdd3ae2c270acc4dda8485301)、[`32f2aa4`](https://github.com/MilkFeng/lumina/commit/32f2aa42c4a8efe153061076a7dac1f5bfdf979b) | 自研阅读器连续滚动、隐藏状态栏、滚动模式媒体点击处理。 |

### 优先修复与条件候选

**字体显示名与落盘名称。** 上游在 [`f018ca4`](https://github.com/MilkFeng/lumina/commit/f018ca40e1f3cf54fa5a662ec0f12e463bff9d33) 中通过平台查询显示名，并在[字体导入器](https://github.com/MilkFeng/lumina/blob/32f2aa42c4a8efe153061076a7dac1f5bfdf979b/lib/src/features/fonts/application/font_manager_notifier.dart#L64-L211)中处理扩展名、路径分隔符和无法命名的文件。基线的 Synlen 只为书籍查询显示名，字体仍以不透明 SAF 文档 ID 命名。本地的[字体命名决策](../../implemented/bug-fix/2026-09-30-import-font-display-names.md)共用现有原生查询并覆盖名称清理、重名与资源释放；不能直接套用上游“全部显示 unknown”的发布现象。

**封面备份完整性。** 上游 [`8b04838`](https://github.com/MilkFeng/lumina/commit/8b048382ac5504851cfce32653b6ebcb18e830a4)让导出优先使用 `coverPath`。Synlen 的基线在压缩不可用时可保留 `.gif`、`.bmp`、`.svg` 封面，但导出只枚举少数后缀。本地的[封面完整性决策](../../implemented/bug-fix/2026-09-30-preserve-backup-cover-files.md)以持久化路径选择源文件，并按书籍哈希命名备份条目，保持恢复关联；真实 ZIP 往返在空存储中验证原始字节与关联。

**Rust 依赖许可展示。** 上游 [`56f134f`](https://github.com/MilkFeng/lumina/commit/56f134ff54335037357eb706cd8a9f012dc14cbf)增加生成与应用内展示机制；Synlen 自有 Rust 后端已移除，这一候选不再适用。若引入其他原生依赖，按实际依赖处理许可信息，不复制 Lumina 的 JSON 或许可接受列表。

### 按需求选择的功能

| 能力 | 建议 | 依据与边界 |
|---|---|---|
| 行距调整 | 值得优先作为独立功能重实现。 | 上游行距及修复集中在 `e309522`、`c1cc9ce`、`aaf9d2f`。Synlen [ReadiumLayout](../../../../lib/src/features/reader/application/readium_layout.dart)没有传递行距；经现有偏好与重排机制接入更合适，需要验证字体、出版者样式和位置保持。 |
| 连续滚动 | 有价值，排在独立验证之后。 | 上游 [`c5cd609`](https://github.com/MilkFeng/lumina/commit/c5cd6094cce7873f5f9585f54bfe84285eb1d6c8)修改旧分页、手势与进度管线。Synlen 当前 `scroll: false`，应使用 Readium 的能力，并验证点词、长按句子、跨章和 Locator；不能当作只改一个开关。 |
| 封面编辑 | 藏书体验的后续候选。 | 上游[草稿与回滚服务](https://github.com/MilkFeng/lumina/blob/32f2aa42c4a8efe153061076a7dac1f5bfdf979b/lib/src/features/detail/data/book_cover_edit_service.dart)提供可参考的失败语义；Synlen 还需覆盖 TXT 封面、现有文件补偿和备份。上游服务跨 feature 直接依赖 data，不能原样搬入。 |
| 隐藏状态栏、书架菜单和目录点击 | 由具体使用问题决定。 | [`82c0e58`](https://github.com/MilkFeng/lumina/commit/82c0e584a2f650efdd3ae2c270acc4dda8485301)、[`d3d9078`](https://github.com/MilkFeng/lumina/commit/d3d9078473bff9030778a0806a5e97da0f8077ce)是体验选择；状态栏还带默认值、时钟与电量显示，不只是孤立修复。 |
| WebDAV 外部来源 | 暂不因上游提供而引入。 | 上游[客户端](https://github.com/MilkFeng/lumina/blob/32f2aa42c4a8efe153061076a7dac1f5bfdf979b/lib/src/features/external_sources/data/services/webdav_client.dart)做目录浏览与流式下载，[凭据存储](https://github.com/MilkFeng/lumina/blob/32f2aa42c4a8efe153061076a7dac1f5bfdf979b/lib/src/features/external_sources/data/services/external_source_credentials_store.dart)使用系统安全存储；这是远程导入，不是阅读进度或多端藏书同步。若有明确需求，可参考其路径与嵌套目录测试，但需接入 Synlen 的 EPUB/TXT 导入入口。 |

### 不建议直接带入的更新

上游的自研分页、WebView 主题、脚注、滚动与媒体点击修复作用于旧引擎。Synlen 的排版与定位归属由 [Readium 决策](../../implemented/architecture/2026-09-20-readium-reader-engine.md)持有，兼容问题应先在当前引擎复现；有问题时带入用例，修复落在当前所有者。

这 16 个提交中解析器的 `getAttribute(namespace: ...)` 到 `namespaceUri` 适配也不能算作缺失能力：Synlen 的 [epub_toc_parser.dart](../../../../lib/src/features/library/data/parsers/epub_toc_parser.dart)已有对应调用。更早的加密 EPUB、封面探测与 NAV/NCX 修复处于补丁等价历史中，不以旧发布条目重复提出迁移。

上游 [`9a60101`](https://github.com/MilkFeng/lumina/commit/9a601010d9aa0b8f236dd9e00a880f24513e2908)在格式预检查后清空现有藏书，再逐本恢复。Synlen 已有[备份版本分派](../../implemented/feature/2026-09-09-backup-version-decoders.md)、[旧进度兼容](../../implemented/bug-fix/2026-09-21-preserve-legacy-reader-data.md)和[恢复服务](../../../../lib/src/features/library/data/services/import_backup_service.dart)的合并与文件补偿。两者格式都叫 2 不证明可互通；不采用清空后恢复语义，也不通过同步覆盖本地 drift、TXT 或 Locator 数据契约。

[`0c0e146`](https://github.com/MilkFeng/lumina/commit/0c0e146654857e36186264e53e182f1ae5e29e40)的 Isar Community、依赖升级，以及 [`0857395`](https://github.com/MilkFeng/lumina/commit/085739589eeea3c172518be8c841c0231d3709fa)的 AGP 9 改动需要按 Synlen 的[工具链约束](../../implemented/process/2026-08-11-pin-toolchain-and-dependency-ceiling.md)独立评估。上游版本号和构建分发规则也不直接替代 Synlen 的版本与发布流程。

### 与已有决策的关系

取代检查搜索了活跃笔记中的 Lumina、上游、备份、字体、依赖与许可。没有覆盖 Lumina 选择吸纳策略的旧笔记。Readium、工具链、备份兼容和[依赖审计](../../implemented/process/2026-09-09-dependency-audit-and-dependabot.md)决策继续有效，本提案不归档或取代它们。依赖审计明确暂不接入许可扫描；自有 Rust notice 候选随后端移除撤下；若以后采用自动许可判定，应另行更新该政策。

### 开发流程与 AI 协作

以代理能否独立定位改动、取得可执行反馈、保留决策理由并控制范围来判断，Synlen 更适合长期、多轮维护。Lumina 的集中入口、已知限制和生成命令矩阵有助于首次接手；这些写法值得借鉴，不能仅凭规则数量判断优劣。

| 维度 | Lumina | Synlen 与判断 |
|---|---|---|
| 上手与检索 | [AGENTS](https://github.com/MilkFeng/lumina/blob/32f2aa42c4a8efe153061076a7dac1f5bfdf979b/AGENTS.md)集中给出模块图、架构红线、生成命令和已知缺口，CLAUDE 入口只引用它。 | [常驻入口](../../../../AGENTS.md)较短，按问题进入架构、子系统、操作手册与笔记；按需读取能控制上下文，但查找层级更多。 |
| 自动反馈 | [PR CI](https://github.com/MilkFeng/lumina/blob/32f2aa42c4a8efe153061076a7dac1f5bfdf979b/.github/workflows/flutter_ci.yml)只运行 Flutter 测试；analyze 依赖本地执行，工具链跟随 stable。 | [PR CI](../../../../.github/workflows/flutter_ci.yml)固定工具链，运行格式、analyze、Flutter、分层、文档、Android 原生、浏览器与 Rust 检查，并检查部分锁文件和生成资产漂移，提供更多可重复的纠错信号。 |
| 模块范式 | [分层约定](https://github.com/MilkFeng/lumina/blob/32f2aa42c4a8efe153061076a7dac1f5bfdf979b/AGENTS.md#layering-rules)允许 feature 只创建需要的层，并暴露可组合 section widget；局部功能能保持较少结构。 | [模块设计](../../../../docs/design.md)强调小接口、依赖注入和真实测试替身，[分层门禁](../../../../tool/layer_gates.dart)检查 import 边；更利于隔离修改与验证，但仍需避免为满足结构而增加空转抽象。 |
| 验证成本 | [完成约定](https://github.com/MilkFeng/lumina/blob/32f2aa42c4a8efe153061076a7dac1f5bfdf979b/AGENTS.md#8-verification-workflow)统一要求 analyze 与 Flutter 全量测试。 | [测试策略](../../../../docs/testing.md)按改动选择内环证据，推送与合并前跑全量；适合多轮迭代。测试文件更多本身不证明覆盖率或质量更高。 |
| 决策记忆与范围 | [工作约定](https://github.com/MilkFeng/lumina/blob/32f2aa42c4a8efe153061076a7dac1f5bfdf979b/AGENTS.md#10-working-agreement)要求结构变更先取得共识、无关问题只报告。 | [Agent Note](../../README.md)记录理由、备选和后果，有助于跨会话延续；调研基线的文件数门槛与附带清理带来额外成本，现行条件由[风险流程](../../../../docs/development.md#按风险选流程)与[笔记契约](../../README.md#何时写一篇)持有。 |

文档和门禁都不能替代语义核对。Lumina 的 [Rust 文档](https://github.com/MilkFeng/lumina/blob/32f2aa42c4a8efe153061076a7dac1f5bfdf979b/docs/AGENTS/RUST_ARCHITECTURE.md#L118)仍称 FRB 的 Dart 依赖为 2.12.0、Rust 与生成物为 2.11.1，实际 [Dart 配置](https://github.com/MilkFeng/lumina/blob/32f2aa42c4a8efe153061076a7dac1f5bfdf979b/pubspec.yaml#L78)、[Rust 配置](https://github.com/MilkFeng/lumina/blob/32f2aa42c4a8efe153061076a7dac1f5bfdf979b/rust/Cargo.toml#L11)和[生成物](https://github.com/MilkFeng/lumina/blob/32f2aa42c4a8efe153061076a7dac1f5bfdf979b/lib/src/rust/frb_generated.dart#L2)均为 2.13.0。调研基线的 Synlen [常驻规则](https://github.com/Duskriver/Synlen/blob/f1c602d1b7dec184008ecf4f68d749a7b40a1186/AGENTS.md#L8)仅写跨 feature 经 application，而详细规则和门禁还允许 domain 值类型，存在摘要歧义；文档门禁不能识别这些含义冲突。

流程建议中，风险分级、决策复用、修改范围与规则摘要的统一由[流程决策](../../implemented/process/2026-09-26-risk-based-agent-workflow.md)落实；前述产品改进仍是候选，吸纳优先级不变。本节比较依据上述固定基线的源码与配置，没有进行同任务 A/B、耗时、token 或真实 AI 使用率评测。

## Alternatives considered

**整体合并 Lumina main。** 不推荐：主要新增量混合了旧阅读引擎、Isar、备份语义、平台与 UI 改动，合并结果必须重新证明学习、TXT、Locator 与数据恢复契约，工作量不能用提交数估计。

**完全忽略上游。** 不推荐：字体显示名与封面导出曾在 Synlen 暴露对应缺口；独立维护并不消除共同来源的缺陷。

**按完整提交逐个 cherry-pick。** 不作为默认方式：字体修复被打包在跨 75 个文件的 WebDAV 提交中，封面备份修复也混在封面编辑和书架调整内。只挑适用行为并保留来源更容易评审；边界完整且与当前实现兼容的小补丁仍可逐项判断。

## Acceptance criteria

- 维护者能基于固定基线、补丁等价结果和当前调用方，为每项候选决定吸纳、重实现或暂缓；不把发布说明直接当作缺陷已复现或性能已提升的证据。
- 若实施字体与备份修复，字体覆盖真实显示名、数字 SAF ID、名称清理和资源释放，备份覆盖非 JPEG 封面的导出恢复往返并保持现有数据语义。
- 若实施阅读功能，先证明当前 Readium 的 Android / iOS 行为，再覆盖学习触摸、重排位置保持与退出重开。采用范围之外的旧引擎或数据格式改动不得随候选一起混入。
- 后续吸纳以独立、可回退的改动保留一手来源和针对性验证，遵循现有[测试约定](../../../../docs/testing.md)。

## Risks

研究依据发布记录、提交差异与源码，没有运行 Lumina 或在设备上复现候选。字体与封面的本地回归验证见各自决策记录，不能扩大为设备端字体渲染、完整兼容审计、漏洞审计或运行性能结论。

补丁等价会忽略提交身份，也不能证明之后的重构保留了全部行为。重写上游思路可能遗漏其边界处理，直接搬代码又可能破坏本地所有权；每项都需要以当前调用路径决定范围。此提案主动放弃恢复整体跟随上游的关系，也不新增周期监控、GitHub issue 或实施承诺。
