# TXT 支持批次暴露的四类导入与渲染缺口

## 执行摘要

2026-08-29 的 TXT 支持批次第一次把"导入 → 落库 → 阅读"整条链路跑通，也在同批自测里暴露四个各自独立的缺陷：导入在对话框订阅前就中断、章节 XHTML 缺命名空间导致分页失效、新书显式写主键导致 upsert 覆盖上一本书、失败回滚从未真正删除文件。四个缺陷全部通过了评审与既有单元测试——因为当时没有任何测试走过"导入一本书并读它"的完整路径。教训：新增格式支持这类跨层链路，必须有一条端到端验收，不能指望各层单测拼起来等于链路正确。

## Summary

- 四个缺陷分别落在导入编排、XHTML 生成、落库主键与文件回滚四处，同批修复并各带回归测试。
- TXT 是第一个走完整链路的新格式，把原本只被 EPUB 单测覆盖的路径推到端到端。
- 没有一条既有测试能拦住它们：单测各自绿灯，链路无人走通。

## Timeline

- 2026-08-29：TXT 支持批次合入（`feat(library): 支持 TXT 格式书籍导入与阅读`）。
- 2026-08-29：同批自测依次暴露四个缺陷，修复并补回归测试。
- 2026-09-08：学习链路端到端验收补齐，覆盖真机 WebView 与真实接口。

## Root cause

1. `LibraryNotifier` 是 autoDispose，`importPipelineStream` 是 `async*`：方法体推迟到调用方订阅流之后才执行，而调用方只 `ref.read` 不监听，provider 先被销毁，导入必然中断。根因是把"流被订阅"当成理所当然。
2. TXT 章节 XHTML 缺 `xmlns`：按 `application/xhtml+xml` 解析时元素没有 HTML 语义，分页引擎注入样式失败、段落被展平。
3. `saveBook` / `saveManifest` 对新书（`id = 0`）显式写主键 `rowid` 0，第二次导入的 upsert 命中同一行，把上一本书整行覆盖——书架上永远只剩最后一本。
4. 导入失败回滚调 `_deleteFile(绝对路径)`，而该方法把入参当相对路径再拼 `documentsPath`，拼出的路径不存在，回滚从未真正删除文件；删除也没有 await，存在竞态。

## Guardrails

- 四条各带回归测试：`test/features/library/application/library_notifier_test.dart`（订阅时序）、`test/features/reader/data/txt_content_service_test.dart`（`xmlns`）、`test/features/library/data/shelf_book_repository_test.dart`（`id = 0` 自增）、`test/features/library/data/services/txt_import_test.dart`（失败回滚删除文件）。
- `LibraryNotifier` 改为 `@Riverpod(keepAlive: true)`，不变量写进 [library 子系统](../subsystems/library.md#边界与不变量)。
- 端到端验收 `integration_test/learning_e2e_test.dart` 覆盖"导入 → 打开 → 点词 / 长按"的真机链路，见 [测试](../testing.md#现状)。

## Dev Note

None.
