# Agent Note: 已导入字体的编解码抽成纯函数

Status: implemented

## Problem

`FontManagerNotifier` 的 `build()` 与 `_persist()` 各写一半持久化逻辑：一边 jsonDecode + 容错过滤，一边 jsonEncode。两端格式必须一致，却分散在 notifier 里，且没有测试——字体列表被写坏时只会静默变成空列表。

## Decision

`imported_font_codec.dart`（settings/domain）：`decodeImportedFonts(String?)` 与 `encodeImportedFonts(List<ImportedFont>)`。解析对 null、非法 JSON、非字符串条目容错；notifier 只负责读写 prefs。

## Alternatives considered

**留在 notifier 里加测试** —— 放弃：测试要构造 ProviderContainer 与 prefs，而这段逻辑与 Riverpod 无关。

**把编解码放进 `ImportedFont`** —— 放弃：领域值对象不该知道磁盘格式（文件名数组）。

## Consequences

- 编解码有 5 个单元测试（含往返与脏数据容错），字体列表格式被钉住。
- notifier 少两处格式细节，`dart:convert` 依赖随之移出。
