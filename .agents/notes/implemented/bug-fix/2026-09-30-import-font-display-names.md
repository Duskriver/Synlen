# Agent Note: 字体导入使用 SAF 显示名

Status: implemented

## Problem

Android SAF 的文档 ID 可以是纯数字，不能据此取得真实文件名。字体导入直接使用 URI 推断名称时，字体列表显示数字，落盘名称也丢失真实后缀。

## Decision

[UnifiedImportService](../../../../lib/src/core/file_handling/unified_import_service.dart)提供 `resolveFileName`，书籍与字体共用现有原生显示名查询；查询为空或不可用时沿用路径名。[FontManagerNotifier](../../../../lib/src/features/settings/application/font_manager_notifier.dart)在落盘前取 basename，统一路径分隔符并替换控制字符与平台保留字符；空名、`.` 与 `..` 拒绝导入。同名仍覆盖文件且只登记一次，文件选择后的目录创建与处理都由 finally 释放原生访问。

本决策落实[上游吸纳研究](../../proposed/process/2026-09-26-selective-lumina-upstream-adoption.md)的字体候选；[字体编解码](../simplification/2026-09-09-imported-font-codec.md)继续拥有列表格式，本决策不改写既有文件名或阅读设置，没有整篇取代的笔记。

## Alternatives considered

**继续从 URI 末段推断名称。** 放弃：数字文档 ID 没有可恢复的真实名称与扩展名。

**给所有无法推断的文件名猜一个字体后缀。** 放弃：显示名查询已有真实信息；查询失败时猜类型可能把 OTF 当成 TTF，也不能恢复原始名称。

## Consequences

回归覆盖数字 SAF ID、双平台分隔符、控制字符、后缀保留、同名策略、无法落盘的名称、目录创建失败、缓存清理与原生访问释放。原生查询不可用时只能保留路径提供的名称；已有数字文件名不迁移，用户重新导入时取得新名称。
