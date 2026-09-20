import 'package:flutter/material.dart';
import 'package:synlen/src/core/theme/app_theme.dart';

class EpubTheme {
  final double zoom;
  final bool shouldOverrideTextColor;
  final ColorScheme colorScheme;
  final Color? overridePrimaryColor;
  final EdgeInsets padding;

  /// 导入字体文件名；null 表示使用书籍字体。
  final String? fontFileName;

  /// 是否用导入字体覆盖出版者指定的字体。
  final bool overrideFontFamily;

  EpubTheme({
    required this.zoom,
    required this.shouldOverrideTextColor,
    required this.colorScheme,
    this.overridePrimaryColor,
    required this.padding,
    this.fontFileName,
    this.overrideFontFamily = false,
  });

  bool get isDark => colorScheme.brightness == Brightness.dark;

  Color get surfaceColor => colorScheme.surface;

  ThemeData get themeData => AppTheme.buildTheme(colorScheme);

  EpubTheme copyWith({
    double? zoom,
    bool? shouldOverrideTextColor,
    ColorScheme? colorScheme,
    Color? overridePrimaryColor,
    EdgeInsets? padding,
    Object? fontFileName = _kUnset,
    bool? overrideFontFamily,
  }) {
    return EpubTheme(
      zoom: zoom ?? this.zoom,
      shouldOverrideTextColor:
          shouldOverrideTextColor ?? this.shouldOverrideTextColor,
      colorScheme: colorScheme ?? this.colorScheme,
      overridePrimaryColor: overridePrimaryColor ?? this.overridePrimaryColor,
      padding: padding ?? this.padding,
      fontFileName: identical(fontFileName, _kUnset)
          ? this.fontFileName
          : fontFileName as String?,
      overrideFontFamily: overrideFontFamily ?? this.overrideFontFamily,
    );
  }

  static const Object _kUnset = Object();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is EpubTheme &&
        other.zoom == zoom &&
        other.shouldOverrideTextColor == shouldOverrideTextColor &&
        other.colorScheme == colorScheme &&
        other.overridePrimaryColor == overridePrimaryColor &&
        other.padding == padding &&
        other.fontFileName == fontFileName &&
        other.overrideFontFamily == overrideFontFamily;
  }

  @override
  int get hashCode => Object.hash(
    zoom,
    shouldOverrideTextColor,
    colorScheme,
    overridePrimaryColor,
    padding,
    fontFileName,
    overrideFontFamily,
  );
}
