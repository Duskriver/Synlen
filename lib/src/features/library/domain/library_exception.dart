/// 藏书模块领域错误码：展示层据此映射为本地化文案（规范 §5：用户文案与内部细节分离）。
///
/// 覆盖 import / backup 主链路的失败语义；分组 CRUD 等其余链路仍是
/// `Either<String, T>`，迁移时在此补码。
enum LibraryErrorCode {
  /// 所选文件无法读取（I/O 或哈希计算失败），细节见 [LibraryException.details]
  fileUnreadable,

  /// 书籍解析失败（EPUB/TXT 结构或编码问题），细节见 [LibraryException.details]
  parseFailed,

  /// EPUB 含 DRM 加密，拒绝导入（仅字体混淆放行）
  drmProtected,

  /// 书籍已存在于书架，重复导入被拒绝
  duplicateBook,

  /// 书籍文件落盘失败（复制 EPUB / 写归一化 TXT），细节见 [LibraryException.details]
  fileWriteFailed,

  /// 书籍元数据写库失败，细节见 [LibraryException.details]
  saveFailed,

  /// 导入的兜底失败（未预期的其他异常），细节见 [LibraryException.details]
  importFailed,

  /// 备份声明的格式版本高于当前支持上限，需升级应用
  backupVersionTooNew,

  /// 备份 ZIP 未通过解压前校验（zip bomb / 路径越界）
  backupArchiveInvalid,

  /// 备份数据损坏或结构不一致（JSON 解析失败、书架与清单标识不符等），
  /// 细节见 [LibraryException.details]
  backupCorrupted,

  /// 恢复的兜底失败（未预期的其他异常），细节见 [LibraryException.details]
  restoreFailed,
}

/// 藏书模块领域异常。
///
/// [details] 为内部细节，仅用于日志，**不上屏**。
class LibraryException implements Exception {
  final LibraryErrorCode code;
  final Object? details;

  const LibraryException(this.code, [this.details]);

  @override
  String toString() => details == null
      ? 'LibraryException(${code.name})'
      : 'LibraryException(${code.name}: $details)';
}
