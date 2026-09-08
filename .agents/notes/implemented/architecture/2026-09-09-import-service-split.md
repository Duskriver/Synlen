# Agent Note: 导入服务拆出平台选择器与备份路径模型

Status: implemented

## Problem

`unified_import_service.dart` 618 行里混着三件事：MethodChannel 选择器调用（十个 `_pick*` 方法，Android / iOS 各一套）、备份 ZIP 的分桶与路径装配（纯字符串逻辑）、以及导入门面本身的缓存与哈希编排。改任意一侧都要读整份文件，纯逻辑也因为没有独立入口而只能经服务间接测。

## Decision

- `NativeFilePicker`（`native_file_picker.dart`）持有 MethodChannel 与平台分支：`pickFiles` / `pickFolder` / `pickBackupFolder` / `pickBackupZipFile` / `pickFontFiles` / `resolveDisplayName` / `fetchIosFileToTemp` / `releaseIosAccess`。
- `BackupPaths` / `BackupPathsForBook` 与纯函数 `classifyBackupEntries` / `buildBackupBookPaths` 移到 `backup_paths.dart`。
- `UnifiedImportService` 保留公开门面：缓存与哈希、备份 ZIP 解压、字体缓存，选择器调用委托 `NativeFilePicker`；构造函数可注入 `picker`，与既有的 `cacheManager` 注入同形。

`file_handling.dart` 桶文件导出新文件，调用方 import 不变。

## Alternatives considered

**让调用方各自注入 `NativeFilePicker`，服务不再转发** —— 放弃：会改动 library 与 settings 的 4 处调用点、`UnifiedImportService` 的 mock 与 `LocalBackupImport` 测试子类；本批次是拆文件，不是改接口。

**把 `releaseIosAccess` 等直接下沉到 picker，服务不再暴露** —— 放弃：`ImportBackupService` 与 `FontManagerNotifier` 经服务调用它，且测试子类正是靠覆盖该方法验证释放时机。

**用 part 文件拆分** —— 放弃：Dart 没有 partial class，实例方法无法跨 part 归属，只能退化成顶层函数传参，反而更绕。

## Consequences

- `unified_import_service.dart` 由 618 行降到 221 行，core 的超 400 行清单只剩 `color_schemes.dart`。
- 备份分桶与装配有了独立单元测试（`test/core/file_handling/backup_paths_test.dart`）。
- `NativeFilePicker` 是具体协作对象而非接口：生产只有一种实现，与 `ImportCacheManager` 一致；真要替换时再提接口。
