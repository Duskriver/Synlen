/// 备份 ZIP 解压前的静态校验：条目数、单条目与总解压量上限，以及路径安全。
///
/// 在写盘前对整个 ZIP 目录跑一次，挡住 zip bomb 与
/// zip-slip 两类恶意备份。纯函数，不触盘，便于单测。
library;

/// 备份 ZIP 单个条目的待校验信息（[size] 为解压后大小，单位字节）。
typedef BackupArchiveEntryInfo = ({String name, int size});

/// 解压上限：条目数。
const int maxBackupEntryCount = 10000;

/// 解压上限：单条目解压后大小（512 MiB）。
const int maxBackupEntryBytes = 512 * 1024 * 1024;

/// 解压上限：全部条目解压后总大小（4 GiB）。
const int maxBackupTotalBytes = 4 * 1024 * 1024 * 1024;

/// 校验不通过的违规类型。
enum BackupArchiveViolation {
  /// 条目数超过 [maxBackupEntryCount]。
  tooManyEntries,

  /// 单条目解压后大小超过 [maxBackupEntryBytes]。
  entryTooLarge,

  /// 总解压量超过 [maxBackupTotalBytes]。
  totalTooLarge,

  /// 条目路径越界：绝对路径或规范化后含 `..`。
  unsafePath,
}

/// [validateBackupArchiveEntries] 判定违规时抛出的异常。
class BackupArchiveViolationException implements Exception {
  const BackupArchiveViolationException(this.violation);

  final BackupArchiveViolation violation;

  @override
  String toString() => 'BackupArchiveViolationException: $violation';
}

/// 遍历备份 ZIP 条目做解压前校验；返回违规类型，全部通过时返回 null。
///
/// 先查路径与计数再累计大小，任一违规立即短路返回。
BackupArchiveViolation? validateBackupArchiveEntries(
  Iterable<BackupArchiveEntryInfo> entries,
) {
  var count = 0;
  var totalBytes = 0;
  for (final entry in entries) {
    if (!_isSafeEntryName(entry.name)) {
      return BackupArchiveViolation.unsafePath;
    }
    count++;
    if (count > maxBackupEntryCount) {
      return BackupArchiveViolation.tooManyEntries;
    }
    if (entry.size < 0 || entry.size > maxBackupEntryBytes) {
      return BackupArchiveViolation.entryTooLarge;
    }
    totalBytes += entry.size;
    if (totalBytes > maxBackupTotalBytes) {
      return BackupArchiveViolation.totalTooLarge;
    }
  }
  return null;
}

/// 条目名必须是以 `/` 分隔的相对路径，且规范化后不越出解压目录：
/// 拒绝空名、绝对路径（POSIX 与 Windows 盘符）、以及任何 `..` 段。
bool _isSafeEntryName(String name) {
  if (name.isEmpty) return false;
  // ZIP 规范用 / 分隔；防御性兼容 \ 分隔的条目。
  final normalized = name.replaceAll('\\', '/');
  if (normalized.startsWith('/')) return false;
  // Windows 盘符（如 C:/...）视同绝对路径。
  if (normalized.length >= 2 && normalized[1] == ':') return false;
  for (final segment in normalized.split('/')) {
    if (segment == '..') return false;
  }
  return true;
}
