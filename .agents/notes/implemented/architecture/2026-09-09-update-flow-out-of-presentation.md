# Agent Note: 更新检查与 APK 下载移出 presentation

Status: implemented

## Problem

`check_update_tile.dart`（396 行）把版本清单拉取与解析、语义化版本比较、Dio 下载、SHA-256 校验、FileProvider 安装与对话框 UI 混在一个 StatefulWidget 里：网络与文件逻辑无法注入 fake、错误以裸 catch + Toast 上屏、违反 presentation 不得含业务逻辑的分层约定。P0 已在此文件内补了 HTTPS 强制与 sha256 校验（见[更新下载链路与备份解压加固](../bug-fix/2026-09-09-update-backup-hardening.md)），结构性问题仍在。

## Decision

按既有分层落点拆成四层：

- **domain**：`AppVersion`（语义化版本 + split APK 构建号归一化 + 逐段比较）、`VersionManifest`（远端清单值类型，含 `androidApkSha256`）、`UpdateException` / `UpdateErrorCode`（`checkFailed`、`noUpdateChannel`、`insecureUrl`、`downloadFailed`、`checksumMismatch`），参照 `LearningErrorCode` 范式，`details` 仅入日志不上屏。
- **data**：`UpdateService`（`lib/src/features/settings/data/services/update_service.dart`）负责清单拉取与解析、本地版本读取、HTTPS scheme 校验、Dio 下载到缓存目录、sha256 比对（不匹配删文件、字段缺失放行记 warning——P0 行为原样保留），产物是安装包路径。Dio、清单端点、`PackageInfo` 读取、缓存目录解析全部经构造注入，测试用 stub `HttpClientAdapter` 替换。
- **application**：`UpdateCheck` notifier 暴露 `AsyncValue<UpdateState>`：检查阶段占满三态（loading = 检查中、error = `UpdateException`、data 带 `idle / upToDate / updateAvailable`），下载作为 data 内的子状态（进度、产物路径、失败错误码），保证下载失败不丢已渲染的清单。错误只在此捕获并转成错误码。
- **presentation**：`check_update_tile.dart` 瘦身为 259 行，只余 UI、状态订阅与按错误码映射 l10n；HTTP、版本比较、下载、校验代码全部删除。

**安装留在 UI 侧薄壳**：`android_intent_plus` 的 `canResolveActivity` / `launch` 没有可注入 seam，副作用只是拉起系统界面，与 `UrlLauncher` 同类；薄壳只消费 application 给出的安装包路径，不含判断逻辑。

## Alternatives considered

**安装也下沉 data 层、包一层自研插件接口** —— 放弃：为一个十余行的 Intent 调用引入接口 + 实现 + 测试替身三层样板，深度为负；薄壳内只剩平台胶水，无逻辑可测。

**下载失败也用 AsyncValue.error 表达** —— 放弃：error 态会顶掉 data 里已展示的清单，对话框内容随下载失败消失；下载是检查成功之后的子阶段，放进 data 内的 `UpdateDownloadState` 更符合状态机形状。

**清单获取沿用 dart:io HttpClient** —— 放弃：与下载统一走注入的 Dio，测试基建（stub adapter）与 `DeepSeekService` 一致，少一种 HTTP 路径。

## Consequences

- presentation 不再 import `dio` / `crypto` / `path_provider`；分层门禁把守着 presentation → data 的边界。
- 更新流程首次有测试：版本比较边界、HTTPS 拒绝、sha256 匹配 / 不匹配 / 缺失放行、网络失败路径，见 `test/features/settings/application/update_check_test.dart` 与 `test/features/settings/domain/app_version_test.dart`。
- 新增错误码时要同步 presentation 的 `_updateErrorMessage` 映射与双语 l10n；现有五个码均复用既有文案。
- 真机行为（FileProvider 安装、系统未知来源引导）不受本次重构影响，未重复验证。

## Testing

- `flutter test test/features/settings` 全绿；`flutter analyze` 零 error 零 warning；`dart run tool/layer_gates.dart` 通过（218 个源文件、488 条 import 边）。

## Related

- [更新下载链路与备份解压加固](../bug-fix/2026-09-09-update-backup-hardening.md)：HTTPS 与 sha256 校验的决策来源，本次只搬家不改行为。
- [组合面跨 feature 依赖](2026-09-08-composition-surface-cross-feature.md)：settings 作为组合面的分层依据。
