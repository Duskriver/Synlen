# 发布一个版本

从版本号定档到 `version.json` 上线，走这套步骤。客户端操作见[应用内更新](../user/guide/in-app-update.md)，版本记录见[版本记录](../user/release-notes.md)。

## 前置条件

- GitHub 主仓库 `Duskriver/Synlen` 与 Gitee 镜像 `Tang_Lei789/synlen` 均公开。Gitee 账号已绑定手机，`main` 存源码，`updates` 存版本清单。
- GitHub Actions 配置 `GITEE_TOKEN` 与 Android 签名 secrets。Gitee 令牌只用于发布，不编入客户端。本地使用 `gitee auth login`，或通过环境变量提供 `GITEE_TOKEN`。
- 本地发布需要 `curl`、`jq`、`shasum`。签名密钥与包名必须保持一致，保证覆盖安装。

## 源码同步

在 GitHub 提交改动；`main` 的推送触发镜像流水线，同步主分支与全部标签到 Gitee。发版流水线在上传 APK 前再次同步，确保发行版标签指向相同源码。不要在 Gitee `main` 独立提交；`updates` 不参与源码镜像。

## 步骤

1. 定版本号 `vX.Y.Z`，更新 `pubspec.yaml` 的 `version`。`versionCode` 为 `X*10000 + Y*100 + Z`，`Y`、`Z` 均小于 100；发布版本必须递增。
2. 把 `docs/user/release-notes.md` 的「未发布」小节改名为 `## vX.Y.Z`，删掉「以下内容尚未发布」那行并核对说明。发布脚本只接受完整匹配的版本标题。
3. 提交并打 tag：`git tag vX.Y.Z && git push origin vX.Y.Z`。流水线先执行质量门禁，再构建 Android ARM64 APK；不构建 AAB 或 iOS 产物。
4. CI 调用 `tool/upload_release.sh`：创建 Gitee Release、上传 APK、匿名下载并核对 SHA-256，最后提交 `version.json`。同名附件不会被覆盖，摘要不一致即失败；旧版本不能覆盖较新的清单。
5. 如需本地发布已构建的正式签名包，运行 `./tool/upload_release.sh vX.Y.Z Tang_Lei789/synlen /绝对路径/app.apk`。确认该 APK 的版本号和构建号与 tag 一致；脚本不能代替安装包元数据检查。

## 验证

1. 匿名读取 [Gitee 清单](https://gitee.com/Tang_Lei789/synlen/raw/updates/version.json)，核对 `buildNumber`、`updateLog`、`androidApkUrl` 与 `androidApkSha256`。
2. 在大陆手机 Wi-Fi 和移动网络下载 APK，并从旧版覆盖安装；确认藏书和阅读进度保留。
3. 旧版本 App 点「检查更新」，确认更新说明正确且能拉起安装器。相同版本不会提示升级，覆盖升级验收使用更高版本号。

## 故障处理

发布完成后，`build/outputs/version.json` 保存已匿名验证的清单。客户端只读取 Gitee 清单，APK 从 Gitee Release 下载。

发布失败不代表清单一定未修改：若最后的匿名验证因缓存或网络失败，先检查远端内容再重试。清单提交携带上一版文件 SHA，冲突会失败；CI 串行发布。本地发版不要与 CI 同时运行。故障恢复见[发布故障响应](handling-a-release-incident.md)，分发选择见 [Agent Note](../../.agents/notes/implemented/process/2026-09-17-release-distribution-via-gitee.md)。

## Dev Note

None.
