# AGENTS.md — 文档标准

本文件定义词镜（Synlen）文档的层级、形态、写作规则与预算。放置与结构判断用 [syn-doc 技能](../.agents/skills/syn-doc/SKILL.md)，句子级判断用 [syn-prose-standard](../.agents/skills/syn-prose-standard/SKILL.md)。

## 一条原则：每个事实只有一个家

每个事实只属于一个层级；别处只链接，不复述。层级表同时写出"不属于此层"的内容，反向定义比正向描述更能阻止内容外溢。

| 层级 | 职责 | 不属于此层 |
|---|---|---|
| 根 [AGENTS.md](../AGENTS.md) | 常驻指令：每个会话都需要的规则，每条 1–3 行并链接其归属文档 | 故事、示例、情境流程、被链接处已写的内容 |
| 子树 `AGENTS.md`（[docs/](AGENTS.md)、[.agents/notes/](../.agents/notes/AGENTS.md)） | 该子树专属指令 | 根文件已载的仓库级规则 |
| [architecture.md](architecture.md) | 有序地图：分层、模块组成、数据流、扩展点；改 `lib/` 前先读 | 类型定义（→ subsystems）、模块内部细节（→ subsystems）、决策理由（→ Agent Notes） |
| [design.md](design.md) | 模块设计的判断标准：深模块、删除测试、seam 纪律、可测试性三原则 | 分层与模块边界（→ architecture.md） |
| [subsystems/](subsystems/README.md) | 每模块一页参考：类型、语义、边界、已知限制与待办 | 行为叙述（→ architecture.md） |
| [Agent Notes](../.agents/notes/README.md) | 活跃决策记录：为什么、放弃了什么、需要什么验证 | 迁移计划、验收清单、已交付后的 "should" 式 spec 语言 |
| [postmortem/](postmortem/README.md) | 事故故事——唯一允许叙事化的层级 | — |
| [cookbook/](cookbook/README.md) | 带编号验证步骤的操作手册 | 设计理由（→ 链接对应 Agent Note） |
| [user/](user/index.md) | 面向用户的指南 | 生成表、贡献者流程、决策史 |
| [glossary.md](glossary.md) | 领域术语的唯一来源 | 实现细节 |
| [development.md](development.md) | 贡献者日常：环境、命令、提交门禁、流程 | 运行时理由（→ Agent Notes）、会与脚本漂移的逐条清单 |
| [testing.md](testing.md) | 测试分层与最小证据 | — |
| 生成物（`*.g.dart`、l10n 生成文件、`assets/reader/readium_learning.js`） | 从源再生成，提交入库 | 手改 |
| [.agents/skills/](../.agents/skills/) | 可复用工作流与判断标准 | 产品与运行时契约（→ docs 或源码） |

放置速查：缺陷 → postmortem；理由 → Agent Notes；步骤 → cookbook；类型与模块语义 → subsystems；面向用户的用法 → user/；术语 → glossary；债务与待办 → GitHub issues；常驻指令 → 根 AGENTS.md + 一条理由链接。

## 形态：教程与参考

每份文档二选一。**教程**按前置概念排序、只引入当步所需，通向一个可观察的结果；**参考**定义查找范围与当前行为，不做教学序列。两者都实质存在时拆开，或给较小的一半加标签。写教程前先私下把读者起点与每个概念标成初/中/高，前置概念必须排在依赖它的概念之前。

## 写作规则

- **只写当前状态。** 不写"以前是""不再是""这一版"、PR、commit、分支位置；变更叙事进 commit、PR、Agent Note 或 postmortem。命名当前生效的机制。
- **一物理行一段落**（软换行）：段落不硬换行；代码块、表格、列表保持原有格式。
- **链接用相对 Markdown 路径**，禁止裸文件名；跨文档引用必须能被 `verify-md-links` 校验。
- **保留承重契约**：义务、不变量、前置/后置条件、兼容承诺、并发与生命周期约束、失败后果。删的是叙述、重复与状态说明，不是契约。
- **具体名词优先**：写"响应字段""JSON 校验""ESM 导出"，不写"响应形状""校验边界""模块形态"；不用隐喻。
- **强调节制**：加粗只用于改变行为的那个从句。
- **中文标点与中英混排**：中文用全角标点；中英文之间、中文与数字之间加一个半角空格（`每个 plugin 注册 3 个 tool`）；代码、命令、路径保持英文原文。
- **Dev Note 是唯一的非权威区。** 每个作者维护的页面以 `## Dev Note` 结尾，承载未定方向、实测数据与进行中的假设，明确标注非权威；无内容时写 `None.`。稳定行为、必须遵守的限制与已接受的决策属于各自的归属文档。

## slop 清单

审计任何文档时先查这九类：

1. 同一条规则出现在多个家——grep 一个特征短语，留一个家，其余改链接。
2. 叙述历史：`以前`、`不再`、`曾经`、`改名为`、PR 编号、commit 号。
3. 实现状态标注：`已实现`、`未来将`。状态会腐烂，代码与门禁才权威。
4. 手抄目录：工具、包、测试清单在源或生成物已权威时被手写一遍。
5. 推理过程复述：分步实现叙述、显然分支的证明、测试走查、被否决的本地备选。
6. 理由与兄弟方法并排重复，而不是在归属能力处写一次。
7. 段落墙：一段塞进多条规则与括号补充。
8. 强调通胀：加粗、全大写、"关键"到处都是。
9. implemented 笔记里的 spec 语言：`应该`、迁移计划、验收清单。

## 预算

`tool/doc-budgets.json` 设定常驻文档与模块参考页的上限，`dart run tool/doc_gates.dart` 拒绝超限或缺失文件。超限时按顺序处理：**先搬迁**（内容属于别层）→ **再精简**（属于本层但可以更短）→ **最后抬上限**并在 PR 里说明理由。上限是护栏不是削减目标：达标文档保留 ≥5% 余量；抬过上限的文档在搬迁或精简之前冻结上限。`docs/user/release-notes.md` 按版本追加，不设上限。

## 校验

文档改动必须过 `dart run tool/doc_gates.dart`：相对链接与锚点、术语与代码一致性、标识符形式的禁用别称未被声明为类型、`docs/` 中引用的仓库路径存在（Agent Notes 可以引用已删除的历史路径）、Agent Note 格式、技能元数据、预算、Markdown 卫生（单一 H1、行尾、一物理行一段落）、`docs/` 页面以 `## Dev Note` 收尾。门禁只证明结构与可核查事实，语义、术语恰当性与可读性仍由评审负责。

## Dev Note

None.
