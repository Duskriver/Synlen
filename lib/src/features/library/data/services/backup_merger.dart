import 'package:drift/drift.dart' show Value;
import '../../../../core/database/app_database.dart';

/// 元数据与进度分别按时间戳取较新值；显式恢复可撤销本机软删除。
ShelfBook mergeRestoredBook(ShelfBook backup, ShelfBook? existing) {
  if (existing == null) return backup.copyWith(id: 0);
  final metadata = backup.updatedAt > existing.updatedAt ? backup : existing;
  final backupReadAt = backup.lastOpenedDate;
  final localReadAt = existing.lastOpenedDate;
  final progress =
      backupReadAt != null &&
          (localReadAt == null || backupReadAt > localReadAt)
      ? backup
      : existing;
  return metadata.copyWith(
    id: existing.id,
    filePath: Value(backup.filePath),
    coverPath: Value(metadata.coverPath ?? existing.coverPath),
    currentChapterIndex: progress.currentChapterIndex,
    readingProgress: progress.readingProgress,
    chapterScrollPosition: Value(progress.chapterScrollPosition),
    isFinished: progress.isFinished,
    lastOpenedDate: Value(progress.lastOpenedDate),
    isDeleted: backup.isDeleted && metadata.isDeleted,
  );
}

/// Drift 时间戳按秒存储，同秒内保留本机清单。
BookManifest mergeRestoredManifest(
  BookManifest backup,
  BookManifest? existing,
) {
  if (existing != null &&
      backup.lastUpdated.millisecondsSinceEpoch ~/ 1000 <=
          existing.lastUpdated.millisecondsSinceEpoch ~/ 1000) {
    return existing;
  }
  return backup.copyWith(id: existing?.id ?? 0);
}
