# Agent Note: 更新分发走阿里云 OSS

Status: implemented

## Problem

应用内更新需要一个国内能稳定访问的版本清单与安装包地址。GitHub Releases 在国内网络下经常超时；同时 Android 要求每次发版的 `versionCode` 递增，否则覆盖安装会被系统拒绝。

## Decision

- 版本元数据是 OSS 上的 `version.json`：`majorNumber` / `minorNumber` / `patchNumber` / `buildNumber` / `updateLog` / `androidApkUrl` / `iosAppStoreUrl` / `lanzouUrl` / `githubUrl`。客户端只读这一个端点，见 `lib/src/features/settings/presentation/widgets/check_update_tile.dart`。
- `versionCode` 由 tag 派生：`vX.Y.Z` → `X*10000 + Y*100 + Z`，构建与上传两侧同一规则（`.github/workflows/build_release.yml` 与 `tool/upload_release.sh`）。
- `updateLog` 从 `docs/user/release-notes.md` 的 `## vX.Y.Z` 段提取，步骤见[发布一个版本](../../../../docs/cookbook/publishing-a-release.md)。
- 打 tag 触发构建；配好 `OSS_*` secrets 时 CI 自动上传，未配置则跳过，开源后 fork 天然无凭据。
- 蓝奏云与 GitHub Release 作为备选入口，只在服务端 `version.json` 里配置了链接时显示。

## Alternatives considered

**只发 GitHub Releases** —— 放弃：国内检查更新与下载不稳定。

**自建更新服务** —— 放弃：与"无后端"的定位冲突，运维成本换不来收益。

**手写 `versionCode`** —— 放弃：漏改就出现"覆盖安装被拒"，派生规则让版本号与 tag 不可能不一致。

## Consequences

- 发版前必须把 release notes 的「未发布」段改名成 `## vX.Y.Z`，否则 `updateLog` 为空。
- `androidApkUrl` 指向 universal APK；split APK 只作备用下载，不进 `version.json`。
- iOS 未上架时 `iosAppStoreUrl` 为空，对话框不显示该入口。
