# 发布故障响应

发布已经上线，随后发现产物有问题（安装失败、版本号错、`version.json` 指错文件）。本手册按顺序止血、修复并留证；正常发布流程见 [publishing-a-release](publishing-a-release.md)。

## 步骤

1. **判定影响面**：确认问题版本、受影响的平台与入口（`version.json` 是否已指向问题产物、GitHub Release 是否已公开）。拉取当前清单：`curl -s https://<bucket>.oss-<region>.aliyuncs.com/version.json`。
2. **止血 `version.json`**：客户端唯一的更新入口就是它。用 `ossutil cp` 把上一次已知良好的 `version.json` 副本回传覆盖（发版时应保留上一版副本），或把 `androidApkUrl` / `androidApkSha256` 改回旧 APK 后重新上传。注意 `tool/upload_release.sh` 只会写入新版本，不会回退。
3. **处理 GitHub Release**：`gh release edit vX.Y.Z --prerelease` 降级，或删除有问题的资产；不要删除已安装用户仍可能回滚到的旧产物。
4. **发布修复版本**：用**递增的新版本号**重新走发布流程，不要重用已推的 tag，也不要改写历史 tag。
5. **通知与留证**：在 Release 说明或相关 issue 记录影响范围与处理动作。
6. **复盘**：若故障满足[事故复盘](../postmortem/README.md)的条件（微妙、系统性、重新发现代价高），补一篇复盘并链接本次新增的护栏。

## 验证

1. `curl` 输出的 `version.json` 中 `buildNumber` 与 `androidApkSha256` 指向回退后的产物。
2. 旧版本 App 点「检查更新」不再提示问题版本；如仍提示，检查 CDN / 浏览器缓存。
3. 新修复版本发布后，`version.json` 的摘要与脚本输出的 APK 摘要一致（见 [publishing-a-release](publishing-a-release.md#验证)）。

## 约束

- 已安装问题版本的设备不会被自动降级，只能靠更高版本号覆盖安装修复。
- 保留每个已发布版本的 APK：回退 `version.json` 与用户重装都依赖它。
- 发布回滚是人工操作，没有自动化；执行时以 `version.json` 为先，其次才是 Release 页面。

## Dev Note

None.
