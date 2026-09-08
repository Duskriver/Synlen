# AGENTS

词镜（Synlen）是一个 Flutter 本地阅读器（Android / iOS）：导入 EPUB / TXT 建立藏书，阅读并记录进度，点词与长按句子做学习，TTS 发音。改 `lib/` 前先读 [docs/architecture.md](docs/architecture.md)；写文档前读 [docs/AGENTS.md](docs/AGENTS.md)。

## 常驻指令

- **分层单向**：`presentation → application → domain`、`data → domain`。禁止 `presentation → data` 与 `domain → 上层`（[分层](docs/architecture.md#分层)）。
- **feature 之间不互相 import**；跨 feature 只经对方 `application` 的接口。共享能力下沉 `core/`，且必须被 ≥2 个 feature 使用（[模块地图](docs/architecture.md#模块)）。
- **依赖经 provider 注入**，不在内部 `new`；`@riverpod` 的 `build()` 只做初始化与订阅，`ref.onDispose` 必须与资源创建成对（[资源生命周期](docs/development.md#资源生命周期)）。
- **`AsyncValue` 三态齐全**，禁止裸 `.value`（[Riverpod 约定](docs/development.md#riverpod)）。
- **错误只在 application 捕获**并转成状态字段；用户可读消息走 l10n，内部细节只入日志（[错误处理](docs/development.md#错误处理)）。
- **用户可见文案一律走 l10n**，`app_en.arb` 与 `app_zh.arb` 同批更新（[l10n 流程](docs/cookbook/adding-an-l10n-string.md)）。
- **日志用 `appLogger`**，禁止 `print` / `debugPrint`（[日志](docs/development.md#日志)）。
- **测试是硬性要求**：domain、application、parser、import 的改动必须带测试；按 [docs/testing.md](docs/testing.md) 选覆盖改动的最小证据，不默认跑全量。
- **每个非平凡改动必须带一篇 Agent Note**（[契约](.agents/notes/README.md#何时写一篇)）；纯机械或局部编辑豁免。
- **注释与文档一律中文**；类名、变量名、命令、路径保持英文（[文字标准](.agents/skills/syn-prose-standard/SKILL.md)）。
- **增量重构**：不做 big-bang；新代码按规范，旧代码路过即修；重构与功能分开提交（[决策](.agents/notes/implemented/architecture/2026-08-10-incremental-refactor-over-big-bang.md)）。
- **codegen 产物提交入库、不手改**：模型或 provider 注解变更后跑 `dart run build_runner build --delete-conflicting-outputs`。
- **强推只用 `--force-with-lease`**，禁止裸 `--force`（[推送前检查](.agents/skills/syn-pre-push-checks/SKILL.md)）。

## 命令

```sh
flutter pub get
flutter run
dart format lib test
flutter analyze                                  # 零 error 零 warning
flutter test                                     # 推送 / 合并前全量
dart run build_runner build --delete-conflicting-outputs
dart run tool/layer_gates.dart                   # 分层门禁（动了 lib/ 时）
dart run tool/doc_gates.dart                     # 文档门禁
```

需要 Flutter SDK ≥ 3.38.0、Dart SDK ≥ 3.10.8。

## 入口

- 架构与分层：[docs/architecture.md](docs/architecture.md) · 模块设计：[docs/design.md](docs/design.md)
- 每模块参考：[docs/subsystems/](docs/subsystems/README.md)
- 领域术语：[docs/glossary.md](docs/glossary.md)
- 贡献者日常：[docs/development.md](docs/development.md) · 测试：[docs/testing.md](docs/testing.md)
- 决策记录：[.agents/notes/](.agents/notes/README.md) · 事故复盘：[docs/postmortem/](docs/postmortem/README.md)
- 操作手册：[docs/cookbook/](docs/cookbook/README.md) · 用户指南：[docs/user/](docs/user/index.md)
- 技能：[.agents/skills/](.agents/skills/)（宿主未自动加载时直接读对应 `SKILL.md`）
- issue 与 PRD 存在 GitHub issues，用 `gh` CLI 操作（`gh issue create / view / list / edit`）。
