import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:synlen/src/core/database/app_database.dart';

import '../data/book_manifest_repository.dart';
import '../data/repositories/book_manifest_repository_provider.dart';
import '../data/repositories/shelf_book_repository_provider.dart';
import '../data/shelf_book_repository.dart';

part 'book_queries.g.dart';

/// 书目读取与进度写入的用例接口：供本模块之外（reader 宿主）的 application 依赖。
///
/// 生产实现 [RepositoryBookQueries] 走仓库；测试可用 fake —— 两种实现，故不是假 seam。
abstract interface class BookQueries {
  /// 按文件哈希取书；不存在返回 null。
  Future<ShelfBook?> findBook(String fileHash);

  /// 按文件哈希取阅读清单；不存在返回 null。
  Future<BookManifest?> findManifest(String fileHash);

  /// 写入阅读进度；书籍已不存在或写入失败时抛 [StateError]。
  Future<void> saveProgress({
    required int bookId,
    required int chapterIndex,
    required double progress,
    required double? scrollPosition,
  });
}

/// 通过仓库读取书目与写入进度的默认实现。
class RepositoryBookQueries implements BookQueries {
  const RepositoryBookQueries({
    required ShelfBookRepository shelfBookRepository,
    required BookManifestRepository manifestRepository,
  }) : _shelfBookRepository = shelfBookRepository,
       _manifestRepository = manifestRepository;

  final ShelfBookRepository _shelfBookRepository;
  final BookManifestRepository _manifestRepository;

  @override
  Future<ShelfBook?> findBook(String fileHash) =>
      _shelfBookRepository.getBookByHash(fileHash);

  @override
  Future<BookManifest?> findManifest(String fileHash) =>
      _manifestRepository.getManifestByHash(fileHash);

  @override
  Future<void> saveProgress({
    required int bookId,
    required int chapterIndex,
    required double progress,
    required double? scrollPosition,
  }) async {
    final result = await _shelfBookRepository.updateProgress(
      bookId: bookId,
      currentChapterIndex: chapterIndex,
      progress: progress,
      scrollPosition: scrollPosition,
    );
    result.fold((error) => throw StateError(error), (updated) {
      if (!updated) throw StateError('保存进度时书籍已不存在');
    });
  }
}

/// 供 reader 等宿主读取书目与提交进度的入口。
@riverpod
BookQueries bookQueries(Ref ref) => RepositoryBookQueries(
  shelfBookRepository: ref.watch(shelfBookRepositoryProvider),
  manifestRepository: ref.watch(bookManifestRepositoryProvider),
);
