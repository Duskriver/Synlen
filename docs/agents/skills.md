# 仓库技能（借鉴 DSH 范式）

> 来源：[deepseek-harness](https://github.com/deepseek-ai/deepseek-harness) 的 `.agents/skills/`（"Everything is a Plugin"）。2026-08 起全量借鉴其开发范式并适配到本仓库。
> 技能本体在 `.agents/skills/<name>/SKILL.md`；共同哲学：**guidance, not a script**——判断力优先于机械清单。

## 映射表

| DSH 技能 | 本仓库 | 适配说明 |
|---|---|---|
| dsh-code-review | `syn-code-review` | 六项阻断要求适配 Flutter 分层 / Riverpod / l10n；保留双轴（标准 + spec） |
| dsh-pre-push-checks | `syn-pre-push-checks` | pnpm change-scope → git diff；按变更类型的最小证据表 |
| dsh-find-simplifications | `syn-find-simplifications` | 产出从双语笔记改为单语提案；小改动并入 TECH_DEBT（规范 §10） |
| dsh-doc-standards | `syn-doc-standards` | 硬预算工具改软规则（≤300 行）；补 README 双语对同步要求 |
| dsh-prose-standard | `syn-prose-standard` | 契约保留式编辑，覆盖中文注释 / 文档 / l10n / commit message |
| dsh-trim-cot-leakage | `syn-trim-cot-leakage` | 八类泄漏 + 排除 CHANGELOG / ADR / TECH_DEBT |
| dsh-archive-agent-notes | `syn-archive-agent-notes` | 单语单文件版 Agent Notes（去 i18n 三元组），契约在 `.agents/notes/README.md` |
| dsh-merging-stacked-prs | `syn-merging-stacked-prs` | 原样移植，gh stack 原生合并 |
| record-browser-gif | `syn-record-ui-demo` | 浏览器 → iOS / Android 模拟器；同样走孤儿 assets 分支发布 |
| dsh-doc-site-sync | **不移植** | 本仓库无文档站投影层（无 VitePress / docs 清单） |
| dsh-translate-docs | **不移植** | 本仓库单语中文（规范 §8.1），不维护任何双语对；README 已统一为单一中文版 |

## 核心范式（落到本仓库的七条）

1. **指导而非脚本**：技能提供判断框架，不替代读代码 / 读文档。
2. **最小证据**：内环按变更类型选最窄测试集（`syn-pre-push-checks`）；全量门禁在推送 / 合并与 CI。
3. **契约保留**：文字编辑先保契约（义务 / 不变量 / 兼容承诺）再删冗余（`syn-prose-standard`）。
4. **仓库视角**：所有持久文字对只看 HEAD 的读者自足；会话痕迹删除（`syn-trim-cot-leakage`）。
5. **决策语料治理**：Agent Notes 有生命周期（提案 → 实现 / 拒绝 → 密封归档），缩减活跃语料而不抹除历史。
6. **真实证据演示**：UI 行为变更的 PR 必须附真实运行的演示 GIF，禁止 mock 冒充（`syn-record-ui-demo`）。
7. **让平台拥有规则**：堆叠 PR 用 GitHub 原生 stack，代理只验证 / 链接 / 触发（`syn-merging-stacked-prs`）。

## 调用说明

- 前缀 `syn-` 避免与用户级技能（如 `code-review`）重名。
- 若宿主未自动加载仓库级技能，按 `AGENTS.md` 的引用路径直接读 `SKILL.md` 执行即可——技能本体即流程说明，不依赖特殊运行时。
- 与六阶段流水线的衔接见 `docs/DEVELOPMENT_WORKFLOW.md` §4–§7。
