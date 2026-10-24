# Agent Note: 用有界封面读取替代自有 Rust EPUB 后端

Status: implemented

## Problem

Readium 接管阅读资源后，自有 Rust 后端的生产资源调用只剩 EPUB 导入时的一张封面，却仍保留中央目录缓存、并发解压、字体还原、FFI 和原生构建链。单封面读取需要保留，专属工具链的维护收益需要重新判断。

## Decision

[CoverExtractor](../../../../lib/src/features/library/data/services/cover_extractor.dart)通过 `compute` 调用 [readEpubCover](../../../../lib/src/features/library/data/services/epub_cover_reader.dart)，使用已有 archive 依赖的文件流与 ZIP 目录读取，配合 `dart:io` 的流式 DEFLATE 解码，只解压目标封面。支持 STORE / DEFLATE、ZIP64 条目和 data descriptor，保持旧路径归一化及重名取最后一个条目的行为。

单封面的声明大小最多 50 MiB，实际输出不能超过声明大小，结束时核对长度和 CRC；读取拒绝加密、符号链接、未知压缩方法与不一致头部，文件句柄在 finally 中同步关闭。archive 会覆盖部分本地头字段，且 `ZipDecoder.decodeStream` 的 CRC 分支未启用，因此显式校验原始本地头与流式输出。缺封面返回空，异常仍由 CoverExtractor 记日志并以无封面继续导入。

图片压缩、格式兜底与 [BookFileChanges](../../../../lib/src/features/library/data/services/book_file_changes.dart)的文件补偿保持不变。自有 Rust crate、FRB 生成绑定、Cargokit、启动初始化和专属构建、测试、审计任务一并移除；Dependabot 继续覆盖 pub、npm 与 Actions。Android 原生库对齐门禁继续验证其余原生依赖。

[字体混淆决策](../feature/2026-09-09-epub-font-obfuscation.md)仍持有导入白名单与出版物保留契约，字体还原由 Readium 执行。本次不改变数据库、备份格式或已有书籍文件。

### 收益证据与边界

移除前在 `f1c602d1b7dec184008ecf4f68d749a7b40a1186` 检索非生成 Dart 调用，Rust load/read/close 均集中在封面提取器，main 仍等待初始化；原有多资源并发与缓存没有阅读调用方。已有维护事件包括 [Android 原生对齐修复](../bug-fix/2026-09-19-android-native-page-alignment.md)。本地 v0.4.0 ARM64 APK 中原生库条目为 811120 字节，约 0.77 MiB，不能等同于重建后的包体积净减少量。

2026-09-26 的 macOS arm64 探针以相同 512 KiB 随机字节模拟封面：Rust release 与 Dart AOT 各预热 5 次，取后续 20 次中位数。普通 ZIP 为 0.251 / 1.737 ms；加 128 MiB 无关内容为 0.213 / 1.602 ms；加 10000 个条目为 3.087 / 4.998 ms。Rust 更快约 1.4–1.9 ms；本决策以维护简化为收益，不宣称解压提速。探针不含 Flutter FFI、isolate、图片压缩或真机完整导入，不作为移动端 A/B。

### 与已有决策的关系

本篇落实[技术栈评估](../../proposed/architecture/2026-09-26-reader-database-stack-assessment.md)中的 Rust 候选，使[上游吸纳策略](../../proposed/process/2026-09-26-selective-lumina-upstream-adoption.md)的自有 Rust notice 候选失去适用对象。仅 Rust 脚手架的 [greet 清理决策](../../archived/simplification/2026-08-26-remove-frb-greet-demo.md)归档；字体混淆、工具链、依赖审计、发布门禁、原生对齐和导入测试决策仍有独立契约，更新当前事实并继续保留。

## Alternatives considered

**原样保留 Rust。** 单次解压更快，但单封面导入路径没有显示出足以抵偿独立工具链的收益；若未来真实样本证明 Dart 读取显著退化，再以同机完整导入数据评估。

**只延迟初始化或精简 Rust 内部缓存。** 能缩小启动依赖或实现，但仍保留 FFI、原生构建与审计成本。

**Dart 读取整本 EPUB 再解压。** 大书内存与整包大小绑定，不符合目标条目的有界读取契约。

**通过 Readium 的当前出版物读取封面。** 当前资源接口绑定阅读会话，导入不应抢占它；扩展双端无会话接口比现成 ZIP 读取增加更多维护面。

## Consequences

- 新增读取测试覆盖多块解压、Unicode、路径兼容、缺失、CRC、声明与实际大小、ZIP64、descriptor、加密与异常后的再次读取。导入测试使用真实 ZIP、文件与 SQLite 验证原图兜底、损坏封面容错、新文件回滚与已有文件恢复。
- 设备验收 `integration_test/cover_import_test.dart` 验证连续五本含 PNG 封面的 EPUB 经原生压缩产生可解码 JPEG，并验证数据库失败不残留封面与书籍；阅读 smoke 使用含封面的 EPUB 验证 Readium 链路。
- 50 MiB 限制的是 ZIP 解压后的图像文件字节，不限制图像解码后的像素内存；大量条目的中央目录仍占内存。完整真机性能、低端设备与大批量导入没有同口径 A/B，不能把桌面毫秒差或模拟器通过外推为性能等价。
