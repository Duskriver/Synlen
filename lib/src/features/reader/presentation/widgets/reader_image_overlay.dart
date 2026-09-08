import 'package:flutter/material.dart';

import 'package:synlen/src/core/theme/app_theme.dart';
import 'package:synlen/src/features/reader/application/epub_webview_handler.dart';
import 'package:synlen/src/features/reader/domain/epub_theme.dart';

import '../image_viewer.dart';

/// 图片查看覆盖层：长按图片后从原位置放大展开。
///
/// 不可见时保持挂载（[IgnorePointer] + 透明），避免展开 / 收起时重建
/// [ImageViewer] 内部状态；没有图片时渲染空占位。
class ReaderImageOverlay extends StatelessWidget {
  const ReaderImageOverlay({
    super.key,
    required this.visible,
    required this.imageUrl,
    required this.sourceRect,
    required this.webViewHandler,
    required this.epubPath,
    required this.fileHash,
    required this.epubTheme,
    required this.onClose,
  });

  final bool visible;
  final String? imageUrl;
  final Rect? sourceRect;
  final EpubWebViewHandler webViewHandler;
  final String epubPath;
  final String fileHash;
  final EpubTheme epubTheme;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    final rect = sourceRect;
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          duration: const Duration(
            milliseconds: AppTheme.defaultAnimationDurationMs,
          ),
          curve: Curves.easeOut,
          opacity: visible ? 1.0 : 0.0,
          child: (url != null && rect != null)
              ? ImageViewer(
                  imageUrl: url,
                  webViewHandler: webViewHandler,
                  epubPath: epubPath,
                  fileHash: fileHash,
                  onClose: onClose,
                  sourceRect: rect,
                  epubTheme: epubTheme,
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}
