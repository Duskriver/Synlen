import 'dart:typed_data';

import 'package:synlen/src/rust/api/epub.dart' as rust_epub;

/// Rust EPUB 后端：加载、读取条目与关闭一本书的缓存条目。
///
/// 抽出接口是为了让 [EpubStreamService] 的切书与释放逻辑脱离 FFI 单测；
/// 生产实现只有 [RustEpubBackend] 一种，测试用 fake。
abstract interface class EpubBackend {
  /// 把 [epubPath] 载入 Rust 侧缓存。
  Future<void> load(String epubPath);

  /// 读取包内条目；条目不存在时返回 null。
  Future<Uint8List?> readFile({
    required String epubPath,
    required String filePath,
  });

  /// 关闭该书在 Rust 侧的缓存条目。
  Future<void> close(String epubPath);
}

/// 生产实现：直接调用 flutter_rust_bridge 生成的 API。
class RustEpubBackend implements EpubBackend {
  const RustEpubBackend();

  @override
  Future<void> load(String epubPath) => rust_epub.loadEpub(epubPath: epubPath);

  @override
  Future<Uint8List?> readFile({
    required String epubPath,
    required String filePath,
  }) => rust_epub.readEpubFile(epubPath: epubPath, filePath: filePath);

  @override
  Future<void> close(String epubPath) =>
      rust_epub.closeEpub(epubPath: epubPath);
}
