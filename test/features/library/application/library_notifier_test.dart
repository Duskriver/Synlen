import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synlen/src/core/database/app_database.dart';
import 'package:synlen/src/core/file_handling/file_handling.dart';
import 'package:synlen/src/features/library/application/library_notifier.dart';
import 'package:synlen/src/features/library/data/services/epub_import_service.dart';
import 'package:synlen/src/features/library/data/services/epub_import_service_provider.dart';
import 'package:synlen/src/core/providers/unified_import_service_provider.dart';
import 'package:synlen/src/features/library/domain/book_format.dart';

import 'library_notifier_test.mocks.dart';

/// 回归测试：导入管道在「调用方只 read 不监听、UI 对话框稍后才订阅流」
/// 的场景下不能因 provider 被 autoDispose 而中断。
///
/// 真实故障路径（Android SAF 选文件后）：
/// `_importPaths` 通过 `ref.read(libraryProvider.notifier)` 拿到 notifier 并
/// 创建 async* 流（方法体此时不执行）；进度对话框在下一帧 initState 才监听，
/// 期间 autoDispose 调度器销毁了无监听者的 libraryProvider，流开始执行时
/// 方法体内的 `ref.read` 抛出 "Cannot use the Ref ... after it has been
/// disposed"，导入一本书也没写入却以流错误告终。
@GenerateMocks([UnifiedImportService, EpubImportService])
void main() {
  late MockUnifiedImportService unifiedImportService;
  late MockEpubImportService epubImportService;
  late ProviderContainer container;

  ShelfBook buildBook() {
    return ShelfBook(
      id: 1,
      fileHash: 'hash-1',
      title: '测试书',
      author: '作者',
      authors: const ['作者'],
      subjects: const [],
      totalChapters: 1,
      epubVersion: '',
      format: BookFormat.txt,
      importDate: 0,
      direction: 0,
      currentChapterIndex: 0,
      readingProgress: 0,
      isFinished: false,
      isDeleted: false,
      updatedAt: 0,
    );
  }

  setUp(() {
    unifiedImportService = MockUnifiedImportService();
    epubImportService = MockEpubImportService();

    // mockito 无法为 fpdart 的 Either 自动造 dummy，需显式提供
    provideDummy<Either<String, ShelfBook>>(right(buildBook()));

    when(unifiedImportService.processEpub(any)).thenAnswer(
      (_) async => ImportableEpub(
        cacheFile: File('/tmp/fake.txt'),
        hash: 'hash-1',
        originalName: 'fake.txt',
      ),
    );
    when(unifiedImportService.cleanCache(any)).thenAnswer((_) async {});
    when(
      epubImportService.importBook(
        any,
        precomputedHash: anyNamed('precomputedHash'),
        originalFileName: anyNamed('originalFileName'),
        moveSourceFile: anyNamed('moveSourceFile'),
      ),
    ).thenAnswer((_) async => right(buildBook()));

    container = ProviderContainer(
      overrides: [
        unifiedImportServiceProvider.overrideWithValue(unifiedImportService),
        epubImportServiceProvider.overrideWithValue(epubImportService),
      ],
    );
    addTearDown(container.dispose);
  });

  test('read 创建流之后、订阅之前的空窗期内 provider 不被销毁，导入照常完成', () async {
    // 只 read 不监听，与 _importPaths 的用法一致
    final stream = container
        .read(libraryProvider.notifier)
        .importPipelineStream([PlatformPath.fromString('/tmp/fake.txt')]);

    // 模拟对话框下一帧才订阅：给 autoDispose 调度器留出销毁窗口
    await Future<void>.delayed(const Duration(milliseconds: 100));

    // 修复前：流开始执行时 ref 已销毁，抛出异常并以流错误结束
    final events = await stream.toList();

    final progress = events.whereType<ImportProgress>().toList();
    expect(progress, hasLength(2));
    expect(progress.first.status, ImportStatus.processing);
    expect(progress.last.status, ImportStatus.success);
    verify(unifiedImportService.processEpub(any)).called(1);
    verify(
      epubImportService.importBook(
        any,
        precomputedHash: anyNamed('precomputedHash'),
        originalFileName: anyNamed('originalFileName'),
        moveSourceFile: anyNamed('moveSourceFile'),
      ),
    ).called(1);
  });

  test('空路径列表立即结束，不触碰任何服务', () async {
    final events = await container
        .read(libraryProvider.notifier)
        .importPipelineStream(const [])
        .toList();

    expect(events.whereType<ImportProgress>(), isEmpty);
    verifyNever(unifiedImportService.processEpub(any));
    verifyNever(
      epubImportService.importBook(
        any,
        precomputedHash: anyNamed('precomputedHash'),
        originalFileName: anyNamed('originalFileName'),
        moveSourceFile: anyNamed('moveSourceFile'),
      ),
    );
  });
}
