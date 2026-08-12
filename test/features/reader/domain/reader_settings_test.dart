import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/core/theme/app_theme_settings.dart';
import 'package:synlen/src/features/reader/domain/reader_settings.dart';

void main() {
  group('ReaderSettings 默认值', () {
    test('should provide sensible defaults', () {
      const settings = ReaderSettings();
      expect(settings.zoom, 1.0);
      expect(settings.followAppTheme, isTrue);
      expect(settings.themeIndex, 0);
      expect(settings.linkHandling, ReaderLinkHandling.ask);
      expect(settings.handleIntraLink, isTrue);
      expect(settings.pageAnimation, ReaderPageAnimation.slide);
      expect(settings.fontFileName, isNull);
      expect(settings.overrideFontFamily, isFalse);
      expect(settings.volumeKeyTurnsPage, isFalse);
    });
  });

  group('ReaderSettings.copyWith', () {
    test('should override only the fields passed in', () {
      const original = ReaderSettings(zoom: 1.2, marginLeft: 24);
      final updated = original.copyWith(zoom: 1.5);

      expect(updated.zoom, 1.5);
      expect(updated.marginLeft, 24);
      expect(updated.followAppTheme, original.followAppTheme);
      expect(updated.linkHandling, original.linkHandling);
    });

    test('should keep fontFileName when the parameter is omitted', () {
      const original = ReaderSettings(fontFileName: 'serif.ttf');
      final updated = original.copyWith(zoom: 1.3);

      expect(updated.fontFileName, 'serif.ttf');
    });

    test('should clear fontFileName when null is passed explicitly', () {
      const original = ReaderSettings(fontFileName: 'serif.ttf');
      final updated = original.copyWith(fontFileName: null);

      expect(updated.fontFileName, isNull);
    });

    test('should switch enum fields', () {
      const original = ReaderSettings();
      final updated = original.copyWith(
        linkHandling: ReaderLinkHandling.never,
        pageAnimation: ReaderPageAnimation.none,
      );

      expect(updated.linkHandling, ReaderLinkHandling.never);
      expect(updated.pageAnimation, ReaderPageAnimation.none);
    });
  });

  group('ReaderSettings 预设主题', () {
    test('should map themeIndex to the matching preset', () {
      for (var i = 0; i < SynlenThemePreset.values.length; i++) {
        expect(
          ReaderSettings(themeIndex: i).currentPreset,
          SynlenThemePreset.fromIndex(i),
        );
      }
    });

    test('should clamp out-of-range themeIndex to standardLight', () {
      expect(
        ReaderSettings(themeIndex: 999).currentPreset,
        SynlenThemePreset.standardLight,
      );
      expect(
        ReaderSettings(themeIndex: -1).currentPreset,
        SynlenThemePreset.standardLight,
      );
    });

    test('should expose the color scheme of the current preset', () {
      final settings = ReaderSettings(themeIndex: 2);
      expect(settings.currentColorScheme, settings.currentPreset.colorScheme);
    });
  });
}
