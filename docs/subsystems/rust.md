# rust

`rust/` 是 EPUB 读取后端：解析 ZIP 中央目录并解压单个条目，经 flutter_rust_bridge 暴露给 Dart。本页 owns 这些接口、缓存语义与 codegen 流程；调用方见 [reader.md](reader.md)。

## 职责

- 中央目录缓存：一本书只解析一次 ZIP 中央目录，之后按路径 O(1) 查条目。
- 条目解压：按需解压单个文件，不做整包解压。
- 生命周期：书籍关闭时释放缓存元数据。
- 绑定：`rust/src/api/` 是唯一需要手写的 Rust 面，Dart 侧绑定由 codegen 生成。

## 关键类型

| 类型 | 语义 | 位置 |
|---|---|---|
| `load_epub` | 打开文件、解析 ZIP 中央目录并缓存；同路径重复调用不产生 I/O | `rust/src/api/epub.rs` |
| `read_epub_file` | 归一化路径查索引后解压单个条目；条目不存在返回 `None` | `rust/src/api/epub.rs` |
| `close_epub` | 删除该路径的缓存元数据 | `rust/src/api/epub.rs` |
| `CachedArchive` | 解析后的 ZIP 元数据 + 归一化路径索引 | `rust/src/api/epub.rs` |
| `EPUB_CACHE` | 全局 `RwLock<HashMap<String, Arc<CachedArchive>>>`，键为 EPUB 绝对路径 | `rust/src/api/epub.rs` |
| `MAX_UNCOMPRESSED_BYTES` | 单条目解压上限 50 MiB，超限报错不解压 | `rust/src/api/epub.rs` |
| `loadEpub` / `readEpubFile` / `closeEpub` | Dart 侧绑定，生成物不手改 | `lib/src/rust/api/epub.dart` |
| `flutter_rust_bridge.yaml` | codegen 配置：`rust_input: crate::api`、`rust_root: rust/`、`dart_output: lib/src/rust` | 仓库根 |

## 流程

1. 打开：`EpubStreamService.openBook` → `loadEpub`；同一路径重复打开复用缓存，切换书籍时先关掉旧缓存。
2. 读取：`readEpubFile` 在读锁内只做 `Arc::clone`（微秒级），随后在私有文件句柄上顺序解压，多个 WebView 拦截请求可并行。
3. 关闭：阅读侧 `EpubStreamService.dispose` 与导入侧 `EpubImportService` 提取封面后的 `finally` 都调 `closeEpub`。
4. codegen：改 `rust/src/api/` 后重跑 flutter_rust_bridge codegen，重新生成 `rust/src/frb_generated.rs`、`lib/src/rust/frb_generated.dart` 与 `lib/src/rust/api/*.dart`，生成物提交入库、不手改。
5. 验证：`cargo test --locked --manifest-path rust/Cargo.toml`（CI 的 rust 任务同此命令），再跑 analyze 与阅读器冒烟测试。

## 边界与不变量

- 缓存按 EPUB 绝对路径索引；同一路径重复 `load_epub` 是幂等空操作。
- 读锁只在 `Arc::clone` 期间持有，不跨 I/O 与解压。
- 条目缺失返回 `Ok(None)`，调用方按 404 处理；I/O 错误、解压失败与 zip 炸弹返回 `Err(msg)`。
- 音视频条目（`mp4` / `mp3` / `wav` 等扩展名）返回空字节，不解压以省内存。
- 缓存无自动淘汰，书籍关闭时必须调 `close_epub`。
- `frb_generated.rs` 与 `lib/src/rust/**` 是生成物，不手改。

## 已知限制与待办

- `rust/src/` 没有 `#[test]`，`cargo test` 只能证明可编译；解析与解压的正确性由 Dart 侧导入与阅读测试间接覆盖。
- 缓存无容量上限：`EpubStreamService` 为 keepAlive，只在自身销毁时关闭当前书，同一会话内连续打开多本书会累积缓存条目。
- 该后端只服务 EPUB；TXT 内容不经 Rust（见 [reader.md](reader.md)）。

## Dev Note

None.
