# 发布一个版本

默认在本机检查、构建并上传同一份 APK 到 GitHub 与 Gitee，最后更新 `version.json`。客户端操作见[应用内更新](../user/guide/in-app-update.md)，版本记录见[版本记录](../user/release-notes.md)。

## 前置条件

- GitHub 主仓库 `Duskriver/Synlen` 与 Gitee 镜像 `Tang_Lei789/synlen` 均公开。Gitee 账号已绑定手机，`main` 存源码，`updates` 存版本清单。
- 按[开发环境](../development.md#环境)配置 Flutter、Rust 与 Node；安装 Android SDK Build-Tools 并设置 `ANDROID_HOME`。命令另需 `gh`、`curl`、`jq`、`shasum` 与 `unzip`。
- 使用 `gh auth login` 与 `gitee auth login`，或提供 `GH_TOKEN` 与 `GITEE_TOKEN`。Gitee 令牌只用于发布，不编入客户端。
- 本地 `android/key.properties` 指向正式签名密钥，凭据文件不提交。APK 校验会拒绝 debug 签名，保证可以覆盖安装。

## 源码同步

GitHub 是源码的唯一写入源；`main` 推送触发镜像同步，发布命令在上传前再次同步主分支与标签。不要在 Gitee `main` 独立提交；`updates` 不参与源码镜像。推送 tag 不自动构建 APK。

## 步骤

1. 定版本号 `vX.Y.Z`，更新 `pubspec.yaml` 的 `version`。`versionCode` 为 `X*10000 + Y*100 + Z`，`Y`、`Z` 均小于 100；发布版本必须递增。
2. 把 `docs/user/release-notes.md` 的「未发布」小节改名为 `## vX.Y.Z`，删掉「以下内容尚未发布」那行并核对说明。发布脚本只接受完整匹配的版本标题。
3. 在 `main` 提交全部改动，保持工作区干净；先不打 tag。执行 `./tool/release.sh vX.Y.Z`，命令先跑发布门禁，再构建 Android ARM64 APK，校验包名、版本、构建号、16 KB 对齐与正式签名。
4. 命令推送源码与 tag、同步 Gitee，上传并下载验证 GitHub 附件，然后调用 `tool/upload_release.sh` 发布 Gitee 并更新清单。同名附件不会被覆盖，摘要不一致即失败；旧版本不能覆盖较新的清单。
5. 保留 `build/outputs/` 中的 `.apk` 与 `.apk.json`：构建记录绑定源码提交与文件摘要。重试时在同一提交执行 `./tool/release.sh vX.Y.Z --apk /绝对路径/synlen-vX.Y.Z-arm64-release.apk`；它仍执行门禁，但复用原包。

## 只准备产物

执行 `./tool/release.sh vX.Y.Z --prepare-only` 完成检查、构建和校验，不推送源码或 tag，不上传。正式发布时按上面的 `--apk` 命令复用产物；同名产物存在时不会重新编译覆盖。

## 手动云构建

1. GitHub Actions 配置 `GITEE_TOKEN` 与 Android 签名 secrets；提交的 tag 中必须包含 `tool/release.sh`。
2. 本地先完成推送前门禁，再推送源码与 tag。执行 `gh workflow run build_release.yml --ref main -f version=vX.Y.Z`。工作流检出该 tag，准备环境并执行相同发布命令。
3. 上传失败时从运行的 `android-artifacts` 下载 APK 与构建记录，检出同一 tag 后用 `--apk` 重试。不要重新构建来替换同版本文件。

## 验证

1. 匿名读取 [Gitee 清单](https://gitee.com/Tang_Lei789/synlen/raw/updates/version.json)，核对 `buildNumber`、`updateLog`、`androidApkUrl` 与 `androidApkSha256`。
2. 在大陆手机 Wi-Fi 和移动网络下载 APK，并从旧版覆盖安装；确认藏书和阅读进度保留。
3. 旧版本 App 点「检查更新」，确认更新说明正确且能拉起安装器。相同版本不会提示升级，覆盖升级验收使用更高版本号。

## 故障处理

发布完成后，`build/outputs/version.json` 保存已匿名验证的清单。客户端只读取 Gitee 清单，APK 从 Gitee Release 下载。

发布失败不代表清单一定未修改：若最后的匿名验证失败，先检查远端再重试。清单提交携带上一版文件 SHA，冲突会失败；云端串行发布，本地命令有进程锁，并拒绝与已运行或排队的云发布并行。发布期间不要另行启动云任务或从另一台电脑发布。异常中断留下 `.git/synlen-release.lock` 时，确认无发布进程后再清理。

故障恢复见[发布故障响应](handling-a-release-incident.md)，构建方式见[本地发布决策](../../.agents/notes/implemented/process/2026-09-17-local-release-with-manual-cloud-fallback.md)，分发选择见 [Gitee 决策](../../.agents/notes/implemented/process/2026-09-17-release-distribution-via-gitee.md)。

## Dev Note

None.
