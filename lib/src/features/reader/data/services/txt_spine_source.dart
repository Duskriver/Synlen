import 'package:synlen/src/features/library/domain/book_manifest.dart';

/// TXT 章节供给所需的 spine 来源。
///
/// reader 的 data 层不直接认识 library 的仓库：宿主 application 用书目查询接口
/// （`BookQueries`）适配出生产实现，测试用 fake——两种实现，故不是假 seam。
abstract interface class TxtSpineSource {
  /// 按文件哈希取 spine；书目或阅读清单不存在时返回 null。
  Future<List<SpineItem>?> spineFor(String fileHash);
}
