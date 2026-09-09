import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:synlen/src/core/database/app_database.dart';
import 'package:synlen/src/core/services/app_logger.dart';
import 'package:synlen/src/core/storage/app_storage.dart';

import '../data/repositories/shelf_book_repository_provider.dart';
import '../data/services/storage_cleanup_service_provider.dart';
import '../domain/book_views.dart';
import 'book_view_mapper.dart';

part 'book_actions.g.dart';

/// 单本书详情页的读取用例：按 fileHash 取详情视图，不存在返回 null。
///
/// 注：手写 FutureProvider 而非 @riverpod codegen——详情页进入前网格会预取
/// 这个 provider，需要它在网格不再监听后仍保留结果，codegen 默认的
/// autoDispose 会在路由动画期间把预取结果丢掉。
final bookDetailProvider = FutureProvider.family<DetailBookView?, String>((
  ref,
  fileHash,
) async {
  final book = await ref
      .read(bookActionsProvider.notifier)
      .findByHash(fileHash);
  return book == null ? null : detailBookView(book);
});

/// 单本书的读取、元数据保存与文件分享用例。
///
/// 保存与分享都按 fileHash 现取整行：调用方只提供编辑后的字段，
/// 不持有 drift 行类型。
@riverpod
class BookActions extends _$BookActions {
  @override
  void build() {}

  Future<ShelfBook?> findByHash(String fileHash) =>
      ref.read(shelfBookRepositoryProvider).getBookByHash(fileHash);

  /// 保存书名 / 作者 / 简介；失败返回可展示的错误信息，成功返回 null。
  Future<String?> saveMetadataByHash({
    required String fileHash,
    required String title,
    required List<String> authors,
    required String? description,
  }) async {
    final repository = ref.read(shelfBookRepositoryProvider);
    final book = await repository.getBookByHash(fileHash);
    if (book == null) {
      appLogger.w('saveMetadata: book not found for hash $fileHash');
      return 'Save failed: book not found';
    }

    final updated = book.copyWith(
      title: title,
      authors: authors,
      author: authors.isNotEmpty ? authors.first : '',
      description: Value(description),
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    final result = await repository.saveBook(updated);
    return result.fold((error) => error, (_) => null);
  }

  /// 把书籍文件拷到可分享的临时路径并调起系统分享面板，结束后删除临时文件。
  ///
  /// MIME 由 `BookFormat.mimeType` 决定：TXT 不能再被标成 EPUB。
  Future<void> shareBookByHash(String fileHash) async {
    final book = await ref
        .read(shelfBookRepositoryProvider)
        .getBookByHash(fileHash);
    final relativePath = book?.filePath;
    if (book == null || relativePath == null) {
      throw StateError('shareBook: book or file path missing: $fileHash');
    }

    final service = ref.read(storageCleanupServiceProvider);
    final sourcePath = '${AppStorage.documentsPath}$relativePath';
    final tempFile = await service.saveTempFileForSharing(
      File(sourcePath),
      book.title,
    );
    try {
      await SharePlus.instance.share(
        ShareParams(
          subject: book.title,
          files: [XFile(tempFile.path, mimeType: book.format.mimeType)],
        ),
      );
    } finally {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }
}
