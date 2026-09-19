# Agent Note: lock 漂移由 CI 门禁拦截

Status: implemented

## Problem

Dependabot 的解析环境看不到 Flutter SDK 的钉版（`flutter_localizations` 锁 `intl`、`flutter_test` 锁 `meta`）。它在每个 pub PR 分支上重算整份 `pubspec.lock`，写进去的版本组合在 Flutter 3.44.9 上不成立：合并 `#35`/`#36`/`#39` 后，lock 里的 `intl` 是 0.20.3、`meta` 是 1.19.0、`vector_math` 是 2.4.2，共 7 个包与解析结果不一致。

这种破损在 CI 结构上不可见——`flutter pub get` 会静默重新解析，测试照常通过，没有任何步骤比对 lock 与解析结果。它只在两处暴露：本地 `pub get` 让工作区变脏，以及 `tool/release.sh` 的干净工作区要求把发布拦在最后一步。

## Decision

`.github/workflows/flutter_ci.yml` 的 flutter job 在 `flutter pub get` 之后增加一步 `git diff --exit-code -- pubspec.lock`：解析结果与入库的 lock 不一致即失败，并输出提示要求用 CI 固定的 Flutter 版本重跑 `pub get` 后提交结果。

门禁以 CI 固定的 3.44.9 为准，与 [docs/development.md](../../../../docs/development.md#环境) 已写明的「本地与 CI 必须同版本」一致：它给那条要求装上牙齿，不新增约束。

## Alternatives considered

**只在 `tool/release.sh` 里检查** —— 放弃：破损的 lock 会通过 PR 与日常 CI，留到发布才拦，而发布已是最后一道；本次故障走的正是这条路径。

**在 `dependabot.yml` 里 `ignore` 掉被 SDK 钉住的包** —— 放弃：会连带屏蔽这些包的安全告警，且忽略清单要跟着 Flutter 升级手工维护。

**靠人工记得合并依赖 PR 后重跑 `pub get` 并提交** —— 放弃：本次就是人工流程漏掉的；没有门禁就没有证据。

**比对 `pubspec.yaml`** —— 放弃：`pub get` 不改写它，比对不成立。

## Consequences

- 依赖 PR 的 lock 不等于解析结果时 CI 直接失败，报错点紧跟 `pub get`，指向明确。
- 本地 Flutter 与 CI 不同版本时，本地生成的 lock 会让门禁失败；这是[工具链锁定](2026-08-11-pin-toolchain-and-dependency-ceiling.md)已要求的同版本纪律，门禁把它从文档约束变成可见证据。
- 合并 pub 依赖 PR 之后需要确认 lock：本仓库的做法是本地重跑 `pub get`，有漂移就单独提交修正（见 `78974cf`）。

## Related

本决策补充[工具链锁定](2026-08-11-pin-toolchain-and-dependency-ceiling.md)记录的 Dependabot 盲区（cargo 侧靠人工锁步），[依赖审计](2026-09-09-dependency-audit-and-dependabot.md)持有的覆盖面不变；发版入口见[本地发布与手动云端备用](2026-09-17-local-release-with-manual-cloud-fallback.md)。
