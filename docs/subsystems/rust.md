# rust

`rust/` 是 EPUB 读取后端：解析 ZIP 中央目录并解压单个条目，经 flutter_rust_bridge 暴露给 Dart。本页 owns 这些接口、缓存语义与 codegen 流程；生产调用方是 [library](library.md) 的封面提取；[reader](reader.md) 的出版物资源由 Readium 加载。

## 职责

- 中央目录缓存：一本书只解析一次 ZIP 中央目录，之后按路径 O(1) 查条目。
- 条目解压：按需解压单个文件，不做整包解压。
- 字体混淆还原：`load_epub` 现场解析 `META-INF/encryption.xml` 与 OPF，缓存混淆字体的还原参数；`read_epub_file` 命中时还原前缀字节。
- 生命周期：书籍关闭时释放缓存元数据。
- 绑定：`rust/src/api/` 是唯一需要手写的 Rust 面，Dart 侧绑定由 codegen 生成。

## 关键类型

| 类型 | 语义 | 位置 |
|---|---|---|
| `load_epub` | 打开文件、解析 ZIP 中央目录并缓存；同路径重复调用不产生 I/O | `rust/src/api/epub.rs` |
| `read_epub_file` | 归一化路径查索引后解压单个条目；条目不存在返回 `None` | `rust/src/api/epub.rs` |
| `close_epub` | 删除该路径的缓存元数据 | `rust/src/api/epub.rs` |
| `CachedArchive` | 解析后的 ZIP 元数据 + 归一化路径索引 + 混淆字体还原参数 | `rust/src/api/epub.rs` |
| `font_obfuscation` | 字体混淆纯函数：encryption.xml / OPF 解析、IDPF 与 Adobe key 派生、前缀 XOR 还原 | `rust/src/font_obfuscation.rs` |
| `EPUB_CACHE` | 全局 `RwLock<HashMap<String, Arc<CachedArchive>>>`，键为 EPUB 绝对路径 | `rust/src/api/epub.rs` |
| `MAX_UNCOMPRESSED_BYTES` | 单条目解压上限 50 MiB，超限报错不解压 | `rust/src/api/epub.rs` |
| `loadEpub` / `readEpubFile` / `closeEpub` | Dart 侧绑定，生成物不手改 | `lib/src/rust/api/epub.dart` |
| `flutter_rust_bridge.yaml` | codegen 配置：`rust_input: crate::api`、`rust_root: rust/`、`dart_output: lib/src/rust` | 仓库根 |

## 流程

1. 打开：`BookImportService` 提取 EPUB 封面前调用 `loadEpub`；同一路径重复打开复用缓存。
2. 读取：`readEpubFile` 在读锁内只做 `Arc::clone`（微秒级），随后在私有文件句柄上顺序解压，并发读取不共享解压游标。
3. 关闭：`BookImportService` 提取封面后的 `finally` 调用 `closeEpub`。
4. codegen：改 `rust/src/api/` 后重跑 flutter_rust_bridge codegen，重新生成 `rust/src/frb_generated.rs`、`lib/src/rust/frb_generated.dart` 与 `lib/src/rust/api/*.dart`，生成物提交入库、不手改。
5. 验证：`cargo test --locked --manifest-path rust/Cargo.toml`（CI 的 rust 任务同此命令），再跑 analyze 与 EPUB 导入冒烟测试。

## 边界与不变量

- 缓存按 EPUB 绝对路径索引；同一路径重复 `load_epub` 是幂等空操作。
- 读锁只在 `Arc::clone` 期间持有，不跨 I/O 与解压。
- 条目缺失返回 `Ok(None)`，调用方按资源缺失处理；I/O 错误、解压失败与 zip 炸弹返回 `Err(msg)`。
- 音视频条目（`mp4` / `mp3` / `wav` 等扩展名）返回空字节，不解压以省内存。
- 混淆字体只收录「算法是 IDPF（前 1040 字节）或 Adobe（前 1024 字节）且 OPF manifest media-type 是字体」的条目；资源路径消解点段且不得越过容器根，identifier 合并文本、CDATA 与字符引用后派生密钥；映射构建失败退化为空映射，不阻断打开。
- 缓存无自动淘汰，书籍关闭时必须调 `close_epub`。
- `frb_generated.rs` 与 `lib/src/rust/**` 是生成物，不手改。
- `rust/build.rs` 只向 Android 动态库注入 16 KB 链接参数，覆盖调试与发布构建；产物检查见[测试策略](../testing.md#最小证据)。

## 已知限制与待办

- `api/epub.rs` 与 `font_obfuscation` 都有单元测试：中央目录解析、读取幂等、条目缺失、zip-bomb 守卫与字体混淆接线都在 Rust 侧有直接证据；Dart 侧导入测试覆盖封面读取端到端。
- 缓存无容量上限；导入任务必须在 `finally` 关闭所打开的 EPUB。
- 该后端只服务 EPUB；TXT 内容不经 Rust（见 [reader.md](reader.md)）。

## Dev Note

None.
