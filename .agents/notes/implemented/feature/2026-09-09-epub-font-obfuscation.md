# Agent Note: EPUB 字体混淆（font obfuscation）支持

Status: implemented

## Problem

`EpubZipParser` 见到 `META-INF/encryption.xml` 就拒绝导入。但 OCF 规范豁免字体资源的弱混淆：算法公开（IDPF / Adobe 两种前缀 XOR），key 就是 OPF 的 unique-identifier，不含任何授权控制。大量只做字体混淆的正版书因此被误伤，无法导入。

## Decision

判定在 Dart 导入侧，还原在 Rust 供给侧，两侧各自从 EPUB 文件解析 `encryption.xml`，不持久化任何映射：

- 导入侧（`epub_encryption.dart`，`EpubZipParser` 的 part 文件）：每个 EncryptedData 都满足「算法是 IDPF（`http://www.idpf.org/2008/embedding`）或 Adobe（`http://ns.adobe.com/pdf/enc#RC`），且目标资源在 OPF manifest 中的 media-type 是字体」才放行；其余（未知算法如 LCP、加密内容文档、清单畸形）按 DRM 拒绝，返回 `LibraryException`（`drmProtected`），`ProgressDialog` 渲染日志时按错误码映射为 l10n 文案 `importFailedDrm`（见 [library 错误模型统一](../architecture/2026-09-09-library-typed-error-codes.md)）。
- 供给侧（`rust/src/font_obfuscation.rs` 纯函数模块）：`load_epub` 现场读 `encryption.xml` + `container.xml` + OPF，派生「归一化路径 → (XOR key, 前缀长度)」映射存进 `CachedArchive`；`read_epub_file` 命中混淆字体时还原前缀字节（IDPF 前 1040、Adobe 前 1024）。key 派生：IDPF 为去空白后 identifier 的 SHA-1，Adobe 为 UUID 去前缀去连字符的 16 字节。映射构建失败退化为空映射，不阻断打开。
- 两侧用同一条收录规则（已知算法 + manifest 字体 media-type）。OPF 的 href 相对 OPF 目录解析，CipherReference URI 相对容器根解析；百分号解码后消解路径中的 `.` 与 `..`，越过容器根的引用无效。Dart 决定能不能进，Rust 决定还原哪些字节，规则各自独立成立。
- Rust 在 identifier 闭合时才合并提交文本，保留普通文本、CDATA、XML 预定义实体与数字字符引用的完整值，再派生字体密钥；无法解析的实体不产生猜测密钥。

## Alternatives considered

**把「混淆字体 → 算法」存进 BookManifest** —— 放弃：还原参数完全可由 EPUB 文件派生，持久化是冗余，还要付一次 Drift schema 迁移；现场派生让规则升级不碰存量数据。

**在 Dart 侧（`EpubStreamService`）还原** —— 放弃：需要在 Dart 层为每本书维护映射状态，而 Rust 已有按书缓存的 `CachedArchive`，字节流出口就在 `read_epub_file`，在出口处还原侵入最小；frb API 签名不变，不用重新 codegen，Dart 供给链零改动。

**URI 兼容 OPF 相对路径** —— 放弃：规范与真实书籍都把 CipherReference URI 写成容器根相对路径；为假想写法加第二条解析规则没有样本支撑。写错的书表现为字体还原不到（缺字形），不崩溃。

**只在导入侧消解路径点段** —— 放弃：虽然书籍可以导入，Rust 仍无法匹配同一字体，供给的字节保持混淆；路径解析必须在两侧一致。

## Consequences

- 仅字体混淆的 EPUB 可导入且字体正常供给；含 DRM 的书仍被拒，导入日志显示本地化文案而非原始英文错误。
- `rust/Cargo.toml` 使用 `sha1` 与 `quick-xml 0.42`；字体还原不改变 frb 接口。
- Rust 测试覆盖 1040 / 1024 字节边界、字体判定、路径点段及 XML 文本编码后的实际字体字节还原；Dart 导入判定测试在 `test/features/library/data/parsers/epub_encryption_test.dart`，覆盖相同路径与容器根边界。
- 已知边界：encryption.xml 的判定要求加密目标出现在 OPF manifest 且 media-type 是字体；manifest 缺声明的字体条目会导致导入被拒而非放行。
