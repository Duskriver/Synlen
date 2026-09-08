# 文档结构参考

**这是判断框架，不是清单**：章节顺序服务于"读者此刻需要什么"，不是填空。四份骨架见 [../templates/subsystem-page.md](../templates/subsystem-page.md)、[../templates/cookbook.md](../templates/cookbook.md)、[../templates/user-guide.md](../templates/user-guide.md)、[../templates/agent-note.md](../templates/agent-note.md)。

## 通用约束

- 每页一个 H1；每个 H2 后先写一句导语，说明本节覆盖什么、谁需要读。
- 一物理行一段落；表格、列表、代码块保持原有格式。
- 每页以 `## Dev Note` 结尾，无内容写 `None.`。
- 顺序固定：先"是什么 / 边界"，再"怎么用"，再"已知限制"，最后 Dev Note。

## 子系统页

顺序：导语 → 职责与边界 → 关键类型与语义 → 数据流 → 扩展点 → 已知限制与待办 → Dev Note。

- 导语：这个模块负责什么、不负责什么。
- 职责与边界：对外接口清单；跨 feature 只写经哪个 application 接口。
- 关键类型与语义：表格（类型 | 语义 | 约束），类型名与 [术语表](../../../../docs/glossary.md) 一致。
- 数据流：编号步骤，只写本模块承担的那段；整体数据流归 [architecture.md](../../../../docs/architecture.md)。
- 扩展点：新增能力改哪个目录或文件。
- 已知限制与待办：当前缺口与归属；迁移计划与验收清单属于 [Agent Note](../../../../.agents/notes/README.md)。

## 操作手册页

顺序：导语 → 步骤 → 验证 → 约束 → Dev Note；有前置条件时在步骤前加一节"前置"。

- 导语：做完能观察到什么，外加一条最硬的约束。
- 步骤：编号，每步一个动作或一条命令；命令用 shell 代码块。
- 验证：编号，每条给可观察的通过 / 失败判据。
- 约束：不变量、失败后果、不可回退的边界。
- 设计理由不写在这里，链接对应 Agent Note。

## 用户指南页

顺序：导语 → 开始前 → 操作步骤 → 结果 → 常见问题 → Dev Note。

- 只写用户看得见的东西；生成表、贡献者流程、决策史留给贡献者文档。
- 术语用界面上的说法，不用内部类型名。

## Agent Note

格式、生命周期与必填小节由 [.agents/notes/README.md](../../../../.agents/notes/README.md) 规定；骨架见 [../templates/agent-note.md](../templates/agent-note.md)。标题行、Status 行与小节顺序都由门禁校验。

## Dev Note 归属

Dev Note 承载未定方向、实测数据与进行中的假设，并明确标注非权威。稳定行为、必须遵守的限制、已接受的决策写进归属文档；空则 `None.`。

## 小规则文件何时拆

拆：一页超过预算；同时服务两条读者路径（教程 + 参考）；单页承担两个层级的事实。不拆：一条规则加一条链接；同一读者的连续步骤；拆开后某半只剩几行。

## 链接规则

相对 Markdown 路径，禁止裸文件名；锚点用目标标题原文；移动文档时同一次改动修所有入站链接；索引页只做路由，不复制目标内容。
