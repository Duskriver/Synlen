import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synlen/src/core/file_handling/platform_path.dart';
import 'package:synlen/src/core/file_handling/unified_import_service.dart';
import 'package:synlen/src/core/providers/shared_preferences_provider.dart';
import 'package:synlen/src/core/providers/unified_import_service_provider.dart';
import 'package:synlen/src/core/storage/app_storage.dart';
import 'package:synlen/src/features/settings/application/font_manager_notifier.dart';

/// 字体导入管道的手写 fake：只覆写被 [FontManagerNotifier] 消费的入口，
/// 不触发任何平台通道。
class _FakeUnifiedImportService extends UnifiedImportService {
  _FakeUnifiedImportService({
    this.pickedPaths = const [],
    Map<String, File>? cacheFiles,
    this.displayNames = const {},
    this.failFor = const {},
  }) : _cacheFiles = cacheFiles ?? {};

  final List<PlatformPath> pickedPaths;
  final Map<String, File> _cacheFiles;
  final Set<String> failFor;
  final Map<String, String> displayNames;

  final List<File> cleaned = [];
  int processCount = 0;
  int releaseCount = 0;

  @override
  Future<List<PlatformPath>> pickFontFiles() async => pickedPaths;

  @override
  Future<String> resolveFileName(PlatformPath path) async =>
      displayNames[path.name] ?? path.name;

  @override
  Future<File> processFontFile(PlatformPath path) async {
    processCount++;
    if (failFor.contains(path.name)) {
      throw const FileSystemException('fake cache failure');
    }
    return _cacheFiles[path.name]!;
  }

  @override
  Future<void> cleanCache(File cacheFile) async => cleaned.add(cacheFile);

  @override
  Future<void> releaseIosAccess() async => releaseCount++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late Directory documentsDir;
  late Directory cacheDir;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('synlen_font_manager_test_');
    documentsDir = Directory('${root.path}/documents')..createSync();
    cacheDir = Directory('${root.path}/cache')..createSync();
    AppStorage.initForTesting(
      documentsPath: documentsDir.path,
      tempPath: cacheDir.path,
    );
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<ProviderContainer> buildContainer(
    _FakeUnifiedImportService service, [
    Map<String, Object> initial = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(initial);
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        unifiedImportServiceProvider.overrideWithValue(service),
      ],
    );
    // 保持订阅，避免 autoDispose 在 read 之后回收 provider。
    container.listen(fontManagerProvider, (_, _) {});
    return container;
  }

  Future<File> writeCacheFile(String fileName) async {
    final file = File('${cacheDir.path}/$fileName');
    await file.writeAsBytes([1, 2, 3]);
    return file;
  }

  test('选择器取消时直接返回空列表，不触碰状态与原生资源', () async {
    final service = _FakeUnifiedImportService();
    final container = await buildContainer(service);
    addTearDown(container.dispose);

    final imported = await container
        .read(fontManagerProvider.notifier)
        .importFonts();

    expect(imported, isEmpty);
    expect(container.read(fontManagerProvider), isEmpty);
    expect(service.processCount, 0);
    expect(service.releaseCount, 0);
  });

  test('成功导入多个字体：复制落盘、更新状态并持久化', () async {
    final serif = await writeCacheFile('serif.ttf');
    final mono = await writeCacheFile('mono.otf');
    final service = _FakeUnifiedImportService(
      pickedPaths: [
        IOSFilePath('/src/serif.ttf'),
        IOSFilePath('/src/mono.otf'),
      ],
      cacheFiles: {'serif.ttf': serif, 'mono.otf': mono},
    );
    final container = await buildContainer(service);
    addTearDown(container.dispose);

    final imported = await container
        .read(fontManagerProvider.notifier)
        .importFonts();

    expect(imported.map((f) => f.fileName), ['serif.ttf', 'mono.otf']);
    expect(container.read(fontManagerProvider).map((f) => f.fileName), [
      'serif.ttf',
      'mono.otf',
    ]);
    expect(await File('${documentsDir.path}/fonts/serif.ttf').readAsBytes(), [
      1,
      2,
      3,
    ]);
    expect(await File('${documentsDir.path}/fonts/mono.otf').exists(), isTrue);
    expect(service.cleaned, [serif, mono]);
    expect(service.releaseCount, 1);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('imported_fonts'), isNotNull);
  });

  test('重复文件名不重复入状态，但仍计入返回值', () async {
    final existing = await writeCacheFile('serif.ttf');
    final service = _FakeUnifiedImportService(
      pickedPaths: [
        IOSFilePath('/src/serif.ttf'),
        IOSFilePath('/src/serif.ttf'),
      ],
      cacheFiles: {'serif.ttf': existing},
    );
    final container = await buildContainer(service, {
      'imported_fonts': '["serif.ttf"]',
    });
    addTearDown(container.dispose);

    final imported = await container
        .read(fontManagerProvider.notifier)
        .importFonts();

    expect(imported.map((f) => f.fileName), ['serif.ttf', 'serif.ttf']);
    expect(container.read(fontManagerProvider).map((f) => f.fileName), [
      'serif.ttf',
    ]);
  });

  for (final displayName in [
    '阅读字体.ttf',
    '../阅读字体.ttf',
    r'C:\folder\阅读字体.ttf',
  ]) {
    test('数字 SAF ID 使用清理后的显示名：$displayName', () async {
      final cache = await writeCacheFile('cache.ttf');
      const path = AndroidUriPath(
        'content://com.android.providers.downloads.documents/document/1000000018',
      );
      final service = _FakeUnifiedImportService(
        pickedPaths: [path],
        cacheFiles: {path.name: cache},
        displayNames: {path.name: displayName},
      );
      final container = await buildContainer(service);
      addTearDown(container.dispose);
      final imported = await container
          .read(fontManagerProvider.notifier)
          .importFonts();
      expect(imported.single.fileName, '阅读字体.ttf');
      expect(imported.single.displayName, '阅读字体');
      expect(await File('${documentsDir.path}/fonts/阅读字体.ttf').readAsBytes(), [
        1,
        2,
        3,
      ]);
      expect(
        File('${documentsDir.path}/fonts/1000000018').existsSync(),
        isFalse,
      );
      expect(service.cleaned, [cache]);
      expect(service.releaseCount, 1);
      expect(
        (await SharedPreferences.getInstance()).getString('imported_fonts'),
        '["阅读字体.ttf"]',
      );
    });
  }

  test('显示名中的控制字符和平台保留字符被替换，后缀保留', () async {
    final cache = await writeCacheFile('cache.otf');
    const path = AndroidUriPath('content://fonts/document/123');
    final service = _FakeUnifiedImportService(
      pickedPaths: [path],
      cacheFiles: {path.name: cache},
      displayNames: {path.name: 'bad:\u0000name?.otf'},
    );
    final container = await buildContainer(service);
    addTearDown(container.dispose);
    final imported = await container
        .read(fontManagerProvider.notifier)
        .importFonts();
    expect(imported.single.fileName, 'bad__name_.otf');
    expect(
      File('${documentsDir.path}/fonts/bad__name_.otf').existsSync(),
      isTrue,
    );
    expect(service.cleaned, [cache]);
    expect(service.releaseCount, 1);
  });

  test('无法落盘的名称跳过当前字体，并释放原生访问', () async {
    const path = AndroidUriPath('content://fonts/document/123');
    final service = _FakeUnifiedImportService(
      pickedPaths: [path],
      displayNames: {path.name: '..'},
    );
    final container = await buildContainer(service);
    addTearDown(container.dispose);
    expect(
      await container.read(fontManagerProvider.notifier).importFonts(),
      isEmpty,
    );
    expect(container.read(fontManagerProvider), isEmpty);
    expect(service.processCount, 0);
    expect(service.releaseCount, 1);
  });

  test('建立字体目录失败时仍释放已选文件的原生访问', () async {
    await File('${documentsDir.path}/fonts').writeAsString('目录被文件占用');
    final service = _FakeUnifiedImportService(
      pickedPaths: [const IOSFilePath('/source/font.ttf')],
    );
    final container = await buildContainer(service);
    addTearDown(container.dispose);
    await expectLater(
      container.read(fontManagerProvider.notifier).importFonts(),
      throwsA(isA<FileSystemException>()),
    );
    expect(service.processCount, 0);
    expect(service.releaseCount, 1);
  });

  test('单个字体处理失败时继续后续条目，并始终清理缓存与释放原生资源', () async {
    final good = await writeCacheFile('good.ttf');
    final service = _FakeUnifiedImportService(
      pickedPaths: [
        IOSFilePath('/src/broken.ttf'),
        IOSFilePath('/src/good.ttf'),
      ],
      cacheFiles: {'good.ttf': good},
      failFor: {'broken.ttf'},
    );
    final container = await buildContainer(service);
    addTearDown(container.dispose);

    final imported = await container
        .read(fontManagerProvider.notifier)
        .importFonts();

    expect(imported.map((f) => f.fileName), ['good.ttf']);
    expect(container.read(fontManagerProvider).map((f) => f.fileName), [
      'good.ttf',
    ]);
    // 失败条目没有缓存文件可清理，成功条目清理一次
    expect(service.cleaned, [good]);
    expect(service.releaseCount, 1);
  });

  test('deleteFont 删除文件、移出状态并持久化', () async {
    final service = _FakeUnifiedImportService();
    final container = await buildContainer(service, {
      'imported_fonts': '["serif.ttf","mono.otf"]',
    });
    addTearDown(container.dispose);

    final fontsDir = Directory('${documentsDir.path}/fonts')..createSync();
    final target = File('${fontsDir.path}/serif.ttf');
    await target.writeAsBytes([1, 2, 3]);

    final notifier = container.read(fontManagerProvider.notifier);
    await notifier.deleteFont(container.read(fontManagerProvider).first);

    expect(await target.exists(), isFalse);
    expect(container.read(fontManagerProvider).map((f) => f.fileName), [
      'mono.otf',
    ]);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('imported_fonts'), '["mono.otf"]');
  });
}
