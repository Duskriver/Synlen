# Agent Note: 发布门禁只等 Android 产物

Status: implemented

## Problem

v0.3.0 首次发版时，iOS job 因 [发布链路的五处首次发版缺陷](2026-09-16-release-pipeline-first-run-defects.md)里的第 5 条失败，而 `create-release` 同时 `needs: [build-ios, build-android]`，于是 Release 被跳过：Android 产物已经上传到 OSS、线上 `version.json` 已生效，其中的 `githubUrl` 却指向一个不存在的 Release 页面。

分发目标实际上只有 Android——没有上架任何应用商店，iOS 暂不投入。让一个不投入的平台决定 Android 能否发布，是把发版可用性绑在了没人维护的构建上。

## Decision

- `create-release` 的依赖收窄为 `needs: [build-android]`：Android 产物就绪即创建 Release。
- `Download iOS Artifacts` 步骤加 `continue-on-error: true`：iOS 产物存在就一并作为附件发布，不存在就跳过。
- `build-ios` job 保留并照常运行。它失败会让整个 run 显示红色，但不再阻塞 Release 与 OSS 通道。
- 与平台无关的质量门禁（analyze、全量测试、分层门禁、Rust 测试、文档门禁、生成物漂移）仍是发布前置，不受此改动影响。

## Alternatives considered

**保持双平台依赖，把 iOS 修到能过** —— 放弃：修好当前缺陷不改变耦合本身。iOS 后续如果再因工具链或签名变动而失败，Android 发版会再次被无声跳过。

**直接删掉 `build-ios` job** —— 放弃：将来接入 iOS 要重新写回工具链准备、Rust target、打包与上传步骤；保留一个可能失败的 job，成本只是一次构建时间和一行红色状态。

**给 `build-ios` 加 `continue-on-error: true`** —— 放弃：job 级容错会把失败显示成成功，丢掉「iOS 坏了」这个信号。当前做法保留信号，只是不让它拦住发布。

## Consequences

- 发布 run 可能整体显示失败（iOS job 红），但 Release 与 OSS 通道都正常。**判断发版是否成功要看 `build-android` 与 Release 是否创建，而不是 run 的整体颜色。**
- iOS 产物何时重新纳入门禁：等真正要分发 iOS 时，把 `needs` 加回 `build-ios` 并去掉下载步骤的 `continue-on-error`。
- v0.3.0 的 Release 是手工补建的（iOS 失败跳过了自动创建），从下一个 tag 起走修好的自动路径。
