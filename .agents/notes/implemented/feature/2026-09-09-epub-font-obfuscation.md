# Agent Note: EPUB 字体混淆（font obfuscation）支持

Status: implemented

## Problem

`EpubZipParser` 见到 `META-INF/encryption.xml` 就拒绝导入。但 OCF 规范豁免字体资源的弱混淆：算法公开（IDPF / Adobe 两种前缀 XOR），key 就是 OPF 的 unique-identifier，不含任何授权控制。大量只做字体混淆的正版书因此被误伤，无法导入。

## Decision

导入判定由 Dart 持有，阅读时的字体还原由原生 Readium 持有，见 [Readium 引擎决策](../architecture/2026-09-20-readium-reader-engine.md)。准备层保留 identifier、字体字节与 encryption.xml，不持久化混淆映射。

- 导入侧（`epub_encryption.dart`）：每个 EncryptedData 都满足「算法是 IDPF（`http://www.idpf.org/2008/embedding`）或 Adobe（`http://ns.adobe.com/pdf/enc#RC`），且目标资源在 OPF manifest 中的 media-type 是字体」才放行；其余按 DRM 拒绝，返回 `LibraryException`（`drmProtected`），由应用层状态与 l10n 文案表达。
- OPF 的 href 相对 OPF 目录解析，CipherReference URI 相对容器根解析；百分号解码后消解路径中的 `.` 与 `..`，越过容器根的引用无效。
- [封面读取后端替代](../simplification/2026-09-26-replace-rust-cover-reader.md)移除自有 Rust 字体实现，不改变导入判定与 Readium 出版物准备契约。

## Alternatives considered

**把「混淆字体 → 算法」存进 BookManifest** —— 放弃：还原参数完全可由 EPUB 文件派生，持久化是冗余，还要付一次 Drift schema 迁移；现场派生让规则升级不碰存量数据。

**在 Dart 侧还原** —— 放弃：增加每书映射状态与资源拦截逻辑，Readium 已拥有出版物资源加载与字体还原。

**URI 兼容 OPF 相对路径** —— 放弃：规范与真实书籍都把 CipherReference URI 写成容器根相对路径；为假想写法加第二条解析规则没有样本支撑。写错的书表现为字体还原不到（缺字形），不崩溃。

**修改 identifier 或预先改写字体却保留混淆声明** —— 放弃：会破坏 Readium 的还原依据；准备层必须成套保留这些出版物资源。

## Consequences

- 仅字体混淆的 EPUB 可导入且字体正常供给；含 DRM 的书仍被拒，导入日志显示本地化文案而非原始英文错误。
- Dart 导入判定由 `test/features/library/data/parsers/epub_encryption_test.dart` 覆盖；出版物准备测试验证 identifier、字体字节与混淆声明的保留。原生字体显示仍依赖两端 Readium 的设备验收。
- 已知边界：encryption.xml 的判定要求加密目标出现在 OPF manifest 且 media-type 是字体；manifest 缺声明的字体条目会导致导入被拒而非放行。
