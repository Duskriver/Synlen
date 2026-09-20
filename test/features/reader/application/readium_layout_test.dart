import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/core/storage/app_storage.dart';
import 'package:synlen/src/features/reader/application/readium_layout.dart';
import 'package:synlen/src/features/reader/domain/epub_theme.dart';

void main() {
  EpubTheme theme({String? font, bool override = false, bool colors = false}) =>
      EpubTheme(
        zoom: 1.5,
        shouldOverrideTextColor: colors,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        padding: const EdgeInsets.fromLTRB(10, 20, 30, 40),
        fontFileName: font,
        overrideFontFamily: override,
      );
  test('字号按比例传入、边距由宿主提供且默认尊重书籍颜色和字体', () {
    final configuration = ReadiumLayout(theme());
    final preferences = configuration.preferences;
    expect(preferences.fontSize, 1.5);
    expect(preferences.pageMargins, 0);
    expect(preferences.publisherStyles, isTrue);
    expect(preferences.textColor, isNull);
    expect(configuration.fonts, isEmpty);
    expect(
      configuration.theme.padding,
      const EdgeInsets.fromLTRB(10, 20, 30, 40),
    );
  });
  test('导入字体采用本地文件URI，强制字体和夜间颜色随同一次视口创建生效', () {
    AppStorage.initForTesting(
      documentsPath: '/tmp/reader-layout',
      tempPath: '/tmp/reader-layout-cache',
    );
    final configuration = ReadiumLayout(
      theme(font: '中文字体.ttf', override: true, colors: true),
    );
    expect(
      configuration.fonts.single.faces.single.asset,
      Uri.file('/tmp/reader-layout/fonts/中文字体.ttf').toString(),
    );
    expect(
      configuration.preferences.fontFamily,
      configuration.fonts.single.name,
    );
    expect(configuration.preferences.publisherStyles, isFalse);
    expect(
      configuration.preferences.textColor,
      configuration.theme.colorScheme.onSurface,
    );
  });
  test('内链开关变化需要重建视口，即使排版偏好未变化', () {
    final value = theme();
    expect(
      ReadiumLayout(value),
      isNot(ReadiumLayout(value, handleInternalLinks: false)),
    );
    expect(ReadiumLayout(value), ReadiumLayout(value));
  });
}
