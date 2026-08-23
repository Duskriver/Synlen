---
name: syn-pre-push-checks
description: 在 Synlen 分支上推送、强推、标记 ready for review 或声称"检查通过"之前使用。按变更类型选择覆盖改动的最小测试集，而不是习惯性跑全量套件；含强推与历史重写保护。当用户要求"推送 / push / 提 PR"或推送前验证时触发。
---

# Synlen 推送前检查（最小证据）

> 核心理念：**选择覆盖变更的最小证据**。内环快，全量门禁放在推送 / 合并前与 CI。
> 硬性底线不变：`flutter analyze` 零 error 零 warning、`dart format` 每次提交必跑（规范 §8/§9）。

## 1. 确认变更范围

- 确认分支与 base（`gh pr view` / stack 父 ref）。
- `git diff <base>...HEAD --stat` 看全量范围；base 变更后重新执行。

## 2. 按变更类型选最窄证据

| 变更 | 最小证据 |
|---|---|
| `lib/` 行为改动 | `flutter analyze` + 对应测试（`flutter test test/<对应路径>_test.dart`） |
| 仅注释 / 文档 | 无测试；`dart format`（仅涉 .dart 时）；核对相对链接 |
| 模型 / provider 注解 | `dart run build_runner build --delete-conflicting-outputs` → analyze + 相关测试 |
| l10n ARB | `flutter analyze`（重新生成 localizations）+ 受影响页面的测试 |
| `pubspec.yaml` / `analysis_options.yaml` / `build.yaml` / `l10n.yaml` | `flutter analyze` + **全量** `flutter test`（配置影响全局，证据必须宽） |
| `rust/` 或 FFI 绑定 | `cargo test`（在 `rust/` 内）→ 绑定重新生成 → analyze + 冒烟测试 |
| 用户可见 UI 行为 | 对应 widget / 单元测试 + `syn-record-ui-demo` 演示 GIF |

- 测试文件过滤 ≠ 覆盖率豁免：新增源文件必须有对应测试；不许用"恰好没跑到"糊弄。
- **全量本地演练**（`flutter test` 全跑）仅在：用户明确要求、排查 CI 失败、或变更横跨全仓库时执行。

## 3. 推送 / 合并门禁

- 推送或 PR 标记 ready for review 前：**全量 `flutter test` 必须全绿**——这是规范 §9 的硬性底线；最小证据只用于内环快速迭代。
- codegen 产物（`.g.dart` 等）与源注解一致后再推送。

## 4. 历史重写保护

- 强推一律 `git push --force-with-lease`（带记录的 OID），**永远禁止**裸 `--force`。
- rebase / 重写分支并推送后**必须事后验证**：重查分支头、检查重写范围、重跑相关证据；验证通过前该 PR 不得合并。

## 5. 失败处理

- 推送前失败就停下修复；**不要推送然后指望 CI 结果不同**。
- 疑似环境问题（SDK 版本、模拟器、网络）需举证（贴错误输出），不许默默绕过。
- 绕过任何 hook / 检查仅在用户明确同意时进行。

## 6. 推送程序

1. 跑选定证据 → 2. 提交（`type(scope): 中文描述`，规范 §9）→ 3. 推送 → 4. 核对远端 ref 与 `HEAD` 一致 → 5. `gh pr checks` 看 CI。
- CI 显示"无检查运行"时，先用 `git merge-tree` 判断是否为冲突（DIRTY / CONFLICTING）而非基础设施问题。
