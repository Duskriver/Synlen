import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_readium/reader_platform_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    debugDefaultTargetPlatformOverride = null;
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test('$platform 创建在途时关闭必须等待创建和所属原生视口拆除', () async {
      debugDefaultTargetPlatformOverride = platform;
      final creation = Completer<dynamic>();
      final nativeDetach = Completer<void>();
      final steps = <String>[];
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (call) async {
        if (call.method == 'create') {
          steps.add('create');
          return creation.future;
        }
        if (call.method == 'dispose') steps.add('platformDispose');
        return null;
      });
      final lifecycle = ReaderPlatformViewLifecycle(
        viewType: 'test/reader',
        creationParams: const {},
        onAllocated: (_) => steps.add('allocated'),
        beforeDispose: () async {
          steps.add('nativeDetach');
          await nativeDetach.future;
        },
      );
      final opening = lifecycle.create(platform, const Size(300, 500));
      await Future<void>.delayed(Duration.zero);
      var disposed = false;
      final closing = lifecycle.dispose().then((_) => disposed = true);
      expect(steps, ['allocated', 'create']);
      expect(disposed, isFalse);
      creation.complete(platform == TargetPlatform.android ? 1 : null);
      await opening;
      await Future<void>.delayed(Duration.zero);
      expect(steps, ['allocated', 'create', 'nativeDetach']);
      expect(disposed, isFalse);
      nativeDetach.complete();
      await closing;
      expect(steps, ['allocated', 'create', 'nativeDetach', 'platformDispose']);
      expect(disposed, isTrue);
      await lifecycle.dispose();
      expect(steps.where((step) => step == 'platformDispose'), hasLength(1));
    });

    test('$platform 创建失败仍清理通道与部分平台资源', () async {
      debugDefaultTargetPlatformOverride = platform;
      final steps = <String>[];
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (call) async {
        if (call.method == 'create') throw PlatformException(code: 'create_failed');
        if (call.method == 'dispose') {
          steps.add('platformDispose');
          if (platform == TargetPlatform.iOS) throw PlatformException(code: 'unknown_view');
        }
        return null;
      });
      final lifecycle = ReaderPlatformViewLifecycle(
        viewType: 'test/reader',
        creationParams: const {},
        onAllocated: (_) => steps.add('allocated'),
        beforeDispose: () async => steps.add('nativeDetach'),
      );
      await expectLater(
        lifecycle.create(platform, const Size(300, 500)),
        throwsA(isA<PlatformException>()),
      );
      await lifecycle.dispose();
      expect(steps, ['allocated', 'nativeDetach', 'platformDispose']);
    });

    for (final failReader in [true, false]) {
      test('$platform 单次关闭会内部重试瞬时${failReader ? '阅读通道' : '平台'}拆除失败', () async {
        debugDefaultTargetPlatformOverride = platform;
        var readerAttempts = 0;
        var platformAttempts = 0;
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, (call) async {
          if (call.method == 'create') return platform == TargetPlatform.android ? 1 : null;
          if (call.method == 'dispose') {
            platformAttempts++;
            if (!failReader && platformAttempts == 1) throw PlatformException(code: 'transient');
          }
          return null;
        });
        final lifecycle = ReaderPlatformViewLifecycle(
          viewType: 'test/reader',
          creationParams: const {},
          onAllocated: (_) {},
          beforeDispose: () async {
            readerAttempts++;
            if (failReader && readerAttempts == 1) throw PlatformException(code: 'transient');
          },
        );
        await lifecycle.create(platform, const Size(300, 500));
        await lifecycle.dispose();
        expect(readerAttempts, failReader ? 2 : 1);
        expect(platformAttempts, failReader ? 1 : 2);
      });
    }

    test('$platform 持续拆除失败不确认成功，失败 Future 不会永久缓存', () async {
      debugDefaultTargetPlatformOverride = platform;
      var attempts = 0;
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (call) async {
        if (call.method == 'create') return platform == TargetPlatform.android ? 1 : null;
        if (call.method == 'dispose' && ++attempts <= 2) throw PlatformException(code: 'persistent');
        return null;
      });
      final lifecycle = ReaderPlatformViewLifecycle(
        viewType: 'test/reader',
        creationParams: const {},
        onAllocated: (_) {},
        beforeDispose: () async {},
      );
      await lifecycle.create(platform, const Size(300, 500));
      await expectLater(lifecycle.dispose(), throwsA(isA<PlatformException>()));
      expect(attempts, 2);
      await lifecycle.dispose();
      expect(attempts, 3);
    });
  }

  test('从未开始创建的视口可直接关闭，关闭后不允许晚到创建', () async {
    var allocated = false;
    final lifecycle = ReaderPlatformViewLifecycle(
      viewType: 'test/reader',
      creationParams: const {},
      onAllocated: (_) => allocated = true,
      beforeDispose: () async => fail('不存在原生视口'),
    );
    await lifecycle.dispose();
    await lifecycle.create(TargetPlatform.android, const Size(300, 500));
    expect(allocated, isFalse);
    expect(lifecycle.hasStarted, isFalse);
  });
}
