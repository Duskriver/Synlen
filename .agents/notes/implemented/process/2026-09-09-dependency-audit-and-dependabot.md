# Agent Note: 依赖漏洞审计与 Dependabot

Status: implemented

## Problem

评审把依赖供应链列为长期风险：仓库没有 SBOM、没有依赖漏洞扫描，GitHub Actions 只固定到 major tag（可被上游重新指向），没有 Dependabot/Renovate 类依赖治理。许可证资产靠 `assets/licenses/` 手工维护。

## Decision

- **Dependabot**（`.github/dependabot.yml`）覆盖四类生态：`github-actions`（合并为一个 group PR）、`pub`、`cargo`（`/rust`）、`npm`（`web_assets/readium`），每周检查。它同时承载 pub 侧的安全告警——Dart 没有等价 `cargo audit` 的本地扫描器。
- **cargo audit**（`.github/workflows/security_audit.yml`）每周一 03:23 UTC 与手动触发时跑 `cargo audit`，命中 RustSec 公告即失败；PR CI 不加这一步，避免每次改动都依赖外部公告库可用性。
- **Actions 固定到 commit SHA**（见[工具链锁定](2026-08-11-pin-toolchain-and-dependency-ceiling.md)），尾注保留 `# v4` 这类语义标签，更新走 Dependabot PR。
- **许可证扫描暂不接入**：现有做法是 `assets/licenses/` 手工登记 + 发布时核对。自动化需要先定许可白名单策略（哪些许可证可接受），这是策略决策而非工具缺口，留给独立议题。

## Alternatives considered

**在 PR CI 里跑 cargo audit** —— 放弃：审计结果随 RustSec 公告变化，与本次改动无关的公告会让无关 PR 变红；周更 + 手动触发已能覆盖发现节奏。

**用 `rustsec/audit-check` 等第三方 Action 代替 `cargo install cargo-audit`** —— 放弃：多一个需要固定 SHA 的 Action，而 `cargo install --locked` 已足够，且与本地命令一致。

**同时接入 `cargo deny` 做许可证扫描** —— 放弃：需要先确定许可证白名单与例外流程，否则扫描结果无人可判。

## Consequences

- 漏洞发现路径：cargo audit 周报 + Dependabot 安全告警；两者都不阻断日常 PR。
- 升级 Actions 变成 Dependabot PR + 人工看尾注标签，SHA 与语义版本不脱节。
- 许可证合规仍是手工流程；引入新依赖时评审需自行核对许可证。
