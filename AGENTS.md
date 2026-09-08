# AGENTS

## 必读（开发前先读）

- `docs/DEVELOPMENT_STANDARDS.md` — 项目唯一开发规范：架构分层、模块设计、Riverpod / 错误处理 / 测试约定。所有代码改动必须遵守。
- `docs/DEVELOPMENT_WORKFLOW.md` — 开发流程：按规模选择步骤、评审与提交门禁。
- `CONTEXT.md` — 领域统一语言词汇表。写作前先查术语；发现模糊 / 冲突术语立即更新。
- `docs/adr/` — 架构决策记录。满足难逆转 + 无上下文会困惑 + 真实权衡三条才新增。
- `docs/TECH_DEBT.md` — 技术债清单（分层违规、待清理项）。
- `.agents/notes/README.md` — Agent Notes 契约：简化提案与决策护栏（含与 ADR / TECH_DEBT 的分工）。

## Agent skills（`.agents/skills/`）

| 技能 | 用途 |
|---|---|
| `syn-code-review` | 评审改动：六项阻断要求 + Flutter 分层 / Riverpod 检查面 |
| `syn-pre-push-checks` | 推送前按变更类型选最小测试证据 |
| `syn-find-simplifications` | 简化机会挖掘 → Agent Note 提案 |
| `syn-doc-standards` / `syn-prose-standard` / `syn-trim-cot-leakage` | 文档结构 / 契约保留式文字 / 会话泄漏清理 |

技能本体即流程说明：宿主未自动加载时，直接读对应 `SKILL.md` 执行。

## Issue tracker

issues 与 PRD 存为 GitHub issues，用 `gh` CLI 操作（`gh issue create / view / list / edit`）。

## Workflows

### Setup / Run
- 安装依赖：`flutter pub get`
- 启动应用：`flutter run`（指定设备：`flutter run -d <device-id>`）

### 提交前必过（规范 §8/§9）
- 每次提交：`flutter analyze`（零 error 零 warning）+ `dart format` + 按最小证据选择的测试（`.agents/skills/syn-pre-push-checks`）
- 推送 / 合并前：全量 `flutter test` 必须全绿
- codegen（模型 / provider 变更后）：`dart run build_runner build --delete-conflicting-outputs`

### Build (Release)
- Android APK：`flutter build apk --release`
- iOS：`flutter build ios --release`

## Notes
- 需要 Flutter SDK >= 3.38.0、Dart SDK >= 3.10.8。
- 注释与 Markdown 文档一律用中文；类名 / 变量名 / 命令等保持英文（规范 §8.1）。
- 增量重构纪律见 ADR-0001：不做 big-bang 重构，新代码按规范，旧代码路过即修；重构与功能分开提交。
- 技术债记录在 `docs/TECH_DEBT.md`，不散落在代码注释。
- Agent Notes 按 `.agents/notes/README.md` 契约管理：提案 → 实现 / 拒绝 → 密封归档。
- 强推只用 `--force-with-lease`，禁止裸 `--force`。
