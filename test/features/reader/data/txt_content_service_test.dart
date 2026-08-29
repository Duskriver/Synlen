import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:synlen/src/core/database/app_database.dart';
import 'package:synlen/src/features/library/data/book_manifest_repository.dart';
import 'package:synlen/src/features/library/data/parsers/txt_book_parser.dart';
import 'package:synlen/src/features/library/domain/book_format.dart';
import 'package:synlen/src/features/library/domain/book_manifest.dart';
import 'package:synlen/src/features/reader/data/services/txt_content_service.dart';

import 'txt_content_service_test.mocks.dart';

@GenerateMocks([BookManifestRepository])
void main() {
  late MockBookManifestRepository manifestRepo;
  late TxtContentService service;

  const fileHash = 'txt-hash-1';
  const bookText = '本书简介\n介绍文字\n第一章 开始\n第一章内容 <>&\n第二章 继续\n第二章内容';

  late Directory tempDir;
  late File txtFile;
  late List<SpineItem> spine;

  BookManifest buildManifest({List<SpineItem>? spineOverride}) {
    return BookManifest(
      id: 1,
      fileHash: fileHash,
      opfRootPath: '',
      spine: spineOverride ?? spine,
      toc: const [],
      manifest: const [],
      epubVersion: '',
      format: BookFormat.txt,
      lastUpdated: DateTime(2026, 1, 1),
    );
  }

  setUp(() async {
    manifestRepo = MockBookManifestRepository();
    service = TxtContentService(manifestRepo: manifestRepo);

    // 用解析器产出归一化字节与 spine，落到临时文件模拟已导入的 TXT 书籍
    final parsed = const TxtBookParser()
        .parseFromText(bookText, fileName: '测试书.txt')
        .getOrElse((l) => throw StateError('unexpected left: $l'));
    spine = parsed.spine;

    tempDir = await Directory.systemTemp.createTemp('synlen_txt_content_test_');
    txtFile = File('${tempDir.path}/$fileHash.txt');
    await txtFile.writeAsBytes(parsed.normalizedUtf8, flush: true);
  });

  tearDown(() async {
    service.dispose();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('TxtContentService.buildChapterHtml', () {
    test('首行为标题行时渲染 <h2>，其余非空行渲染 <p>', () {
      final html = TxtContentService.buildChapterHtml('第一章 开始\n正文一行\n\n再来一行');

      expect(html, contains('<h2>第一章 开始</h2>'));
      expect(html, contains('<p>正文一行</p>'));
      expect(html, contains('<p>再来一行</p>'));
      // 空行折叠，不产生空段落
      expect(html, isNot(contains('<p></p>')));
    });

    test('首行不是标题时全部渲染为 <p>', () {
      final html = TxtContentService.buildChapterHtml('只是普通文字\n第二行');

      expect(html, isNot(contains('<h2>')));
      expect(html, contains('<p>只是普通文字</p>'));
    });

    test('HTML 特殊字符转义', () {
      final html = TxtContentService.buildChapterHtml('1 < 2 & 3 > 2');

      expect(html, contains('1 &lt; 2 &amp; 3 &gt; 2'));
      expect(html, isNot(contains('< 2')));
    });

    test('输出包含带 XHTML 命名空间的骨架与生成器标记', () {
      final html = TxtContentService.buildChapterHtml('内容');

      // xmlns 必须存在：章节按 application/xhtml+xml 解析时，
      // 无命名空间的元素不具备 HTML 语义（阅读器注入样式会失败）
      expect(
        html,
        startsWith(
          '<!DOCTYPE html><html xmlns="http://www.w3.org/1999/xhtml">',
        ),
      );
      expect(html, contains('<meta charset="utf-8" />'));
      expect(html, contains('<meta name="generator" content="synlen" />'));
      expect(html, endsWith('</body></html>'));
    });
  });

  group('TxtContentService.readChapter', () {
    test('按字节范围读取章节并包装为 XHTML', () async {
      when(
        manifestRepo.getManifestByHash(fileHash),
      ).thenAnswer((_) async => buildManifest());

      final result = await service.readChapter(
        txtAbsolutePath: txtFile.path,
        fileHash: fileHash,
        relativePath: 'txt/chapter_1.xhtml',
      );

      expect(result.isRight(), isTrue);
      final (bytes, mimeType) = result.getOrElse((l) => throw StateError(l));
      expect(mimeType, 'application/xhtml+xml');

      final html = utf8.decode(bytes);
      expect(html, contains('<h2>第一章 开始</h2>'));
      expect(html, contains('第一章内容 &lt;&gt;&amp;'));
      expect(html, isNot(contains('第二章')));
    });

    test('引导块章节（无标题行）也可读取', () async {
      when(
        manifestRepo.getManifestByHash(fileHash),
      ).thenAnswer((_) async => buildManifest());

      final result = await service.readChapter(
        txtAbsolutePath: txtFile.path,
        fileHash: fileHash,
        relativePath: 'txt/chapter_0.xhtml',
      );

      expect(result.isRight(), isTrue);
      final (bytes, _) = result.getOrElse((l) => throw StateError(l));
      final html = utf8.decode(bytes);
      expect(html, contains('本书简介'));
      expect(html, isNot(contains('第一章')));
    });

    test('spine 缓存：多次读取只查一次库', () async {
      when(
        manifestRepo.getManifestByHash(fileHash),
      ).thenAnswer((_) async => buildManifest());

      await service.readChapter(
        txtAbsolutePath: txtFile.path,
        fileHash: fileHash,
        relativePath: 'txt/chapter_1.xhtml',
      );
      await service.readChapter(
        txtAbsolutePath: txtFile.path,
        fileHash: fileHash,
        relativePath: 'txt/chapter_2.xhtml',
      );

      verify(manifestRepo.getManifestByHash(fileHash)).called(1);
    });

    test('非法章节路径返回 left', () async {
      final result = await service.readChapter(
        txtAbsolutePath: txtFile.path,
        fileHash: fileHash,
        relativePath: 'OEBPS/ch1.xhtml',
      );

      expect(result.isLeft(), isTrue);
      verifyNever(manifestRepo.getManifestByHash(any));
    });

    test('章节索引越界返回 left', () async {
      when(
        manifestRepo.getManifestByHash(fileHash),
      ).thenAnswer((_) async => buildManifest());

      final result = await service.readChapter(
        txtAbsolutePath: txtFile.path,
        fileHash: fileHash,
        relativePath: 'txt/chapter_99.xhtml',
      );

      expect(result.isLeft(), isTrue);
    });

    test('manifest 不存在返回 left', () async {
      when(
        manifestRepo.getManifestByHash(fileHash),
      ).thenAnswer((_) async => null);

      final result = await service.readChapter(
        txtAbsolutePath: txtFile.path,
        fileHash: fileHash,
        relativePath: 'txt/chapter_0.xhtml',
      );

      expect(result.isLeft(), isTrue);
    });

    test('spine 缺少字节范围返回 left', () async {
      final noRangeSpine = [
        SpineItem(
          index: 0,
          href: 'txt/chapter_0.xhtml',
          idref: 'txt-chapter-0',
        ),
      ];
      when(
        manifestRepo.getManifestByHash(fileHash),
      ).thenAnswer((_) async => buildManifest(spineOverride: noRangeSpine));

      final result = await service.readChapter(
        txtAbsolutePath: txtFile.path,
        fileHash: fileHash,
        relativePath: 'txt/chapter_0.xhtml',
      );

      expect(result.isLeft(), isTrue);
    });

    test('TXT 文件缺失返回 left', () async {
      when(
        manifestRepo.getManifestByHash(fileHash),
      ).thenAnswer((_) async => buildManifest());

      final result = await service.readChapter(
        txtAbsolutePath: '${tempDir.path}/not_exist.txt',
        fileHash: fileHash,
        relativePath: 'txt/chapter_0.xhtml',
      );

      expect(result.isLeft(), isTrue);
    });
  });
}
