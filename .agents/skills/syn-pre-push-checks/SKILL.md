---
name: syn-pre-push-checks
description: 在 Synlen 推送、强推、标记 ready for review 或声称"检查通过"之前使用——按变更类型选择覆盖改动的最小证据，并走推送与合并门禁、历史重写保护。当用户说"推送 / push / 提 PR"或推送前验证时触发。
---

# 推送前检查：最小证据

**这是判断框架，不是清单**：证据的宽度跟着改动的风险面走；最小证据用于内环迭代，全量门禁在推送与合并前。

## 真相来源

- [docs/testing.md](../../../docs/testing.md) — 按文件类型的最小证据表、测试分层、命名与位置。
- [docs/development.md](../../../docs/development.md) — 提交门禁、提交信息格式、增量重构纪律。
- [AGENTS.md](../../../AGENTS.md) — 命令清单与强推约束。
- [.agents/notes/README.md](../../../.agents/notes/README.md) — 非平凡改动必须带笔记。

## 最小证据选择

先确定变更范围：`git diff <base>...HEAD --stat`；base 变更后重算。再问改动碰到哪一面，取覆盖它的最窄证据。

| 改动碰到 | 证据宽度 | 为什么够 |
|---|---|---|
| 只碰注释、文档 | 无测试；动了 .dart 跑 `dart format` + `dart run tool/doc_gates.dart` | 无运行时行为 |
| 单个 feature 内部行为 | `flutter analyze` + 该路径的测试 | 契约面局限在本 feature |
| 跨层契约、数据模型、共享 `core/` | 相关 feature 的测试 + 受影响门禁 | 影响面超出单模块 |
| 模型 / provider 注解 | 重新生成 codegen → analyze + 相关测试 | 生成物是契约的一部分 |
| 配置与依赖（`pubspec.yaml`、`analysis_options.yaml`、`build.yaml`、`l10n.yaml`） | analyze + 全量 `flutter test` | 影响全局，证据必须宽 |
| `rust/` 或 FFI 绑定 | `cargo test` → 绑定重生成 → analyze + 冒烟 | 跨语言边界 |
| reader Web 资源 | typecheck + 前端测试 → 重新生成资源 | 生成物会漂移 |

按文件类型的精确映射见 [docs/testing.md](../../../docs/testing.md)；本表只定宽度。测试过滤不等于覆盖率豁免：新增源文件必须有对应测试。全量本地演练只在用户明确要求、排查 CI 失败或改动横跨全仓库时执行。

## 阻断要求

1. **推送或标记 ready for review 前全量 `flutter test` 全绿**；最小证据只用于内环。
2. **强推只用 `git push --force-with-lease`**，禁止裸 `--force`；重写分支后重查分支头、重跑证据，验证通过前不得合并。
3. **codegen 产物与源注解一致**再推送。
4. **推送前失败就停下修复**，不推送后指望 CI 结果不同；疑似环境问题要贴证据，不默默绕过。
5. **不绕过 hook 与检查**，除非用户明确同意。

## 手动检查

- `gh pr checks` 看 CI；显示"无检查运行"时先用 `git merge-tree` 判断是不是冲突（DIRTY / CONFLICTING）而不是基础设施问题。
- 推送后核对远端 ref 与本地 `HEAD` 一致。
- 提交信息 `type(scope): 中文描述`，说明"为什么"；一个逻辑改动一个 commit，重构与功能分开。

## 推送程序

1. 跑选定证据 → 2. 提交 → 3. 推送 → 4. 核对远端 ref 与 `HEAD` → 5. 看 CI。

## 报告发现

- 变更范围、选了哪档证据、每条命令的结果。
- 全量测试结论、codegen 与门禁状态、强推后的验证结果。

## Dev Note

None.
