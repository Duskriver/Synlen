import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ReadiumImageDialog extends StatelessWidget {
  const ReadiumImageDialog({super.key, required this.url, required this.svg});
  final String url;
  final bool svg;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.parse(url);
    final remote = uri.scheme == 'https' || uri.scheme == 'http';
    final file = File(uri.scheme == 'file' ? uri.toFilePath() : url);
    final Widget image = svg
        ? remote
              ? SvgPicture.network(url)
              : SvgPicture.file(file)
        : remote
        ? Image.network(url)
        : Image.file(file);
    return Dialog.fullscreen(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        onLongPress: () {},
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 6,
          child: Center(
            child: GestureDetector(
              // 图片消费点按，命中区域随缩放和平移变化；外部短点才关闭。
              onTap: () {},
              child: image,
            ),
          ),
        ),
      ),
    );
  }
}
