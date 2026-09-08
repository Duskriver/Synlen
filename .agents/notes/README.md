# Agent Notes

Agent Note 是 agent 写的 RFC：记录影响代码库的决策——**为什么**做、放弃了**什么**，这些是代码和文档承载不了的部分。本文件定义它们放在哪、什么时候写、以及文件格式。

## 布局与命名

每篇笔记的两个维度都编码在**路径**里：`{lifecycle}/{class}/yyyy-mm-dd-topic-title.md`。

**生命周期**（顶层目录）就是状态，状态变化时文件随之移动：

- `proposed/` — 实现前评审过的提案，尚未建成或只建了一部分。
- `implemented/` — 决策已交付。文件描述 shipped 现实，并**跟着现实走**：代码后来改了路径、改了名字、改了默认值，同一次改动里更新笔记里的事实（只改事实，不改决策）。
- `rejected/` — 提案被考虑后否决。只在它的理由还能阻止一个真实错误时保留，否则删掉。
- `archived/` — 冻结历史。见[归档](#归档与删除)。

**类别**（二级目录）是决策的种类，取值是闭集：

| 类别 | 覆盖什么 |
|---|---|
| `feature` | 新的用户可见或模型可见能力 |
| `bug-fix` | 修缺陷，或补上一个复盘暴露的缺口 |
| `simplification` | 删代码、删行为、删接口面，不新增能力 |
| `architecture` | 关于 shipped 源码的结构决策：模块如何关联、运行时词汇是什么 |
| `process` | 代码**周边**的工具、政策与流程：门禁、依赖、发布 |
| `testing` | 测试基础设施与策略 |

`architecture` 与 `process` 的分界：前者关乎我们发布的源码，后者关乎外围工具与流程。故意没有 `refactor`——它与 `simplification` 重叠，判别标准"可观察行为是否改变"已经覆盖。

文件名里的日期是话题**首次提出**的日期（以 git 历史为准）。笔记之间用相对 Markdown 链接互相引用，不用裸文件名或编号。

**不要建集中索引**：活跃树本身就是清单，靠目录和全文搜索检索。

## 归档与删除

已交付的决策完成、且其理由不太可能再指导未来工作时，归档它。它的备选方案、所有权边界、负面保证、持久化或线上语义、安全规则、重新引入条件仍然有用时，保持活跃。**永远不要归档 proposed 笔记**——过期的提案应当改判 rejected。rejected 笔记只在还能阻止一个可预见的错误时保留，否则连同中文文件一起删除。

归档路径是 `archived/{class}/yyyy-mm-dd-topic-title.md`；没有 `implemented/` 这一层，因为只有 implemented 笔记能进归档。归档时：移动文件、在 `Status: implemented` 下一行插入 `Archived: YYYY-MM-DD`、修复或删除所有入站链接。这是归档期唯一允许的内容改动。

一旦封存，归档笔记永久冻结：不编辑、不重排、不移动、不删除，也不作为当前行为的权威。文档门禁跳过归档目录。

## 何时写一篇

**每个非平凡改动必须在同一次改动里新增或更新至少一篇 Agent Note。** 非平凡指：改变行为、架构、跨文件或跨模块的契约、流程与工具、测试策略、磁盘 / 线上 / 配置格式，或任何维护者日后可能重新考虑的决定。为将来的大工作做提案，从 `proposed/` 开始；已经做出的决定，从 `implemented/` 开始。

更新已经拥有该决策的笔记即可满足要求，不要新建重复的。只有纯机械或局部编辑、且不改变行为、契约、结构、流程与理由时才豁免。一篇笔记不能被编辑成**另一个决策**：用新笔记取代它，两者交叉链接，除非旧笔记被完全并入新笔记。

新增笔记时先做**取代检查**：搜索活跃树里是否已有覆盖同一决策或机制的旧笔记；完全或部分取代的，在同一次改动里按[归档规则](#归档与删除)处理。

## 文件格式

前三行固定：

```markdown
# Agent Note: <标题>

Status: <status>
```

后接空行。`Status` 有三种形式，且必须与所在目录一致：`Status: proposed`、`Status: implemented`、`Status: rejected — <一句话理由>`。状态行不带日期与括号；日期在文件名里，其余在 git 里。

正文以 `## Problem` 开头——动机要能脱离方案独立成立。之后按生命周期：

**proposed**

```markdown
## Problem
## Proposal
…按需的技术小节…
## Alternatives considered
## Acceptance criteria
## Risks
```

`## Proposal` 可以合法地使用将来时；`## Acceptance criteria` 说明什么可观察状态算完成；`## Risks` 覆盖可能出问题的地方与这次改动主动放弃的东西。

**implemented**

```markdown
## Problem
## Decision
…按需的技术小节…
## Alternatives considered
## Consequences
```

`## Decision` 用现在时描述 shipped 现实。proposal 时代的标题在这里是 spec 语言，门禁会拒绝：`## Proposal`、`## Plan`、`## Migration plan`、`## Acceptance criteria` 不得出现在 implemented 笔记里。`## Testing`、`## Deferred`、`## Related` 陈述现在时事实时可以保留。

**rejected**

rejected 笔记是冻结的提案：保留它提案期的所有小节（包括 `## Acceptance criteria`），判决写在 `Status:` 行上。只有头部、`## Problem` 开头、`## Proposal` 小节和下面的备选方案要求仍然适用。

### Alternatives considered 是强制的

每篇笔记都要有 `## Alternatives considered`：每个真实备选以及它为何落败，一个备选一段或一个 `### 为什么不选 X？` 小节。**决策不记录它击败了什么，就会招来重新争论**——这正是 Agent Notes 存在的理由。备选只记录，不发明。

### 生命周期之间的移动

移动文件意味着在同一次改动里更新 `Status:` 行并满足目标目录的骨架，否则门禁失败。`proposed/` → `implemented/` 把 `## Proposal` 改写成现在时的 `## Decision`，把 `## Acceptance criteria` 与 `## Risks` 折进 `## Consequences`，删掉计划、只留交付了什么。`proposed/` → `rejected/` 只在 `Status:` 行上加理由并冻结文件。

## Dev Note

None.
