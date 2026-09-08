# Agent Note: 规则由门禁执行，而不是靠评审记得

Status: implemented

## Problem

文档标准里有两条规则只写在散文里：`docs/` 页面以 `## Dev Note` 收尾、术语表的"禁用别称"不得被当成代码标识符。前者已经漏掉两个页面，后者从未被执行过——术语表把 `AppTheme` 列为 `AppThemeSettings` 的别称，而 `lib/src/core/theme/app_theme.dart` 里 `AppTheme` 是一个真实类型。发版路径也没有跑文档门禁：`build_release.yml` 的 quality-gates 只做 analyze、测试与生成物漂移，打 tag 可以带着坏文档出门。

## Decision

- `tool/doc_gates.dart` 新增两项检查：`docs/` 页面的最后一节必须是 `## Dev Note`；术语表禁用别称列里标识符形式的别名不得在 `lib/` 被声明为类型（中文别称与短语仍靠评审）。
- 发布前置门禁（`build_release.yml` 的 quality-gates）加 `dart run tool/doc_gates.dart`，与 PR 走同一道校验。
- `tool/upload_release.sh` 在 release notes 里找不到 `## vX.Y.Z` 段时中止，而不是发布一个 `updateLog` 为空的版本。
- `tool/doc-budgets.json` 从 17 份扩到 28 份，把 cookbook、user 页与 `README.md` 纳入上限；`docs/user/release-notes.md` 按版本追加，明确不设上限。

## Alternatives considered

**继续靠评审发现** —— 放弃：这两条规则都已漏过，没有执行者的规则等于没有规则。

**把检查写进 Dart lint** —— 放弃：检查对象是 Markdown 与跨文件一致性，不是单个 Dart 文件的语法。

**让上传脚本保持只警告** —— 放弃：更新说明为空对用户是可见缺陷，宁可让发版在此时失败。

## Consequences

- 新规则要配门禁，否则不进 [文档标准](../../../../docs/AGENTS.md)。
- 门禁输出会报告各项核对数量，便于发现"检查悄悄没跑"。
- 别称检查只覆盖标识符形式的别名；中文别称的清理仍由评审负责。
