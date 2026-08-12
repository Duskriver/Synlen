# AGENTS

## 必读（开发前先读）

- `docs/DEVELOPMENT_STANDARDS.md` — 项目唯一开发规范：架构分层、模块设计、Riverpod/错误处理/测试约定。所有代码改动必须遵守。
- `docs/DEVELOPMENT_WORKFLOW.md` — 开发流程：六阶段流水线（想法→规格→拆票→实现→评审→维护）、Skill 速查表、硬性底线。按任务规模适配，底线不可破。
- `CONTEXT.md` — 领域统一语言词汇表。写作前先查术语；发现模糊/冲突术语立即更新。
- `docs/adr/` — 架构决策记录。满足难逆转 + 无上下文会困惑 + 真实权衡三条才新增。
- `docs/agents/` — 工程技能的仓库配置（issue tracker、triage 标签、领域文档消费规则）。

## Agent skills

### Issue tracker

本仓库的 issues 与 PRD 存为 GitHub issues，通过 `gh` CLI 访问。见 `docs/agents/issue-tracker.md`。

### Triage labels

五个规范 triage 角色映射到默认标签（`needs-triage`、`needs-info`、`ready-for-agent`、`ready-for-human`、`wontfix`）。见 `docs/agents/triage-labels.md`。

### Domain docs

单上下文：根目录 `CONTEXT.md` + `docs/adr/`。见 `docs/agents/domain.md`。

## Workflows

### Setup
- 安装依赖：`flutter pub get`

### Run
- 启动应用：`flutter run`
- 指定设备运行：`flutter run -d <device-id>`

### 提交前必过（规范 §8/§9）
- 静态检查（零 error 零 warning）：`flutter analyze`
- 测试：`flutter test`
- 格式化：`dart format`
- codegen（模型/provider 变更后）：`dart run build_runner build --delete-conflicting-outputs`

### Build (Release)
- Android APK：`flutter build apk --release`
- iOS：`flutter build ios --release`

## Notes
- 需要 Flutter SDK >= 3.10.8 和 Dart SDK >= 3.10.8（见 README）。
- 注释与 Markdown 文档一律用中文；类名/变量名/命令等保持英文（规范 §8.1）。
- 增量重构纪律见 ADR-0001：不做 big-bang 重构，新代码按规范，旧代码路过即修；重构与功能分开提交。
- 技术债记录在 `docs/TECH_DEBT.md`，不散落在代码注释。
