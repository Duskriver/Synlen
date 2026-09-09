# Agent Note: 发版质量门禁是 PR 门禁的超集

Status: implemented

## Problem

PR 的日常 CI 跑分层门禁与 Rust 测试，发版的 quality-gates 却不跑：PR 能拦住的违规在发版链路里反而漏过，而漏过的代价是要撤回已发布的产物。同时 reader 的 Playwright 用例（点词与长按取词的浏览器行为断言）长期只在本地跑，[docs/testing.md](../../../../docs/testing.md) 要求 reader Web 资源改动跑 `npm test`，CI 却没有任何 job 执行它，回归只能靠人工记得跑。

## Decision

门禁对齐方向定为**发版 ⊇ PR**：`.github/workflows/build_release.yml` 的 quality-gates 补上 `dart run tool/layer_gates.dart` 与 `cargo test --locked --manifest-path rust/Cargo.toml`（Rust toolchain 用 `dtolnay/rust-toolchain@stable` + `Swatinem/rust-cache@v2`，与日常 CI 的 rust job 同写法）。

`.github/workflows/flutter_ci.yml` 的 web-assets job 在 typecheck 之后跑 `npm test`（即 `playwright test`）。浏览器安装集与 `web_assets/controller.js/playwright.config.cjs` 的 projects 保持一致：`npx playwright install --with-deps chromium webkit`，配置改动时两处同步。用例不依赖 WebView 与网络，浏览器内核是唯一新增的运行时依赖。

## Alternatives considered

**发版 job 只补 cargo test，不补 layer gates** —— 放弃：理由同样成立，缺哪个都是发版比 PR 松。

**只装 chromium，省掉 webkit 的安装时间** —— 放弃：playwright.config.cjs 声明了 webkit project，少装会让一半的用例报错而不是跳过；要么改配置砍 project，要么装全，本决策选装全。

**发版 workflow 复用日常 CI 的 job（reusable workflow）** —— 放弃：跨文件复用要求日常 CI 改造成 `workflow_call`，改动面大于收益；两个文件各自的步骤清单保持直白可复制。

## Consequences

- 发版失败点前移：分层违规或 Rust 测试挂掉时，tag 推送不产生任何构建产物，删 tag 重来即可。
- web-assets job 每次运行多出两个浏览器内核的下载与系统依赖安装（约一两分钟），只在改动触及该 job 的 PR 上付出。
- Playwright 用例数量增长时，浏览器安装清单仍跟着 `playwright.config.cjs` 走，不靠人工记。
