import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/features/reader/domain/epub_theme.dart';

void main() {
  EpubTheme buildTheme({
    ColorScheme? colorScheme,
    String? fontFileName,
    EdgeInsets padding = EdgeInsets.zero,
  }) {
    return EpubTheme(
      zoom: 1.0,
      shouldOverrideTextColor: false,
      colorScheme: colorScheme ?? ColorScheme.light(),
      padding: padding,
      fontFileName: fontFileName,
    );
  }

  group('EpubTheme.isDark', () {
    test('should follow the brightness of the color scheme', () {
      expect(buildTheme().isDark, isFalse);
      expect(buildTheme(colorScheme: ColorScheme.dark()).isDark, isTrue);
    });
  });

  group('EpubTheme.copyWith', () {
    test('should keep fontFileName when the parameter is omitted', () {
      final theme = buildTheme(fontFileName: 'song.ttf');
      expect(theme.copyWith(zoom: 1.2).fontFileName, 'song.ttf');
    });

    test('should clear fontFileName when null is passed explicitly', () {
      final theme = buildTheme(fontFileName: 'song.ttf');
      expect(theme.copyWith(fontFileName: null).fontFileName, isNull);
    });
  });

  group('EpubTheme 相等性', () {
    test('should treat identical values as equal', () {
      final a = buildTheme(fontFileName: 'song.ttf');
      final b = buildTheme(fontFileName: 'song.ttf');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('should treat different fields as unequal', () {
      final a = buildTheme(fontFileName: 'song.ttf');
      final b = buildTheme(fontFileName: 'kai.ttf');
      final c = a.copyWith(zoom: 1.5);

      expect(a, isNot(b));
      expect(a, isNot(c));
    });
  });
}
