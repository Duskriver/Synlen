import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synlen/src/core/providers/shared_preferences_provider.dart';
import 'package:synlen/src/features/reader/application/reader_settings_notifier.dart';
import 'package:synlen/src/features/reader/domain/reader_settings.dart';
import 'package:synlen/src/features/settings/application/imported_font_file_names_provider.dart';

ProviderContainer buildContainer(
  SharedPreferences prefs, {
  Set<String> importedFonts = const {},
}) {
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      importedFontFileNamesProvider.overrideWith((ref) => importedFonts),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReaderSettingsNotifier.build', () {
    test('should load persisted settings from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'reader_zoom': 1.4,
        'reader_theme_mode': 2,
        'reader_link_handling': 2, // never
        'reader_page_animation': 0, // none
        'reader_volume_key_turns_page': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final container = buildContainer(prefs);
      addTearDown(container.dispose);

      final settings = container.read(readerSettingsProvider);

      expect(settings.zoom, 1.4);
      expect(settings.themeIndex, 2);
      expect(settings.linkHandling, ReaderLinkHandling.never);
      expect(settings.pageAnimation, ReaderPageAnimation.none);
      expect(settings.volumeKeyTurnsPage, isTrue);
    });

    test('should fall back to defaults when nothing is persisted', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = buildContainer(prefs);
      addTearDown(container.dispose);

      final settings = container.read(readerSettingsProvider);

      expect(settings.zoom, 1.0);
      expect(settings.linkHandling, ReaderLinkHandling.ask);
      expect(settings.pageAnimation, ReaderPageAnimation.slide);
    });
  });

  group('ReaderSettingsNotifier 持久化写入', () {
    test('should persist and update state on setter calls', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = buildContainer(prefs);
      addTearDown(container.dispose);
      final notifier = container.read(readerSettingsProvider.notifier);

      await notifier.setZoom(1.6);
      expect(container.read(readerSettingsProvider).zoom, 1.6);
      expect(prefs.getDouble('reader_zoom'), 1.6);

      await notifier.setLinkHandling(ReaderLinkHandling.always);
      expect(
        prefs.getInt('reader_link_handling'),
        ReaderLinkHandling.always.index,
      );

      await notifier.setPageAnimation(ReaderPageAnimation.none);
      expect(
        prefs.getInt('reader_page_animation'),
        ReaderPageAnimation.none.index,
      );
    });

    test('should remove the key when font is cleared', () async {
      SharedPreferences.setMockInitialValues({
        'reader_font_file_name': 'song.ttf',
      });
      final prefs = await SharedPreferences.getInstance();
      final container = buildContainer(
        prefs,
        importedFonts: const {'song.ttf'},
      );
      addTearDown(container.dispose);
      final notifier = container.read(readerSettingsProvider.notifier);

      await notifier.setFontFileName(null);
      expect(prefs.getString('reader_font_file_name'), isNull);
      expect(container.read(readerSettingsProvider).fontFileName, isNull);
    });
  });

  group('ReaderSettingsNotifier 字体失效清理', () {
    test('should clear a font that is no longer imported', () async {
      SharedPreferences.setMockInitialValues({
        'reader_font_file_name': 'gone.ttf',
        'reader_override_font_family': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final container = buildContainer(
        prefs,
        importedFonts: const {'other.ttf'},
      );
      addTearDown(container.dispose);

      final settings = container.read(readerSettingsProvider);

      expect(settings.fontFileName, isNull);
      expect(settings.overrideFontFamily, isFalse);
      expect(prefs.getString('reader_font_file_name'), isNull);
      expect(prefs.getBool('reader_override_font_family'), isNull);
    });

    test('should keep a font that is still imported', () async {
      SharedPreferences.setMockInitialValues({
        'reader_font_file_name': 'song.ttf',
        'reader_override_font_family': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final container = buildContainer(
        prefs,
        importedFonts: const {'song.ttf'},
      );
      addTearDown(container.dispose);

      final settings = container.read(readerSettingsProvider);

      expect(settings.fontFileName, 'song.ttf');
      expect(settings.overrideFontFamily, isTrue);
    });
  });
}
