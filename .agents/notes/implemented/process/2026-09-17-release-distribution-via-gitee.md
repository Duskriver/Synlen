# Agent Note: Android ARM64 更新分发走 Gitee

Status: implemented

## Problem

OSS 默认域名拒绝 APK 下载，而大陆 bucket 的自定义域名需要备案。项目尚无使用者，无需保留 OSS 客户端兼容入口。当前交付范围只有 Android ARM64，发布 AAB 与 iOS 产物增加了无消费者的构建步骤。

## Decision

- GitHub 主仓库与 Gitee 镜像以 MIT 公开自有代码，保留上游及第三方许可。Gitee `Tang_Lei789/synlen` 的 `main` 与标签由 GitHub 单向同步，`updates` 分支承载 `version.json`，Release 附件承载 APK。账号需绑定手机，客户端匿名读取，无 Gitee Token。
- 保持客户端清单协议与 SHA-256 校验策略；`AppInfo.versionEndpoint` 默认指向 Gitee raw 地址，仍支持 `SYNLEN_VERSION_URL`。客户端直接切换到 Gitee，不镜像 OSS 清单。清单里的 `githubUrl` 是已安装客户端读取的键名（不能改），值给 Gitee 附件直链：实测 `/releases/tag/<tag>` 会 302 到源码 zip（`repository/blazearchive/<tag>.zip`），Gitee 网页端下载附件还常要求登录，而附件直链匿名可用——更新弹窗的外部下载按钮读它，直接拿到 APK 最省事。
- 发布脚本从准确匹配的版本标题提取说明，创建发行版并上传 APK（Gitee 对未创建的发行版返回 HTTP 200 与 `null`，按响应内容判断是否需要创建），匿名下载验证摘要后才更新清单。禁止回退构建号、同版本替换 APK 与覆盖同名附件。清单写入携带上一版文件 SHA；流水线串行发布。
- `vX.Y.Z` 派生构建号 `X*10000+Y*100+Z`，限制 `Y`、`Z` 小于 100，避免版本映射冲突。正式包必须保持包名和签名一致；统一发布入口自动校验 APK，直接调用底层上传脚本时仍由发布者核对内部版本与签名。
- 只构建 Android ARM64 APK；GitHub `main` 推送触发源码同步，发布前再次同步源码与标签。同步脚本在临时裸仓库中从 `origin` 获取远端 `main` 与标签，只推送这批引用；开发工作区的未发布提交、本地标签及同名覆盖不进入镜像。推送保持快进，不自动覆盖 Gitee 独立提交。Gitee 写令牌来自本地凭据或 GitHub Secret `GITEE_TOKEN`；凭据不进入命令输出、安装包或匿名下载请求。

此决策取代[原 OSS 分发决策](../../archived/process/2026-08-11-release-distribution-via-oss.md)，原 [OSS 基础设施](../../archived/process/2026-09-16-release-channel-infrastructure.md)退出发布链路。构建触发方式由[默认本地发布](2026-09-17-local-release-with-manual-cloud-fallback.md)部分取代；分发协议继续有效。操作步骤由[发布手册](../../../../docs/cookbook/publishing-a-release.md)持有。

## Alternatives considered

**继续用大陆 OSS 自定义域名分发 APK**：需要域名备案，不符合当前快速独立分发的目标。

**仅用 GitHub Release**：保留为备用入口，但大陆网络下的可达性不适合作为唯一下载源。

**让客户端直接解析 Gitee Release API**：会引入新的清单解析协议，并把版本选择绑在平台行为上。公开 raw JSON 可复用现有客户端逻辑，也能独立变更 APK 托管地址。

**保留 OSS 清单镜像**：项目没有已安装用户，兼容层没有消费者，直接切换端点更简单。

**双向同步源码**：两边独立提交会引入冲突与凭据配置。GitHub 作为唯一写入源，Gitee 作为公开镜像即可满足国内浏览与下载需求。

**直接推送开发工作区的全部标签**：本地实验标签可能引用从未发布的提交，且本地同名标签不一定与 GitHub 一致。独立抓取远端引用才能保持 GitHub 作为唯一来源，不修改开发者的标签。

## Consequences

- 实测公开 raw 文件、Release API 与 30,042,819 字节的 v0.3.0 ARM64 APK 均支持匿名读取；下载摘要与 GitHub 原包一致。此结果不代表平台提供下载 SLA，也不能替代大陆手机双网络与覆盖安装验收。
- Gitee 令牌的写权限是更新通道的信任边界；SHA-256 验证完整性，不能抵御清单写账号失陷。
- 发布可能在上传 APK 后失败，留下未进入清单的附件；重试复用匹配附件。清单发布后的匿名验证若失败，先核对远端内容再重试。
- 本地测试覆盖成功发布、重复发布、摘要不匹配、禁止回退、非法版本号，以及镜像排除本地实验标签、以远端同名标签为准、无标签仓库同步；实际网络验证覆盖现有 APK 的重试发布。正式升级仍需更高版本号、同签名真机验收。
