import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart' as secure;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:synlen/main.dart' as app;
import 'package:synlen/src/core/database/app_database.dart';
import 'package:synlen/src/features/library/domain/book_format.dart';
import 'package:synlen/src/features/library/domain/book_manifest.dart';
import 'package:synlen/src/features/learning/presentation/widgets/sentence_analysis_dialog.dart';
import 'package:synlen/src/features/learning/presentation/widgets/word_definition_dialog.dart';
import 'package:synlen/src/features/reader/presentation/readium_viewport.dart';
import 'package:synlen/src/features/reader/presentation/reader_screen.dart'
    as reader;

/// 学习链路真机端到端验收：在模拟器上以真实 Readium 原生视口渲染
/// TXT 书籍，点击单词与长按句子走真实 DeepSeek 接口。
///
/// 运行方式（密钥经 --dart-define 传入，不入库）：
/// ```
/// flutter test integration_test/learning_e2e_test.dart -d <device> \
///   --dart-define=SYNLEN_DEEPSEEK_KEY=<key>
/// ```
const _deepSeekKey = String.fromEnvironment('SYNLEN_DEEPSEEK_KEY');

const _kDeepSeekStorageKey = 'api_key_deepseek';

/// 内容使用小词表重复句式：页面填满英文文本，保证中央点按落在已知单词上。
String get _bookContent => List.generate(
  24,
  (i) =>
      'The old keeper spoke about perseverance during every storm. '
      'She told the young sailors that patience and effort always matter. '
      'Chapter $i ends with a quiet morning near the harbor.',
).join('\n\n');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // 平台视图（WebView）的手势需要真实事件穿透。
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('点击单词出解释、长按句子出分析（真实 DeepSeek）', (tester) async {
    // 在种子阶段手动初始化存储路径（与 main() 一致），随后关闭连接交给应用。
    await _seed(tester);

    // main() 声明为 void，内部异步初始化由后续 pump 驱动。
    app.main();
    await _pumpFor(tester, const Duration(seconds: 6));

    // 书架出现种子书目。
    final bookTile = find.text('E2E 学习验收书');
    await _pumpUntil(tester, bookTile, timeout: const Duration(seconds: 20));
    await tester.tap(bookTile);

    // 点击书封进入的是详情页，需再点 Start Reading（中英文环境均兼容）。
    final startReading = find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          (widget.data == 'Start Reading' || widget.data == '开始阅读'),
    );
    await _pumpUntil(
      tester,
      startReading,
      timeout: const Duration(seconds: 15),
    );
    // 等详情页转场收敛，否则 tap 会命中路由下层的 Scaffold。
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
    await tester.tap(startReading);

    await _pumpUntil(
      tester,
      find.byType(reader.ReaderScreen),
      timeout: const Duration(seconds: 15),
    );
    final readyUntil = DateTime.now().add(const Duration(seconds: 40));
    while (DateTime.now().isBefore(readyUntil)) {
      await tester.pump(const Duration(milliseconds: 200));
      final views = find.byType(ReadiumViewport);
      if (views.evaluate().isNotEmpty &&
          tester.widget<ReadiumViewport>(views).session.ready) {
        break;
      }
    }
    final viewport = find.byType(ReadiumViewport);
    expect(tester.widget<ReadiumViewport>(viewport).session.ready, isTrue);
    final bounds = tester.getRect(viewport);
    final wordDialog = find.byType(WordDefinitionDialog);
    Offset? selectedPoint;
    // 行间空白不会产生点词事件；扫描相邻像素行，命中后停止，避免重复请求。
    for (final dy in [0.0, 5.0, -5.0, 10.0, -10.0, 15.0, -15.0]) {
      final point = Offset(
        bounds.center.dx,
        bounds.top + bounds.height * 0.4 + dy,
      );
      await tester.tapAt(point);
      if (await _waitFor(
        tester,
        wordDialog,
        timeout: const Duration(seconds: 3),
      )) {
        selectedPoint = point;
        break;
      }
    }
    expect(selectedPoint, isNotNull, reason: 'Readium 的真实点词未产生学习弹窗');
    final selected = tester.widget<WordDefinitionDialog>(wordDialog);
    expect(_bookContent, contains(selected.word));
    expect(_bookContent, contains(selected.context));
    // 单词弹窗流式渲染四节契约（真实网络，放宽等待）。
    final phoneticsHeading = find.text('音标');
    await _pumpUntil(
      tester,
      phoneticsHeading,
      timeout: const Duration(seconds: 120),
    );
    await _pumpUntil(
      tester,
      find.text('句中含义'),
      timeout: const Duration(seconds: 60),
    );
    await _pumpUntil(
      tester,
      find.text('常见用法'),
      timeout: const Duration(seconds: 30),
    );

    // 使用刚刚命中字形的位置长按，覆盖 550 ms 脚本阈值。
    await tester.tap(find.byIcon(Icons.close));
    await _pumpFor(tester, const Duration(seconds: 2));
    final gesture = await tester.startGesture(selectedPoint!);
    await tester.pump(const Duration(milliseconds: 900));
    await gesture.up();
    final sentenceDialog = find.byType(SentenceAnalysisDialog);
    await _pumpUntil(
      tester,
      sentenceDialog,
      timeout: const Duration(seconds: 15),
    );
    final analysis = tester.widget<SentenceAnalysisDialog>(sentenceDialog);
    expect(analysis.sentence, selected.context);
    await _pumpUntil(
      tester,
      find.text(analysis.sentence),
      timeout: const Duration(seconds: 10),
    );
    // 翻译小节由真实模型流式输出。
    await _pumpUntil(
      tester,
      find.text('翻译'),
      timeout: const Duration(seconds: 120),
    );
    await _pumpUntil(
      tester,
      find.text('语法分析'),
      timeout: const Duration(seconds: 60),
    );
  }, skip: _deepSeekKey.isEmpty);
}

Future<void> _seed(WidgetTester tester) async {
  if (_deepSeekKey.isEmpty) return;
  await secure.FlutterSecureStorage().write(
    key: _kDeepSeekStorageKey,
    value: _deepSeekKey,
  );

  final content = _bookContent;
  final hash = sha256.convert(utf8.encode(content)).toString();
  final docs = await getApplicationDocumentsDirectory();
  File('${docs.path}/books/$hash.txt')
    ..createSync(recursive: true)
    ..writeAsStringSync(content);

  final db = AppDatabase();
  await db
      .into(db.shelfBooks)
      .insert(
        ShelfBook(
          id: 0,
          fileHash: hash,
          filePath: 'books/$hash.txt',
          title: 'E2E 学习验收书',
          author: '验收',
          authors: const ['验收'],
          subjects: const [],
          description: '',
          totalChapters: 1,
          epubVersion: '',
          format: BookFormat.txt,
          importDate: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
          direction: 0,
          readingProgress: 0,
          lastOpenedDate: null,
          isFinished: false,
          isDeleted: false,
        ),
      );
  await db
      .into(db.bookManifests)
      .insert(
        BookManifest(
          id: 0,
          fileHash: hash,
          opfRootPath: '',
          spine: [
            SpineItem(
              index: 0,
              href: 'txt/chapter_0.xhtml',
              idref: '0',
              sourceRange: '0-${utf8.encode(content).length}',
            ),
          ],
          toc: const [],
          manifest: const [],
          epubVersion: '',
          format: BookFormat.txt,
          lastUpdated: DateTime.now(),
        ),
      );
  await db.close();
}

/// 循环 pump 直到 [finder] 命中；配合真实网络与 WebView 的异步时序。
Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  if (!await _waitFor(tester, finder, timeout: timeout)) {
    fail('等待超时：${finder.toString()}');
  }
}

/// 等待 [finder] 命中，超时返回 false 而不抛错（用于条件分支）。
Future<bool> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 400));
    if (finder.evaluate().isNotEmpty) return true;
  }
  return finder.evaluate().isNotEmpty;
}

/// 持续 pump 一段时间让渲染与网络请求落地。
Future<void> _pumpFor(WidgetTester tester, Duration duration) async {
  final end = DateTime.now().add(duration);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}
