# Agent Note: 更新下载链路与备份解压加固

Status: implemented

## Problem

更新下载与备份恢复需要在接受外部文件前限制其信任范围：

1. 网络层信任面过宽：Android `AndroidManifest.xml` 设了 `usesCleartextTraffic="true"`，iOS `Info.plist` 设了 `NSAllowsArbitraryLoads`，明文 HTTP 全放行。应用内更新的 APK 直链来自远端 `version.json` 下发，下载后不做任何完整性校验，链路被降级或劫持即可投递任意安装包；下载与安装失败的异常细节还直接拼进 Toast 上屏。
2. 备份恢复解压 ZIP 时对条目数、单条目大小、总解压量均无上限，恶意备份（zip bomb）可耗尽磁盘或内存。
3. ZIP 目录可读不代表正文完整。`archive` 的磁盘解压辅助函数吞掉正文解码异常，且 `ZipDecoder.verify` 没有执行 CRC 校验；损坏的压缩正文可能留下空文件，恢复仍提交书目并报告成功。

## Decision

**网络策略收紧**

- Android：新增 `android/app/src/main/res/xml/network_security_config.xml`，`base-config` 关闭明文、只信系统 CA；Manifest 改 `usesCleartextTraffic="false"` 并挂 `networkSecurityConfig`。
- iOS：删除 `Info.plist` 整段 `NSAppTransportSecurity` / `NSAllowsArbitraryLoads`，回到 ATS 默认。
- 更新下载链路（现位于 `UpdateService.downloadApk`，见 `lib/src/features/settings/data/services/update_service.dart`）：下载前要求直链 scheme 为 `https`，否则中止并提示 `updateInsecureUrl`；下载完成后若 `version.json` 提供了 `androidApkSha256`，对文件算 SHA-256 比对，不匹配则删除文件并提示 `updateChecksumMismatch`。字段缺失时保持放行（兼容已发布的旧清单），记 warning 日志。两处 `$e` 上屏改为只给 l10n 文案，异常细节入 `appLogger`。
- `tool/upload_release.sh` 在发布时用 `shasum -a 256` 计算 universal APK 摘要并写入 `version.json` 的 `androidApkSha256`；APK 定位逻辑相应提到清单生成之前。

**备份解压上限与完整性**

- 新增 `lib/src/core/file_handling/backup_archive_guard.dart`：纯函数 `validateBackupArchiveEntries`，上限为条目数 10000、单条目 512 MiB、总量 4 GiB；条目路径拒绝绝对路径（含 Windows 盘符）与任何 `..` 段。
- `processBackupZip()` 委托 `extractVerifiedBackupZip` 读取中央目录并执行静态校验；违规抛 `BackupArchiveViolationException`，展示层映射为备份无效文案。
- 解压支持 STORE、DEFLATE、BZIP2，拒绝未知压缩方法、加密 ZIP 条目与符号链接。DEFLATE 使用 `dart:io` 原生解码 sink，输出逐块写盘并累计 CRC，避免 `archive` 原生适配器聚集整条解压结果。
- 每条实际输出不得超过目录声明大小；结束时长度与 CRC 必须一致。声明大小已受单条目与总量上限约束，实际写入也因此受限。全部条目验证成功后才返回恢复路径；任一解码、校验或写盘失败均关闭文件流，删除整个临时解压目录与缓存 ZIP，不进入数据库恢复。

## Alternatives considered

**要求 version.json 必须带摘要、缺失即拒绝下载** —— 放弃：OSS 上已发布的旧清单没有该字段，硬校验会让所有旧版本永久无法应用内更新。放行 + warning 留了迁移窗口；待旧版本占比可忽略后可收紧为强制。

**只在解压时流式计数、超限即停** —— 放弃：中央目录能提前拒绝已声明超限的备份；静态校验与实际输出计数共同约束未如实声明大小的条目。

**只给 `ZipDecoder` 传入 `verify: true`，继续使用磁盘解压辅助函数** —— 放弃：`archive 4.3.0` 中该校验实现被注释，辅助函数也吞掉解码异常，不能保证损坏备份失败。

**zip-slip 只靠 archive 包内置防护** —— 放弃：包内防护是实现细节而非契约，校验器里保留独立的路径检查作为防御层，成本极低。

## Consequences

- 已知取舍：Android WebView 加载书内引用的远程 http 图片会被网络策略阻断（https 不受影响）；书内本地资源走自定义 scheme，不受影响。
- 旧 `version.json` 无 `androidApkSha256` 时更新仍可下载，warning 日志是唯一信号；下次用 `tool/upload_release.sh` 发版后新清单自动带摘要。
- 单条目 512 MiB / 总量 4 GiB 对正常备份（EPUB 书库）是数量级余量；超限备份恢复被直接拒绝，用户只能换备份文件。
- 校验只访问缓存文件，失败不会改动现有藏书与数据库；全部条目通过才开始恢复。自行制作的备份不能含符号链接或加密 ZIP 条目。
- 更新逻辑整体移出 presentation 已由后续重构完成，见[更新检查移出 presentation](../architecture/2026-09-09-update-flow-out-of-presentation.md)。
- 发版核对清单新增一项：`androidApkSha256` 与脚本输出一致，见[发布一个版本](../../../../docs/cookbook/publishing-a-release.md)。

## Testing

- `test/core/file_handling/backup_archive_guard_test.dart` 覆盖：正常通过、条目数超限、单条目超限、总量超限、`../` 与反斜杠越界、POSIX 与 Windows 绝对路径、空条目名、边界值放行。
- `test/core/file_handling/backup_archive_extractor_test.dart` 覆盖三种压缩方法跨缓冲区解压、空文件、路径越界、符号链接与未知压缩方法；`test/features/library/data/services/backup_roundtrip_test.dart` 覆盖正常导出恢复，以及正文 DEFLATE 损坏、CRC 不符、实际长度大于或小于声明时拒绝并清理，原藏书保持完整。
- `flutter analyze` 零 error 零 warning；`dart run tool/layer_gates.dart` 通过。
- 真机验证未做：明文拦截与 APK 摘要校验的设备端行为需在下次发版窗口确认。
