# Agent Note: 发布链路的五处首次发版缺陷

Status: implemented

## Problem

`build_release.yml` 的上传与说明提取步骤只在真实 tag 发版时执行，此前从未跑过。首次发版前逐项核对外部依赖，发现四处会直接失败或取错内容的缺陷，它们都藏在不执行就看不见的地方：

1. **ossutil 下载地址不存在**：`ossutil-1.7.19-linux-amd64.zip` 返回 404；且 `curl` 没带 `-f`，会把 XML 错误页当压缩包存盘，错误被推迟到 `unzip` 才暴露。
2. **解压后的二进制路径错误**：包内有一层 `ossutil-v1.7.19-linux-amd64/` 目录，原步骤里的 `chmod +x /tmp/ossutil-bin/ossutil` 指向的文件并不存在。
3. **凭据来源不成立**：ossutil v1 不读 `OSS_ACCESS_KEY_ID` / `OSS_ACCESS_KEY_SECRET` 环境变量。实测仅设环境变量时报 `accessKeyID and ecsUrl are both empty`，与完全没有凭据时一模一样；改为写配置文件后请求抵达服务端并返回 `InvalidAccessKeyId`，证明凭据确实被采用。
4. **Release 正文取错版本**：`ffurrer2/extract-release-notes` 默认读 `CHANGELOG.md`（本仓库没有该文件），且按固定序号取「第 2 到第 3 个二级标题之间」。本仓库发版时会新插入一个 `## vX.Y.Z` 段，该取法会抽出**上一版**的说明。

第五处在首次真实发版时才暴露，v0.3.0 的 iOS job 因此失败、连带 Release 创建被跳过：

5. **YAML 折叠吃掉续行符**：`flutter build ios ... \` 加下一行参数的写法落在 `run:` 的普通标量里，而非 `run: |` 字面块。YAML 把两行折叠成一行时保留反斜杠，shell 于是把 ` --build-number=300`（带前导空格）当成 flutter 的位置参数，报 `Target file " --build-number=300" not found`。Android 侧同名的 `--build-number` 参数因为写在 `run: |` 块里而不受影响。

## Decision

- Release 正文改成与 `tool/upload_release.sh` 同一套 awk 规则：取 `docs/user/release-notes.md` 中 `## v<version>` 段到下一个 `##` 之间；缺段即以 `::error::` 失败，不再依赖第三方动作的取段策略。
- OSS 与 iOS 构建步骤由 [Gitee ARM64 分发](2026-09-17-release-distribution-via-gitee.md)取代；这里保留首次故障的证据与版本说明提取决策。

## Alternatives considered

**保留 `ffurrer2/extract-release-notes`，只传 `changelog_file` 指向 release-notes** —— 放弃：它的取段规则是按序号而非按版本号匹配，在本仓库「每次发版新增一个版本段」的结构下取出的是上一版内容；一个取错内容的正文比没有正文更糟。

**升级到 ossutil v2 或改用 aliyun CLI** —— 放弃：`tool/upload_release.sh` 与文档都按 v1 语法写就（`cp -f` / `-e`），换版本面更大；v1 只要把凭据落到配置文件就完全可用。

**让 Release 正文从线上 `version.json` 的 `updateLog` 取** —— 放弃：等于把 `create-release` 与上传步骤的成功、以及网络可达性耦合起来，而省下的只是一段 5 行 awk。

**在 workflow 里内联签名 V1 请求（curl + openssl）替代 ossutil** —— 放弃：手写 OSS 签名易错且难验证，等于把供应商 SDK 的责任揽到自己身上。

## Consequences

- 提取规则在 `tool/upload_release.sh` 与 `tool/release.sh` 中各有一份，改格式要同改两处。
- v0.3.0 的 Android 产物与 `version.json` 由修复后的上传步骤真实产出，universal APK 的 SHA-256 与清单声明一致；iOS 失败导致 Release 被跳过，该 Release 随后手工补建。发布门禁的调整见[发布门禁只等 Android 产物](../../archived/process/2026-09-16-android-only-release-gating.md)。
- 通道形态与凭据边界的决策见[Gitee ARM64 分发](2026-09-17-release-distribution-via-gitee.md)。
