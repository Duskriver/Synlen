import 'package:flutter_readium/flutter_readium.dart';
import 'package:path/path.dart' as p;

import '../../../core/storage/app_storage.dart';
import '../domain/epub_theme.dart';

/// 排版参数随视口一起创建，避免在旧物理页码上直接修改字号。
class ReadiumLayout {
  const ReadiumLayout(this.theme, {this.handleInternalLinks = true});
  final bool handleInternalLinks;
  final EpubTheme theme;

  EPUBPreferences get preferences => EPUBPreferences(
    fontSize: theme.zoom,
    backgroundColor: theme.surfaceColor,
    textColor: theme.shouldOverrideTextColor
        ? theme.colorScheme.onSurface
        : null,
    fontFamily: theme.fontFileName == null ? null : 'SynlenUserFont',
    publisherStyles: !theme.overrideFontFamily,
    columnCount: EpubColumnCount.one,
    pageMargins: 0,
    scroll: false,
  );

  List<ReaderFontFamily> get fonts => theme.fontFileName == null
      ? const []
      : [
          ReaderFontFamily(
            name: 'SynlenUserFont',
            faces: [
              ReaderFontFace(
                asset: Uri.file(
                  p.join(
                    AppStorage.documentsPath,
                    'fonts',
                    p.basename(theme.fontFileName!),
                  ),
                ).toString(),
              ),
            ],
          ),
        ];

  @override
  bool operator ==(Object other) =>
      other is ReadiumLayout &&
      theme == other.theme &&
      handleInternalLinks == other.handleInternalLinks;
  @override
  int get hashCode => Object.hash(theme, handleInternalLinks);
}
