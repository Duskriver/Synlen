# Agent Note: 安装 URI 与下载落点对齐

Status: implemented

## Problem

用户点「下载并安装」后系统报「解析软件包时出现问题。(11) / open failed: ENOENT (No such file or directory)」：清单检查、APK 下载与 sha256 校验都成功，只有交给系统安装器这一步失败。

根因是两处路径声明脱节。`bb45745`（更新检查与下载移出 presentation）把落点从缓存根移进 `<缓存>/apk/synlen-<版本>.apk`，安装侧仍按旧假设拼 URI：

- 下载落点：`<cacheDir>/apk/synlen-<版本>.apk`（`update_service.dart`）
- 交给安装器的 URI：`content://<包名>.fileprovider/apk_cache/synlen-<版本>.apk`（只带文件名）
- `file_paths.xml` 的映射：`<cache-path name="apk_cache" path="." />`，即缓存根

三者本应共同指向同一个文件，实际 URI 解析到 `<cacheDir>/synlen-<版本>.apk`——`apk/` 段被丢掉，文件不存在。这三处分别在 Dart 代码、`AndroidManifest.xml` 与 `file_paths.xml` 里，互相看不见，且**没有任何测试覆盖安装 URI**；v0.3.0、v0.3.2、v0.3.3、v0.3.4 四个发布版都是这个状态。

## Decision

- 落点收成唯一声明：`UpdateService.apkRelativePath(versionLabel)` 返回 `apk/synlen-<版本>.apk`。下载按它写文件，application 把它放进 `UpdateDownloadState.apkRelativePath`。
- presentation 用 `apkContentUri(packageName, apkRelativePath)` 拼 URI，带完整相对路径；authority 后缀与映射名收在该文件的常量里，与 Android 配置成对出现。
- 契约测试 `test/features/settings/update_install_uri_test.dart` 解析真实的 `AndroidManifest.xml` 与 `file_paths.xml`，断言 authority 后缀、映射名，以及 URI 经映射后解析出的路径**等于**下载落点。反证：把 URI 拼装改回「只带文件名」，该测试报 `Expected: 'apk/synlen-9.9.9.apk' / Actual: 'synlen-9.9.9.apk'`。

## Alternatives considered

**只把 `file_paths.xml` 改成 `path="apk"`** —— 放弃：一行就能让当前两值对上，但 Dart 侧仍按「URI 只带文件名」构造，耦合藏得更深（落点再变一次又会错），且 Dart 测试无法覆盖 XML，契约照样无人守。

**让 application 直接产出 content URI** —— 放弃：authority 与 FileProvider 是 Android 平台知识，塞进 application 与[更新检查与 APK 下载移出 presentation](../architecture/2026-09-09-update-flow-out-of-presentation.md)「安装留在 presentation 薄壳」的分工冲突。

**保持现状、只在更新说明里教用户手动安装** —— 放弃：这等于承认应用内更新长期不可用；用户已经点到了「下载并安装」，失败点必须修。

## Consequences

- 修复版的应用内更新可用。**已发布的 v0.3.0–v0.3.4 无法通过应用内更新装上修复版**：执行安装的是旧版自身的代码与它编译进去的 `file_paths.xml`，改不动。旧版本用户需要手动安装一次（浏览器或发行页下载 APK），之后应用内更新恢复正常；v0.3.5 的更新说明里要写明这一步。
- 安装 URI 的契约有了守卫：改 Dart 常量、`AndroidManifest.xml` 或 `file_paths.xml` 任一处，测试都会失败并指出解析后的实际路径。
- 落点仍是缓存目录内的 `apk/` 子目录——发布侧的「复用产物」与缓存清理逻辑不受影响。

## Related

- [更新检查与 APK 下载移出 presentation](../architecture/2026-09-09-update-flow-out-of-presentation.md)：本次缺陷正是那次重构的副作用，其「真机行为未重复验证」的判断已被证伪并修正。
- [更新下载链路与备份解压加固](2026-09-09-update-backup-hardening.md)：HTTPS 与 sha256 校验的决策来源，本次不动。
