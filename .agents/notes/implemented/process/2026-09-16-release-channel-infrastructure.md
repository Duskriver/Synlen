# Agent Note: 更新分发通道的 OSS 基础设施

Status: implemented

## Problem

应用内更新依赖 OSS 上的 `version.json` 与 APK 直链，但账号里没有任何 bucket——客户端硬编码的端点 `https://synlen.oss-cn-hangzhou.aliyuncs.com/version.json` 匿名访问返回 `NoSuchBucket`，CI 也没有可用的上传凭据。这条通道同时是**信任根**：谁能写这个 bucket，谁就能给全体已安装用户投递任意 APK，所以凭据的授予方式与匿名可达范围都必须一次定对。

## Decision

**通道形态**

- bucket `synlen`，地域 `cn-hangzhou`，ACL `public-read`。地域与桶名跟 `lib/src/core/config/app_info.dart` 里 `AppInfo.versionEndpoint` 的硬编码一致，因此不必为建通道改代码、重新发版。
- 关闭桶级「阻止公共访问」（`BlockPublicAccess=false`）。新建桶默认开启该开关，它会静默架空 `public-read` ACL：实测桶 ACL 已是 `public-read` 而匿名请求仍返回 `AccessDenied`（`because of bucket acl`），关闭后同一请求变为 `NoSuchKey`（对象不存在但读取被允许）。

**APK 直链的硬约束（v0.3.0 发布当天实测）**

OSS 禁止用默认域名分发 `.apk` / `.ipa`：2023-08-15 之后创建的桶，匿名或签名请求访问这两类扩展名的对象都返回 400 `ApkDownloadForbidden`，提示 "please use CNAME instead"。实测 `cn-hangzhou` 与 `cn-hongkong` 两个地域都返回同一错误，传输加速域名也在官方说明的阻断范围内，所以**换地域绕不开**；同一桶内的非 `.apk` 对象（实测 `.bin`）匿名读取正常，说明拦截按扩展名生效，与 ACL 和对象内容无关。

结果是通道分裂：`version.json` 走默认域名可用，`androidApkUrl` 指向的 APK 走默认域名必然 400，应用内「下载并安装」拿不到包。官方给出的通路是自有域名 CNAME 到桶：大陆地域的桶用自定义域名须完成 ICP 备案，海外地域的桶不需要。该直链是清单下发的数据而非客户端硬编码，换域名只需改 `version.json`，不必重新发版。

**此为当前唯一未决项**：域名来源与是否备案待定，未决期间 Android 的更新入口靠 GitHub Release 附件的备选按钮。

**凭据边界**

- 匿名可达范围：**单个对象可读、列表不可枚举**（实测匿名 `GET /version.json` 通过，匿名 `GET /?max-keys=3` 被拒）。知道 URL 就能下载，不知道就不能遍历。
- 新增 RAM 用户 `synlen-ci` 与自定义策略 `synlen-oss-publish`：只允许该 bucket 的对象读写（`oss:PutObject` / `GetObject` / `ListObjects` / 分片上传相关动作），**不含删除**，不涉及其它产品。
- 该用户的 AccessKey 写入 GitHub Secrets 的 `OSS_ACCESS_KEY_ID` / `OSS_ACCESS_KEY_SECRET` / `OSS_BUCKET` / `OSS_REGION`，供 `build_release.yml` 上传步骤使用。root 凭据不进 CI。

## Alternatives considered

**CI 直接用账号 root 的 AccessKey** —— 放弃：CI 是密钥最可能外泄的位置（fork、日志、第三方动作），root 泄露等于整个账号失守。RAM 子账号把爆炸半径限制在这一个 bucket 的写入上。

**给 CI 用户保留删除权限** —— 放弃：发布只需要写。删除能力不会让发版更容易，只会放大密钥泄露的后果——拿到密钥的人可以从线上抹掉已发布的 APK。实测该身份删除对象被拒（403），这是预期行为而非配置缺陷。

**换一个更近的地域或自定义域名** —— 放弃：端点写死在客户端，换地域或域名都要改代码、重新发版，而 `cn-hangzhou` 对大陆用户已经足够；自定义域名指向大陆 OSS/CDN 还需 ICP 备案，默认 `aliyuncs.com` 域名不需要。

**改用 CDN 加速分发，或自建更新服务** —— 放弃：前者要等出现真实的下载瓶颈再做，加一层只是增加配置面；后者与「无后端」定位冲突，已在[更新分发走阿里云 OSS](2026-08-11-release-distribution-via-oss.md)里否决过。

## Consequences

- 桶名在 OSS 全局唯一。`synlen` 已由本账号占用；将来若重建或迁桶，必须同名同地域，否则要同步改 `AppInfo.versionEndpoint` 并重新发版，否则老客户端的检查更新会直接失败。
- `version.json` 与其中的 `androidApkSha256` 同源同桶：摘要校验防的是传输环节被篡改，防不住能改写清单的人。这条链路的安全性最终等于该 bucket 写权限的保管水平。
- 公共读桶按量计费且可被第三方刷流量，建议在费用中心设预算告警；列表不可枚举意味着攻击者仍需知道确切文件名，成本比可枚举时高。
- 桶级「阻止公共访问」是新建桶的默认值，重建桶或迁地域时容易再次踩到——症状是客户端只报「检查更新失败」，很难反推到 ACL 之外的这一层。
