# 开发

贡献者的日常：环境、命令、提交流程与门禁。分层与模块边界见 [architecture.md](architecture.md)，测试策略见 [testing.md](testing.md)，文档规则见 [AGENTS.md](AGENTS.md)。

## 环境

Flutter 3.47.8 stable 自带 Dart 3.13.7；Android 使用 Gradle 9.3.1、AGP 9.1.1、Kotlin 2.4.0 与 JDK 25，源码字节码目标为 Java 17。Android 最低 API 24、compile / target SDK 36，iOS 最低部署版本为 15.0。reader 学习脚本使用 [.nvmrc](../.nvmrc) 固定的 Node 24 LTS，先执行 `nvm install && nvm use`，再执行 `npm ci`（见[操作手册](cookbook/changing-reader-web-assets.md)）。

Flutter 默认使用 Android Studio 自带的 Java，本机无需另装 Homebrew JDK 21。直接执行 Gradle 时，[daemon JVM 配置](../android/gradle/gradle-daemon-jvm.properties)也要求 Java 25；CI 安装同主版本 JDK。macOS 若未识别 Android Studio 的 JBR，可将 `/Applications/Android Studio.app/Contents/jbr` 链接到 `~/Library/Java/JavaVirtualMachines/android-studio.jdk`，用 `/usr/libexec/java_home -v 25` 检查；路径仅属于本机配置。

Android 使用 `android.builtInKotlin=true`，应用与所有原生插件由 AGP 内置 Kotlin 编译；显式声明可防止 Flutter 迁移器写回旧模式。`android.newDsl=false` 仍是 Flutter 3.47.8 自身构建插件的要求，取消后会在 `FlutterPlugin.addFlutterTasks` 中发生旧 DSL 类型强转错误。Readium 使用本地补丁分支，升级其内核须单独验证阅读行为。

`flutter_image_compress_common 1.1.1` 会按构建环境选择内置 Kotlin。Flutter 的文本扫描仍可能把其未执行的旧插件分支报告为 KGP 使用；实际加载状态与构建结果才是判断依据，不修改 pub 缓存来消除警告。

```sh
flutter pub get
flutter run -d <device-id>
```

实际构建版本由 CI 的 `flutter-version: '3.47.8'` 固定；本地与 CI 必须同版本，升级走[工具链锁定](../.agents/notes/implemented/process/2026-08-11-pin-toolchain-and-dependency-ceiling.md)的流程。依赖更新与漏洞告警由 Dependabot 覆盖，每周检查版本更新（[依赖审计](../.agents/notes/implemented/process/2026-09-09-dependency-audit-and-dependabot.md)）。

升级保留已有书库，不清除应用数据；数据库迁移与验证步骤见[数据库 schema](cookbook/changing-the-database-schema.md)，旧阅读坐标的恢复精度见[reader 边界](subsystems/reader.md#边界与不变量)。

## 按风险选流程

| 风险与决策 | 例子 | 走的步骤 |
|---|---|---|
| 局部、目标明确且沿用已有契约 | 文案与样式、机械修改、恢复既定行为的 bug 修复 | 明确验证方式 → 实现 → 检查 → 提交 |
| 需要确定新行为或契约 | 验收标准不明确的新能力、公共接口或模块职责变化、持久化格式与兼容、删除功能、不可逆操作 | 定规格 → 实现 → 检查 → 提交 |
| 需要分阶段交付或迁移 | 引擎替换、跨模块改造、存量数据迁移 | 定规格 → 按可独立验证的阶段拆票 → 实现 → 评审 → 维护 |

规格写清背景、验收标准与关键约束或技术路径。**已有用户请求或 issue 足以确定这些内容且已授权实施时，直接继续**；只补缺失的决策，不重复确认。需要持续跟踪的规格放 GitHub issue，优先补充已有 issue；新的独立工作项用 `gh issue create` 建。

按行为、契约与回退成本判断风险；同一局部改动涉及测试、l10n、生成物或按既有接口跨层接线，不因文件数升级流程。流程选择的理由见[决策记录](../.agents/notes/implemented/process/2026-09-26-risk-based-agent-workflow.md)。

## 提交门禁

每次提交：

```sh
dart format lib test
flutter analyze                                  # 零 error 零 warning
dart run tool/layer_gates.dart                   # 动了 lib/ 时（分层与跨 feature 边）
dart run tool/doc_gates.dart                     # 动了文档时（CI 在 PR 与发版前置门禁都跑）
```

推送或合并前：**全量 `flutter test` 必须全绿**。内环只跑覆盖改动的最小证据（见 [testing.md](testing.md)），CI 拥有全量矩阵。

提交信息格式 `type(scope): 描述`，type ∈ {feat, fix, refactor, chore, docs, test, perf, merge}，描述用中文、说明"为什么"而不是"改了什么"。一个逻辑改动一个 commit；**重构与功能不混在同一个 commit 里**。分支：`main` 保持可发布，功能在 `feat/xxx` 分支开发。

## 资源生命周期

`@riverpod` 的 `build()` 只做初始化与订阅，异步加载放私有方法。**在 `build()` 中创建的资源（音频协调器、流订阅、控制器）必须在 `ref.onDispose` 中释放**，参考 `LearningController`。重复进入同一页面不得泄漏。

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

注释、dartdoc、Markdown 一律中文；类名、变量名、文件名、枚举值、包名、命令、路径保持英文。生成物（`*.g.dart`、l10n 生成文件、`assets/reader/readium_learning.js`）先改源再重新生成。

新增或实质修改的注释使用中文；未涉及的旧英文注释留待专项整理，避免翻译淹没本次行为差异。

## 增量重构

新代码按规范写，旧代码只整理本次实现、验证或理解受改行为所必需的部分；无关问题在交付说明中报告，需要追踪时另记 issue。文件被打开或改动本身不构成扩大范围的理由。

不做 big-bang 重构；必要重构与功能分开提交，先重构后功能。只有某个区域成为新功能地基，或任务明确要求重构该区域时，才安排专项重构，且**先补测试再动手**（见[决策记录](../.agents/notes/implemented/architecture/2026-08-10-incremental-refactor-over-big-bang.md)）。

## 维护

| 场景 | 动作 / 技能 |
|---|---|
| 用户报 bug | 建 issue，标注优先级 |
| 疑难 bug / 性能回归 | 先定位根因再动手；值得复盘时写 [事故复盘](postmortem/README.md) |
| 简化机会 | [syn-find-simplifications](../.agents/skills/syn-find-simplifications/SKILL.md) → Agent Note 提案 |
| 评审改动 | [syn-code-review](../.agents/skills/syn-code-review/SKILL.md) |
| 文档结构与审计 | [syn-doc](../.agents/skills/syn-doc/SKILL.md) |
| 技术债与待办 | GitHub issues（`gh issue list`）；新增债务开 issue 并标注优先级 |
| 文字精简与会话泄漏清理 | [syn-prose-standard](../.agents/skills/syn-prose-standard/SKILL.md) / [syn-trim-cot-leakage](../.agents/skills/syn-trim-cot-leakage/SKILL.md) |
| 发版 | [发布一个版本](cookbook/publishing-a-release.md) |
| 发布后出问题 | [发布故障响应](cookbook/handling-a-release-incident.md) |

## Dev Note

None.
