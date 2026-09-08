---
name: syn-doc
description: 在 Synlen 写、移动或审计文档时使用——判断事实该放哪一层、写成教程还是参考、按廉价探针审计语料、超预算时怎么处理。当用户说"改进文档 / 审计文档 / 这文档放哪 / 太长了"时触发。
---

# Synlen 文档：放置与结构

**这是判断框架，不是清单**：层级定义、写作规则与预算规则由 [docs/AGENTS.md](../../../docs/AGENTS.md) 持有，本技能只决定放哪、怎么排、先查什么。

## 真相来源

- [docs/AGENTS.md](../../../docs/AGENTS.md) — 层级表、写作规则、slop 九类、预算与校验。
- [docs/architecture.md](../../../docs/architecture.md) — 模块组成、分层、新行为落点。
- [docs/design.md](../../../docs/design.md) — 深模块、seam 纪律、可测试性三原则。
- [docs/glossary.md](../../../docs/glossary.md) — 领域术语的规范词与禁用别称。
- [docs/development.md](../../../docs/development.md) · [docs/testing.md](../../../docs/testing.md) — 贡献者流程与测试策略。
- [docs/subsystems/README.md](../../../docs/subsystems/README.md) — 每模块参考页的入口。
- [.agents/notes/README.md](../../../.agents/notes/README.md) — 决策记录的生命周期、类别与格式。
- [AGENTS.md](../../../AGENTS.md) — 常驻指令。
- 结构细则见 [references/structure.md](references/structure.md)，骨架见 [templates/subsystem-page.md](templates/subsystem-page.md)、[templates/cookbook.md](templates/cookbook.md)、[templates/user-guide.md](templates/user-guide.md)、[templates/agent-note.md](templates/agent-note.md)。

## 放置判断

按"作者在回答什么问题"路由；每个层级的职责与"不属于此层"的反向定义以 [docs/AGENTS.md](../../../docs/AGENTS.md) 的层级表为准。

| 作者在回答 | 落点 |
|---|---|
| 每个会话都必须知道的约束 | 根 [AGENTS.md](../../../AGENTS.md)，1–3 行 + 一条理由链接 |
| 系统由哪些模块组成、依赖往哪流、新行为放哪 | [docs/architecture.md](../../../docs/architecture.md) |
| 这个模块有哪些类型、语义、边界、已知限制 | [docs/subsystems/README.md](../../../docs/subsystems/README.md) 下的一页 |
| 这个模块该长什么样（接口大小、seam） | [docs/design.md](../../../docs/design.md) |
| 为什么这样决定、放弃了哪些备选 | [.agents/notes/README.md](../../../.agents/notes/README.md) 下的一篇笔记 |
| 怎么做完一件有验证步骤的事 | [docs/cookbook/README.md](../../../docs/cookbook/README.md) 下的一页 |
| 用户怎么用 | [docs/user/index.md](../../../docs/user/index.md) |
| 这个领域概念叫什么、不许叫什么 | [docs/glossary.md](../../../docs/glossary.md) |
| 坏了什么、哪道安全网没拦住 | [docs/postmortem/README.md](../../../docs/postmortem/README.md) |
| 环境、命令、提交门禁、测试策略 | [docs/development.md](../../../docs/development.md)、[docs/testing.md](../../../docs/testing.md) |

不发明新的顶层位置；同一事实已经有家时，别处只加链接。

## 教程还是参考

每份文档二选一。**教程**按前置概念排序、只引入当步所需、通向一个可观察结果；**参考**定义查找范围与当前行为，不做教学序列。

写教程前先把读者起点与每个概念标成初 / 中 / 高，前置概念排在依赖它的概念之前。两者都实质存在时拆开，或给较小的一半加标签；拆开后某半只剩几行时才不拆。

## 语料审计顺序

先跑廉价探针，再读散文；探针能定位的问题不靠通读发现。

1. 量体：`dart run tool/doc_gates.dart --list` 打印每份文档行数，与 `tool/doc-budgets.json` 的上限对照。
2. 找重复之家：拿一条特征短语 `rg -n` 全仓搜，命中多个家就留一个，其余改链接。
3. 找手抄目录：纯链接的索引页、工具 / 包 / 测试清单；源或生成物已权威时删。
4. 找历史与状态：搜 `以前`、`不再`、`曾经`、`已实现`、`未来将`、`PR #`。
5. 通读散文最密的段落：段落墙、强调通胀、理由与兄弟方法重复只有通读能发现。

## 预算处理

超限按固定顺序，不跳步：

1. **先搬迁**：内容属于别层 → 移到归属文档，本页留链接。
2. **再精简**：属于本层 → 删叙述、重复、状态说明，保留承重契约。
3. **最后抬上限**：改 `tool/doc-budgets.json` 的数字，并在 PR 里说明理由。

上限是护栏不是削减目标：达标文档留 ≥5% 余量；抬过上限的文档在搬迁或精简之前冻结上限。

## 阻断要求

1. **每个事实一个家**：同一条规则命中两个家就留一个，其余改链接。
2. **只写当前状态**：不写"以前是""不再是""这一版"、PR 编号、commit 号、`已实现` / `未来将`。
3. **链接用相对 Markdown 路径**且目标存在；移动文档时同一次改动修所有入站链接。
4. **作者维护的页面以 `## Dev Note` 结尾**，无内容写 `None.`（Agent Note 按 [.agents/notes/README.md](../../../.agents/notes/README.md) 的格式，不加 Dev Note）；稳定行为与已接受的决策不放 Dev Note。
5. **文档改动过门禁**：`dart run tool/doc_gates.dart` 检查链接与锚点、术语与代码一致、仓库路径、Agent Note 格式、技能元数据、预算、Markdown 卫生。
6. **超预算按 搬迁 → 精简 → 抬上限** 的顺序处理，不先抬上限。

## 手动检查

- 术语用 [docs/glossary.md](../../../docs/glossary.md) 的规范词，禁用别称清零；新概念先落术语表再写文档。
- 教程：前置概念是否都排在依赖它的概念之前。
- 参考页是否在教人按顺序读；是则改成教程或删掉教学段。
- 排除区：生成物、`.agents/notes/archived/`、[docs/postmortem/README.md](../../../docs/postmortem/README.md) 的叙事、commit message。
- 移动前查入站链接与配对文件；门禁只证明结构与可核查事实，语义与可读性仍靠人。

## 报告发现

- 动了哪些文档、各自的归属层级，以及搬迁 / 精简 / 抬上限分别做了什么。
- `dart run tool/doc_gates.dart` 的结果；剩余问题与原因。
- 无法核实的路径或数字、有意保留的边界情况。

## Dev Note

None.
