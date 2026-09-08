# 开发

贡献者的日常：环境、命令、提交流程与门禁。分层与模块边界见 [architecture.md](architecture.md)，测试策略见 [testing.md](testing.md)，文档规则见 [AGENTS.md](AGENTS.md)。

## 环境

Flutter SDK ≥ 3.38.0、Dart SDK ≥ 3.10.8；reader 的 Web 资源另需 Node 22 与 `npm ci`（见 [操作手册](cookbook/changing-reader-web-assets.md)）。

```sh
flutter pub get
flutter run -d <device-id>
```

## 按规模选流程

| 规模 | 例子 | 走的步骤 |
|---|---|---|
| 小改动 | 修一个 bug、改一个文案、调一个参数 | 实现 → 提交 |
| 中功能 | 新增一个页面或能力 | 定规格 → 实现 → 提交 |
| 大功能 / 重构 | 阅读器引擎改造、新增整个模块 | 定规格 → 拆票 → 实现 → 评审 → 维护 |

判断标准：涉及**跨层架构**、**超过 3 个文件**或**影响数据模型**时，至少先定规格。规格是 GitHub issue 的正文（背景、验收标准、技术路径），用 `gh issue create` 建。

## 提交门禁

每次提交：

```sh
dart format lib test
flutter analyze                                  # 零 error 零 warning
dart run tool/doc_gates.dart                     # 动了文档时（CI 在 PR 与发版前置门禁都跑）
```

推送或合并前：**全量 `flutter test` 必须全绿**。内环只跑覆盖改动的最小证据（见 [testing.md](testing.md)），CI 拥有全量矩阵。

提交信息格式 `type(scope): 描述`，type ∈ {feat, fix, refactor, chore, docs, test, perf, merge}，描述用中文、说明"为什么"而不是"改了什么"。一个逻辑改动一个 commit；**重构与功能不混在同一个 commit 里**。分支：`main` 保持可发布，功能在 `feat/xxx` 分支开发。

## 资源生命周期

`@riverpod` 的 `build()` 只做初始化与订阅，异步加载放私有方法。**在 `build()` 中创建的资源（音频协调器、流订阅、控制器）必须在 `ref.onDispose` 中释放**，参考 `SentenceLearningController`。重复进入同一页面不得泄漏。

## Riverpod

- 依赖一律经 `ref.watch` / `ref.read` 获取。
- `AsyncValue` 必须处理全部三态，禁止裸 `.value`。
- provider 与实现文件分离：`xxx_repository.dart`（实现）+ `xxx_repository_provider.dart`（暴露）。
- 生成文件（`.g.dart`）提交入库、不手改，由 `build_runner` 维护。

## 错误处理

- 领域错误定义在 `domain`：`class XxxException implements Exception`，`toString() => message`。
- **捕获点在 `application`**：catch 后转成状态字段，UI 只渲染状态；禁止在 presentation 里 try/catch 业务异常并吞掉。
- 用户可读消息与内部细节分离：消息走 l10n，内部细节只入日志。

## 日志

用 `appLogger`（`lib/src/core/services/app_logger.dart`），**禁止 `print` / `debugPrint`**；`analysis_options.yaml` 已启用 `avoid_print`。

## l10n

用户可见文案一律走 ARB，`app_en.arb` 与 `app_zh.arb` 同批更新，流程见 [adding-an-l10n-string](cookbook/adding-an-l10n-string.md)。错误码到文案的映射在展示层统一做。

## 注释与文档语言

注释、dartdoc、Markdown 一律中文；类名、变量名、文件名、枚举值、包名、命令、路径保持英文。生成物（`*.g.dart`、l10n 生成文件、`lib/src/web/web_assets.dart`）先改源再重新生成。

早期写就的模块里仍有成片英文注释（集中在导入、解析、主题与备份相关的几个大文件）。按 Boy Scout Rule 路过即译，不做一次性批量翻译——翻译不改行为，却会淹没 diff。

## 增量重构

不做 big-bang 重构：新代码一律按规范写，旧代码遵循 Boy Scout Rule（路过即修）。重构与功能分开提交，先重构后功能。只有某个区域成为新功能地基时，才安排一轮专项重构，且**先补测试再动手**（见[决策记录](../.agents/notes/implemented/architecture/2026-08-10-incremental-refactor-over-big-bang.md)）。

## 维护

| 场景 | 动作 / 技能 |
|---|---|
| 用户报 bug | 建 issue，标注优先级 |
| 疑难 bug / 性能回归 | 先定位根因再动手；值得复盘时写 [事故复盘](postmortem/README.md) |
| 简化机会 | [syn-find-simplifications](../.agents/skills/syn-find-simplifications/SKILL.md) → Agent Note 提案 |
| 评审改动 | [syn-code-review](../.agents/skills/syn-code-review/SKILL.md) |
| 文档结构与审计 | [syn-doc](../.agents/skills/syn-doc/SKILL.md) |
| 文字精简与会话泄漏清理 | [syn-prose-standard](../.agents/skills/syn-prose-standard/SKILL.md) / [syn-trim-cot-leakage](../.agents/skills/syn-trim-cot-leakage/SKILL.md) |
| 发版 | [发布一个版本](cookbook/publishing-a-release.md) |

## Dev Note

None.
