import 'package:drift/drift.dart' show Value;
import 'package:fpdart/fpdart.dart';

import 'package:synlen/src/core/database/app_database.dart';
import '../book_manifest_repository.dart';
import '../shelf_book_repository.dart';

/// 把备份数据合并进本机库。
///
/// 元数据与阅读位置分别按各自的时间戳取较新的一方：备份更新则覆盖元数据，
/// 本机读过更晚则保留本机进度；同秒内按秒精度比较，避免 drift 截断误判。
class BackupMerger {
  final ShelfBookRepository _shelfBookRepository;
  final BookManifestRepository _bookManifestRepository;

  BackupMerger({
    required ShelfBookRepository shelfBookRepository,
    required BookManifestRepository bookManifestRepository,
  }) : _shelfBookRepository = shelfBookRepository,
       _bookManifestRepository = bookManifestRepository;

  Future<void> mergeGroups(List<ShelfGroup> backupGroups) async {
    for (final backupGroup in backupGroups) {
      final existingGroup = await _shelfBookRepository.getGroupByName(
        backupGroup.name,
      );

      if (existingGroup == null) {
        final id = _requireSaved(
          await _shelfBookRepository.createGroup(name: backupGroup.name),
        );
        await _shelfBookRepository.saveGroup(backupGroup.copyWith(id: id));
      } else {
        if (backupGroup.updatedAt > existingGroup.updatedAt) {
          await _shelfBookRepository.saveGroup(
            backupGroup.copyWith(id: existingGroup.id),
          );
        }
      }
    }
  }

  T _requireSaved<T>(Either<String, T> result) =>
      result.fold((error) => throw StateError(error), (value) => value);

  /// Drift 的 dateTime 列按秒存储；毫秒差会被截断，必须按同一精度比较，
  /// 否则同秒内的旧备份会被误判为较新。
  bool _isManifestNewer(DateTime backup, DateTime existing) =>
      backup.millisecondsSinceEpoch ~/ 1000 >
      existing.millisecondsSinceEpoch ~/ 1000;

  Future<void> mergeManifest(BookManifest backupManifest) async {
    final existing = await _bookManifestRepository.getManifestByHash(
      backupManifest.fileHash,
    );
    if (existing != null &&
        !_isManifestNewer(backupManifest.lastUpdated, existing.lastUpdated)) {
      return;
    }
    _requireSaved(
      await _bookManifestRepository.saveManifest(
        backupManifest.copyWith(id: existing?.id ?? 0),
      ),
    );
  }

  Future<void> mergeBook(ShelfBook backupBook) async {
    final existing = await _shelfBookRepository.getBookByHash(
      backupBook.fileHash,
    );
    if (existing == null) {
      _requireSaved(await _shelfBookRepository.saveBook(backupBook));
      return;
    }

    // 元数据与阅读位置分别按各自时间选择；相同或都未知时保留本机值。
    final metadata = backupBook.updatedAt > existing.updatedAt
        ? backupBook
        : existing;
    final backupReadAt = backupBook.lastOpenedDate;
    final localReadAt = existing.lastOpenedDate;
    final progress =
        backupReadAt != null &&
            (localReadAt == null || backupReadAt > localReadAt)
        ? backupBook
        : existing;
    final merged = metadata.copyWith(
      id: existing.id,
      filePath: Value(backupBook.filePath),
      coverPath: Value(metadata.coverPath ?? existing.coverPath),
      currentChapterIndex: progress.currentChapterIndex,
      readingProgress: progress.readingProgress,
      chapterScrollPosition: Value(progress.chapterScrollPosition),
      isFinished: progress.isFinished,
      lastOpenedDate: Value(progress.lastOpenedDate),
      // 显式恢复包含此书的备份时撤销本机软删除，同时保留选定的较新数据。
      isDeleted: backupBook.isDeleted && metadata.isDeleted,
    );
    _requireSaved(await _shelfBookRepository.saveBook(merged));
  }
}
