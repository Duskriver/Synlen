# Agent Note: 导入服务拆出格式探测、文件落盘与封面提取

Status: implemented

## Problem

`epub_import_service.dart` 568 行：导入流水线（去重、格式分发、解析、落库、回滚）与三类自成一体的能力混在一个类里——ZIP 魔数嗅探与哈希、书籍文件落盘、封面提取（含 OPF 相对路径解析与压缩）。后三者各自有明确的输入输出，却只能通过整条导入流水线验证。

## Decision

- `BookFileProbe`（`book_file_probe.dart`）：`detectFormat`（扩展名优先 + ZIP 魔数纠偏）与 `calculateHash`。
- `BookFileStore`（`book_file_store.dart`）：`copyBook`（EPUB 原样复制，支持移动源文件）与 `writeNormalizedTxt`（TXT 归一化字节落盘）。
- `CoverExtractor`（`cover_extractor.dart`）：`extract` 按 OPF 根目录解析封面条目，压缩后写入 covers 目录；失败只记日志并返回 null。

三者都是无状态具体类，服务以 `static const` 持有；`EpubImportService` 只留流水线编排与失败回滚。

## Alternatives considered

**把三个能力都做成接口注入** —— 放弃：每种只有一种实现，接口会变成假 seam；与 `ImportCacheManager`、`NativeFilePicker` 的既有做法保持一致，先拆类不提接口。

**只拆封面提取** —— 放弃：568 → 480 行仍超限，且探测与落盘同样是可独立验证的单元。

**把封面提取下沉到 `core/`** —— 放弃：它只服务导入，且依赖 `ImportWorkers.compressImage` 这一 library 侧 worker。

## Consequences

- `epub_import_service.dart` 由 568 行降到 399 行，library 的超 400 行清单少一项。
- 格式探测与文件落盘有独立单元测试（`book_file_probe_test.dart` / `book_file_store_test.dart`）。
- 封面提取仍只由导入端到端测试覆盖：它依赖 Rust 后端与图片压缩 worker，独立测需要真 EPUB 样本。
