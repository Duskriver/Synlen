import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:synlen/src/core/database/app_database.dart';
import 'package:synlen/src/core/storage/app_storage.dart';

import '../data/repositories/shelf_book_repository_provider.dart';
import '../data/services/storage_cleanup_service_provider.dart';

part 'book_actions.g.dart';

/// 单本书详情页的读取用例：按 fileHash 取书，不存在返回 null。
///
/// 注：手写 FutureProvider（而非 @riverpod codegen）——riverpod_generator
/// 4.0.4 无法把 drift DataClass 作为 provider 返回类型生成代码
/// （InvalidTypeException），待生成器 / Flutter SDK 升级后可视情况改回。
final bookDetailProvider = FutureProvider.family<ShelfBook?, String>((
  ref,
  fileHash,
) async {
  return ref.read(bookActionsProvider.notifier).findByHash(fileHash);
});

/// 单本书的读取、元数据保存与文件分享用例。
@riverpod
class BookActions extends _$BookActions {
  @override
  void build() {}

  Future<ShelfBook?> findByHash(String fileHash) =>
      ref.read(shelfBookRepositoryProvider).getBookByHash(fileHash);

  /// 保存书名 / 作者 / 简介；失败返回可展示的错误信息，成功返回 null。
  Future<String?> saveMetadata(ShelfBook book) async {
    final result = await ref.read(shelfBookRepositoryProvider).saveBook(book);
    return result.fold((error) => error, (_) => null);
  }

  /// 把书籍文件拷到可分享的临时路径并调起系统分享面板，结束后删除临时文件。
  Future<void> shareBookFile(ShelfBook book) async {
    final service = ref.read(storageCleanupServiceProvider);
    final sourcePath = '${AppStorage.documentsPath}${book.filePath}';
    final tempFile = await service.saveTempFileForSharing(
      File(sourcePath),
      book.title,
    );
    try {
      await SharePlus.instance.share(
        ShareParams(
          subject: book.title,
          files: [XFile(tempFile.path, mimeType: 'application/epub+zip')],
        ),
      );
    } finally {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }
}
