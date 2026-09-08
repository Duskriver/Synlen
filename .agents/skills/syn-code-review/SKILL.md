---
name: syn-code-review
description: 在 Synlen 评审 PR 或待合并改动时使用。执行本仓库的阻断性检查（l10n、文档同步、术语、资源生命周期、语义测试、门禁）与 Flutter 分层/Riverpod 手动审查，报告缺陷。当用户要求"评审代码 / review / 看看这个改动"时触发。
---

# Synlen 代码评审

> 指导而非清单：本技能提供判断框架与必须覆盖的检查面，不替代阅读代码本身。
> 原则：优先关注**正确性、资源生命周期、必要行为的中断**，而非风格——风格交给 `flutter analyze` 与 `dart format`。

## 1. 准备

1. 确认评审对象的实际 base 与 head（`gh pr view <n> --json baseRefName,headRefName` 或 `git merge-base`）；PR 变更目标分支后重新评审。
2. 看全量 diff：`gh pr diff <n>` 或 `git diff <base>...HEAD`，先 `--stat` 判断范围，再逐文件读足上下文理解设计。
3. 读关联 ticket / spec（`gh issue view <n>`），记住验收标准——评审是**双轴**的：**标准轴**（是否守开发规范）+ **spec 轴**（是否贴合原需求）。
4. 需要上下文时读：`docs/DEVELOPMENT_STANDARDS.md`、`CONTEXT.md`、相关 `docs/adr/`、`docs/TECH_DEBT.md`。

## 2. 阻断性要求（不满足即打回）

1. **文案**：新增用户可见文案一律走 l10n（zh / en ARB 同步），并按 `syn-prose-standard` 过语义审查；禁止 UI 硬编码字符串（规范 §8）。
2. **文档同步**：README（双语对）、`docs/`、`CONTEXT.md` 中受影响的内容必须在同一 diff 更新。
3. **术语**：核心类型 / 领域概念变更必须同步 `CONTEXT.md`（含 `_Avoid_` 表）；代码命名使用规范词（规范 §6）。
4. **资源生命周期**：新增 `@riverpod` provider / 协调器 / 流订阅，必须有对应释放验证（`ref.onDispose` 成对出现、重复进入不泄漏——规范 §2 application 层职责）。
5. **invariant 伴生测试须有语义**：断言行为与边界，而非仅"对象存在 / 不抛异常"；核心逻辑（domain、application、parser、import）无测试不合并（规范 §7）。
6. **门禁**：作者已跑 `flutter analyze`（零 error 零 warning）、按 `syn-pre-push-checks` 的最小测试证据、`dart format`；模型 / provider 注解变更已重新生成 codegen 产物。

## 3. 手动检查（按 diff 类型裁剪）

- **分层**：依赖方向 `presentation → application → domain`、`data → domain`；禁止 `presentation → data`、禁止 `domain → 上层`、feature 间不互引、进 `core/` 须被 ≥2 个 feature 使用（规范 §1）。新增违规直接阻断——别让 PR 加长 TECH_DEBT #1 那张表。
- **深模块**：接口能再小吗？参数能再简吗？只有一种实现的接口是假 seam（规范 §3）。
- **Riverpod**：`AsyncValue` 三态齐全、无裸 `.value`；data 层依赖经 provider 注入、不在内部 `new` 自己的依赖；provider 文件与实现分离（规范 §4）。
- **错误处理**：捕获点在 application；异常转状态字段；内部细节只入日志不上屏（规范 §5）。
- **并发与生命周期**：流订阅取消、`AudioCoordinator` 一页一实例、webview / platform channel 回调捕获是否有泄漏路径。
- **测试强度**：在 seam 处用 fake 替换，不依赖真实网络 / 文件系统 / 平台通道（规范 §7）。
- **增量纪律**：重构与功能是否分 commit（ADR-0001）。
- **体量**：presentation 文件超 ~400 行必须拆（规范 §2）。

## 4. 报告发现

- 每条发现说明：**缺陷、位置（`文件:行`）、影响、证据**。
- 局部问题用行内评论；架构性问题（分层、模块形状）用 PR 级评论。
- 明确区分**阻断项**与**建议项**；已被绿色门禁（analyze / 测试）覆盖的问题不再报。
- 与既有 ADR 矛盾的改动显式指出（"与 ADR-0002 矛盾——但值得重开，因为……"），不默默放过（见 `CONTEXT.md` 与 `docs/adr/`）。
