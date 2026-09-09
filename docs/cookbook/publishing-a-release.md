# 发布一个版本

从版本号定档到 `version.json` 上线，走这套步骤。客户端如何检查更新见[应用内更新](../user/guide/in-app-update.md)，版本记录的用户可见格式见[版本记录](../user/release-notes.md)。

## 步骤

1. 定版本号 `vX.Y.Z`，同时更新 `pubspec.yaml` 的 `version`。Android 的 `versionCode` 由 tag 派生（`vX.Y.Z` → `X*10000 + Y*100 + Z`），不手写。
2. 在 `docs/user/release-notes.md` 把「未发布」小节改名为 `## vX.Y.Z`，删掉「以下内容尚未发布」那行，核对内容与本次发布一致。段名不改，`tool/upload_release.sh` 会中止发布。
3. 提交并打 tag：`git tag vX.Y.Z && git push origin vX.Y.Z`。`.github/workflows/build_release.yml` 的 `quality-gates` job 先跑 analyze、全量测试、分层门禁、Rust 测试、文档门禁与生成物漂移，再构建 APK、AAB 与 iOS 产物。
4. 上传到 OSS：`./tool/upload_release.sh vX.Y.Z <bucket> <region>`。脚本生成 `version.json` 并上传 universal APK 与存在的 split APK；CI 里配好 `OSS_*` secrets 后，tag 推送会自动执行同一步。
5. 核对 `version.json`：`updateLog` 与 release notes 一致，`androidApkUrl` 指向本次 APK，`androidApkSha256` 与脚本输出的 APK 摘要一致（脚本自动写入，客户端下载后比对）。

## 验证

1. `bash tool/upload_release.sh vX.Y.Z` 不因缺少版本段而中止，输出里的 `updateLog` 是本次版本段。
2. 打开 `https://<bucket>.oss-<region>.aliyuncs.com/version.json`：`buildNumber` 与 tag 派生值一致，`updateLog` 是本次版本段。
3. 在旧版本 App 上点「检查更新」：弹出更新对话框，版本号与更新日志正确，Android 能下载并拉起安装器。
4. 覆盖安装后书架与阅读进度仍在。

## 约束

- 更新分发只走 OSS 的 `version.json`，`androidApkUrl` 必须是 universal APK；split APK 只作备用下载，不进 `version.json`。`androidApkSha256` 由 `tool/upload_release.sh` 自动写入；手工维护 `version.json` 时必须带上 `shasum -a 256` 的摘要，缺失时客户端放行但记 warning。
- 发版 job 与门禁用同一套固定工具链（Flutter 3.44.9、Rust 1.97.1、cargo-ndk 4.1.2），Actions 固定到 commit SHA；版本升级见[工具链锁定](../../.agents/notes/implemented/process/2026-08-11-pin-toolchain-and-dependency-ceiling.md)。
- 发布链路不含 AI 服务密钥：签名密钥走 GitHub Secrets，AI 密钥由用户在设备上自填（见 [BYOK 决策](../../.agents/notes/implemented/architecture/2026-08-11-byok-user-provided-ai-keys.md)）。
- iOS 的 App Store 链接在服务端 `version.json` 里配置；为空时对话框不显示该入口。

## Dev Note

None.
