import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../l10n/app_localizations.dart';

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
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 6,
              child: Center(child: image),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: IconButton(
                tooltip: AppLocalizations.of(context)!.close,
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
