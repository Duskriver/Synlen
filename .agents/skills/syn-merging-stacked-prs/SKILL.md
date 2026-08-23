---
name: syn-merging-stacked-prs
description: 落地一组相互依赖的堆叠式 PR（A ← B ← C）时使用。必须借助 GitHub 原生 stack 功能与 gh stack 扩展合并，禁止手动逐个合并再改 base 模拟堆叠语义。当用户要求"合并这串 PR / merge the stack"时触发。
---

# 合并堆叠式 PR

> 核心思想：让 GitHub 拥有整个堆叠的规则、CI、顺序与 retarget；代理只负责**验证、链接与触发**。不确定就问用户，不自动变更。

## 1. 前置

- `gh stack --version`；不可用则**硬性停止**（安装：`gh extension install github/gh-stack`），不允许降级为手动方案。
- 所有分支必须同仓库；跨 fork 链停止。

## 2. 获取权威元数据

- `gh pr view` 拉取每个 PR 的精确 head OID。
- GraphQL 查询 `PullRequest.stack` 与 `stackEntry.position`——**stack 对象是成员资格的权威依据**，不靠 base 分支推断。

## 3. 补链

- 对照 stack 条目与预期链。所有作者完全一致 → 按自底向上顺序 `gh stack link`；作者不同 → 先问用户。
- 禁止自动解散、重排、重建已有 stack。

## 4. 仅在必要时刷新

- 只在合并状态或仓库规则要求时改写历史：`gh stack checkout` + `gh stack sync`（冲突用 `gh stack rebase` + `gh stack push`）。
- 改写后按 `syn-pre-push-checks` §4 重新验证，并重审未解决的 review 线程、审批与 CI。

## 5. 预检与合并

- 重查 stack：所选 PR 均 open、非 draft、顺序正确、满足审查与检查要求。
- 整体落地：`gh stack merge <stack-number> --yes --merge`；部分落地传边界 PR（必须自底向上包含到边界的所有层）。
- 不传 `--delete-branch`；不手动改 base；不逐个 `gh pr merge`。受阻时查明原因或停下报告，**绝不回退到手动合并**。

## 6. 验证与分支清理

- 等所有选中 PR 状态为 `MERGED`——排队中不算完成；部分落地后重查 stack，确认剩余上层仍按预期链接。
- 分支删除是最后的独立阶段：删除前确认该分支没有仍开放的 PR 引用（查询结果非 0 则阻止删除）。
