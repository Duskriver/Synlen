# Agent Note: 恢复服务拆出合并策略与 JSON 反序列化

Status: implemented

## Problem

`import_backup_service.dart` 444 行里，恢复流水线（读备份、拷文件、发进度事件）与两类纯逻辑混在一起：合并策略（元数据与阅读位置分别按各自时间戳取较新的一方、drift 秒精度比较）和备份 JSON 的反序列化。两者都只依赖仓库与 JSON，却只能通过恢复整条流水线间接验证。

## Decision

- `BackupMerger`（`data/services/backup_merger.dart`）持有两个仓库，暴露 `mergeGroups` / `mergeManifest` / `mergeBook`，保留"元数据与进度分别取较新、同秒按秒精度比较"的语义。
- `backup_json_mapper.dart` 提供纯函数 `mapToShelfGroup` / `mapToShelfBook` / `mapToBookManifest`：`id` 一律置 0，设备相关路径由调用方注入。
- `ImportBackupService` 只留流水线：进度事件、文件复制、封面回退、错误转进度事件；合并与映射分别委托。

## Alternatives considered

**把合并策略留在服务里，只拆映射函数** —— 放弃：合并策略是恢复语义的核心（较新者胜），值得有独立入口与独立测试；映射只是机械转换。

**让 `BackupMerger` 直接拿 `AppDatabase`** —— 放弃：仓库已封装软删除与进度更新的细节，绕过它会让恢复与导入两条路径的写法分叉。

**把两个仓库依赖从服务构造函数去掉** —— 放弃：`ImportBackupService` 的构造签名是对外契约（provider 与测试都在用），本批次只改文件结构。

## Consequences

- `import_backup_service.dart` 由 444 行降到 246 行，library 的超 400 行清单少一项。
- 反序列化有独立单元测试（`test/features/library/data/backup_json_mapper_test.dart`）；合并语义仍由既有恢复端到端测试覆盖。
- `_bookManifestRepository` 不再由服务持有，改由 `BackupMerger` 持有。
