import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_readium/flutter_readium.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synlen/l10n/app_localizations.dart';
import 'package:synlen/src/core/providers/shared_preferences_provider.dart';
import 'package:synlen/src/features/library/application/book_queries.dart';
import 'package:synlen/src/features/reader/application/readium_gateway.dart';
import 'package:synlen/src/features/reader/application/readium_layout.dart';
import 'package:synlen/src/features/reader/application/readium_session.dart';
import 'package:synlen/src/features/reader/application/reader_session_factory.dart';
import 'package:synlen/src/features/reader/presentation/control_panel.dart';
import 'package:synlen/src/features/reader/presentation/reader_screen.dart';
import 'package:synlen/src/features/reader/presentation/readium_viewport.dart';

class _Queries implements BookQueries {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Gateway implements ReadiumGateway {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Session extends ReadiumSession {
  _Session()
    : super(
        fileHash: 'book',
        prepare: (_) => throw UnimplementedError(),
        queries: _Queries(),
        gateway: _Gateway(),
      );

  @override
  Future<void> open(ReadiumLayout newLayout) async {
    layout = newLayout;
    publication = Publication.fromJson({
      'metadata': {'title': 'Reading'},
      'links': <Object>[],
      'readingOrder': [
        {'href': 'chapter.xhtml', 'type': 'application/xhtml+xml'},
      ],
    })!;
    locator = Locator(href: 'chapter.xhtml', type: 'application/xhtml+xml');
    ready = true;
  }

  @override
  void requestLayout(ReadiumLayout next) {}
  @override
  Future<bool> flush() async => true;
  @override
  Future<bool> close() async => true;
}

class _Factory extends ReaderSessionFactory {
  _Factory(this.session)
    : super(
        prepare: (_) => throw UnimplementedError(),
        queries: _Queries(),
        gateway: _Gateway(),
      );
  final _Session session;
  @override
  ReadiumSession create(String fileHash) => session;
}

void main() {
  testWidgets('底部Flutter留白短点打开多功能菜单', (tester) async {
    tester.view.physicalSize = const Size(412, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tester.binding.defaultBinaryMessenger.setMockMessageHandler(
      'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
      (_) async => const StandardMessageCodec().encodeMessage([null]),
    );
    final session = _Session();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          readerSessionFactoryProvider.overrideWithValue(_Factory(session)),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ReaderScreen(fileHash: 'book'),
        ),
      ),
    );
    await tester.pump();
    final viewport = tester.getRect(find.byType(ReadiumViewport));
    final blank = Offset(206, viewport.bottom + 12);
    expect(viewport.contains(blank), isFalse);
    expect(
      tester.widget<ControlPanel>(find.byType(ControlPanel)).showControls,
      isFalse,
    );
    await tester.tapAt(blank);
    await tester.pump();
    expect(
      tester.widget<ControlPanel>(find.byType(ControlPanel)).showControls,
      isTrue,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
