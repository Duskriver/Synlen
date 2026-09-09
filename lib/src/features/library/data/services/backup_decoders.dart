/// 备份格式版本分派：shelf.json 与每书 manifest json 顶层的 `version` 字段
/// 在此消费。
///
/// `version` 从格式第一版起就由导出端写入；缺失视为异常，按 1 处理并记
/// warning。声明版本高于 [kBackupFormatVersion] 时抛
/// [LibraryException]（[LibraryErrorCode.backupVersionTooNew]），恢复中止，
/// 绝不按旧格式静默错解。
///
/// 未来格式演进：为 v2 写一个 decoder 并注册进 `_shelfDecoders` /
/// `_manifestDecoders` 即可，旧版本 decoder 保留以兼容旧备份。
library;

import 'package:synlen/src/core/database/app_database.dart';
import 'package:synlen/src/core/services/app_logger.dart';

import '../../domain/library_exception.dart';
import 'backup_json_mapper.dart';

/// 当前支持的最高备份格式版本；导出端写入的 version 即取此值。
const int kBackupFormatVersion = 1;

/// shelf.json 的解码结果：分组与书目的 JSON 列表。
typedef ShelfBackupData = ({
  List<Map<String, dynamic>> groups,
  List<Map<String, dynamic>> books,
});

typedef _ShelfDecoder = ShelfBackupData Function(Map<String, dynamic> json);
typedef _ManifestDecoder = BookManifest Function(Map<String, dynamic> json);

/// version → shelf.json decoder 注册表。
final Map<int, _ShelfDecoder> _shelfDecoders = {1: _decodeShelfV1};

/// version → manifest json decoder 注册表。
final Map<int, _ManifestDecoder> _manifestDecoders = {1: mapToBookManifest};

/// 按 shelf.json 顶层 `version` 分派解码，返回分组与书目列表。
ShelfBackupData decodeShelfBackup(Map<String, dynamic> json) {
  final version = _readVersion(json, 'shelf.json');
  final decoder = _shelfDecoders[version];
  if (decoder == null) {
    _throwUnknownVersion(version, 'shelf.json');
  }
  return decoder(json);
}

/// 按 manifest json 顶层 `version` 分派解码为 [BookManifest]；
/// [source] 是清单文件名（如 `book-a.json`），仅用于日志与异常定位。
BookManifest decodeManifestBackup(
  Map<String, dynamic> json, {
  required String source,
}) {
  final version = _readVersion(json, source);
  final decoder = _manifestDecoders[version];
  if (decoder == null) {
    _throwUnknownVersion(version, source);
  }
  return decoder(json);
}

int _readVersion(Map<String, dynamic> json, String source) {
  final raw = json['version'];
  if (raw == null) {
    appLogger.w('[BackupDecoder] $source 缺少 version 字段，按 1 处理');
    return 1;
  }
  if (raw is! int) {
    throw FormatException('$source 的 version 字段不是整数: $raw');
  }
  return raw;
}

Never _throwUnknownVersion(int version, String source) {
  if (version > kBackupFormatVersion) {
    // 版本来源与声明的版本号只作 details 入日志；用户文案由错误码映射。
    throw LibraryException(
      LibraryErrorCode.backupVersionTooNew,
      '$source: version $version > $kBackupFormatVersion',
    );
  }
  throw FormatException('$source 声明了未知备份版本: $version');
}

ShelfBackupData _decodeShelfV1(Map<String, dynamic> json) => (
  groups: (json['groups'] as List<dynamic>).cast<Map<String, dynamic>>(),
  books: (json['books'] as List<dynamic>).cast<Map<String, dynamic>>(),
);
