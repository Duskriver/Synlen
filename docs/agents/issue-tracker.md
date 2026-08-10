# Issue tracker：GitHub

本仓库的 issues 与 PRD 都存为 GitHub issues，所有操作使用 `gh` CLI。

## 约定

- **创建 issue**：`gh issue create --title "..." --body "..."`。多行正文用 heredoc。
- **读取 issue**：`gh issue view <number> --comments`，用 `jq` 过滤评论，同时获取标签。
- **列出 issues**：`gh issue list --state open --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'`，配合 `--label` 与 `--state` 过滤。
- **评论 issue**：`gh issue comment <number> --body "..."`
- **打标签 / 移除标签**：`gh issue edit <number> --add-label "..."` / `--remove-label "..."`
- **关闭 issue**：`gh issue close <number> --comment "..."`

仓库从 `git remote -v` 推断——在仓库克隆内运行时 `gh` 会自动识别。

## 把 PR 作为请求入口

**PR 是否作为请求入口：否。** （若本仓库把外部 PR 当作功能请求，改为 `yes`；`/triage` 会读取此标记。）

设为 `yes` 时，PR 与 issue 走相同的标签与状态，使用 `gh pr` 对应命令：

- **读取 PR**：`gh pr view <number> --comments`，diff 用 `gh pr diff <number>`。
- **列出待 triage 的外部 PR**：`gh pr list --state open --json number,title,body,labels,author,authorAssociation,comments`，只保留 `authorAssociation` 为 `CONTRIBUTOR`、`FIRST_TIME_CONTRIBUTOR` 或 `NONE` 的（排除 `OWNER`/`MEMBER`/`COLLABORATOR`）。
- **评论 / 打标签 / 关闭**：`gh pr comment`、`gh pr edit --add-label`/`--remove-label`、`gh pr close`。

GitHub 的 issue 与 PR 共用一个编号空间，所以裸的 `#42` 可能是任一者——先用 `gh pr view 42` 判断，失败再退回 `gh issue view 42`。

## 当技能说"发布到 issue tracker"时

创建一个 GitHub issue。

## 当技能说"获取相关 ticket"时

运行 `gh issue view <number> --comments`。

## Wayfinding 操作

由 `/wayfinder` 使用。**地图**是一个带子 issue 作为 ticket 的单个 issue。

- **地图**：单个带 `wayfinder:map` 标签的 issue，存放 Notes / Decisions-so-far / Fog 正文。`gh issue create --label wayfinder:map`。
- **子 ticket**：作为 GitHub sub-issue 链接到地图的 issue（用 `gh api` 操作 sub-issues 接口）。若未启用 sub-issues，则把子项写进地图正文的任务清单，并在子 issue 正文顶部加 `Part of #<map>`。标签：`wayfinder:<type>`（`research`/`prototype`/`grilling`/`task`）。认领后 ticket 指派给负责的开发者。
- **阻塞**：GitHub 原生的 **issue 依赖**——UI 可见的规范表示。用 `gh api --method POST repos/<owner>/<repo>/issues/<child>/dependencies/blocked_by -F issue_id=<blocker-db-id>` 添加边，其中 `<blocker-db-id>` 是阻塞者的数字**数据库 id**（`gh api repos/<owner>/<repo>/issues/<n> --jq .id`，不是 `#编号` 或 `node_id`）。GitHub 报告 `issue_dependencies_summary.blocked_by`（仅未关闭的阻塞者——实时闸门）。依赖不可用时，退回在子 issue 正文顶部写 `Blocked by: #<n>, #<n>`。当所有阻塞者都关闭时，ticket 解除阻塞。
- **前沿查询**：列出地图未关闭的子项（`gh issue list --state open`，限定在地图的 sub-issues / 任务清单内），去掉带未关闭阻塞者（`issue_dependencies_summary.blocked_by > 0`，或 `Blocked by` 行内有未关闭 issue）或已有指派人的；按地图顺序取第一个。
- **认领**：`gh issue edit <n> --add-assignee @me` —— 本会话的第一次写操作。
- **解决**：`gh issue comment <n> --body "<答案>"`，然后 `gh issue close <n>`，再把上下文指针（gist + 链接）追加到地图的 Decisions-so-far。
