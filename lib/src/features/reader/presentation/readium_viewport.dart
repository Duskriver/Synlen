import 'package:flutter/material.dart';
import 'package:flutter_readium/flutter_readium.dart';

import '../../../../l10n/app_localizations.dart';
import '../application/readium_session.dart';
import '../domain/readium_interaction.dart';

/// 挂载身份固定到这一代原生视口，所有迟到回调交会话核验。
class ReadiumViewport extends StatefulWidget {
  const ReadiumViewport({
    super.key,
    required this.session,
    required this.onInteraction,
    required this.onExternalLink,
    required this.onImage,
    required this.controls,
    required this.handleInternalLinks,
  });
  final ReadiumSession session;
  final void Function(
    ReadiumInteraction event,
    Rect? anchorRect,
    List<Rect>? wordRects,
  )
  onInteraction;
  final ValueChanged<String> onExternalLink;
  final ValueChanged<ImageTapEvent> onImage;
  final ValueNotifier<bool> controls;
  final bool handleInternalLinks;

  @override
  State<ReadiumViewport> createState() => _ReadiumViewportState();
}

class _ReadiumViewportState extends State<ReadiumViewport> {
  late final String _id;
  @override
  void initState() {
    super.initState();
    _id = widget.session.sessionId;
    widget.session.viewMounted(_id);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final session = widget.session;
    return ReadiumReaderWidget(
      publication: session.publication!,
      sessionId: _id,
      initialLocator: session.initialLocator,
      fontFamilyDeclarations: session.layout!.fonts,
      handlePointerControls: false,
      handleInternalLinks: widget.handleInternalLinks,
      shouldShowControls: widget.controls,
      allowedDefaultActions: const {},
      onLocatorChanged: (locator) => session.reportLocator(_id, locator),
      onReaderReady: () => session.reportReady(_id),
      onReaderError: (code) => session.reportError(_id, code),
      onReaderDisposed: () => session.viewDisposed(_id),
      onTextInteraction: (payload) {
        if (!mounted) return;
        final event = session.interaction(_id, payload);
        if (event == null) return;
        Rect? globalAnchor;
        List<Rect>? globalWords;
        final anchor = event.anchorRect;
        if (anchor != null) {
          final box = context.findRenderObject();
          if (box is! RenderBox || !box.hasSize) return;
          Rect? toGlobal(ReadiumWordRect rect) {
            final local = Rect.fromLTWH(
              rect.x,
              rect.y,
              rect.width,
              rect.height,
            ).intersect(Offset.zero & box.size);
            if (local.isEmpty) return null;
            return Rect.fromPoints(
              box.localToGlobal(local.topLeft),
              box.localToGlobal(local.bottomRight),
            );
          }

          globalAnchor = toGlobal(anchor);
          if (globalAnchor == null) return;
          globalWords = event.wordRects
              ?.map(toGlobal)
              .whereType<Rect>()
              .toList();
          if (globalWords != null && globalWords.isEmpty) return;
        }
        widget.onInteraction(event, globalAnchor, globalWords);
      },
      onExternalLinkActivated: (url) {
        if (mounted && _id == session.sessionId && session.ready) {
          widget.onExternalLink(url);
        }
      },
      onImageTapped: (event) {
        if (mounted && _id == session.sessionId && session.ready) {
          widget.onImage(event);
        }
      },
      goForwardSemanticLabel: strings.next,
      goBackwardSemanticLabel: strings.previous,
      toggleShowControlsSemanticLabel: strings.readerControls,
    );
  }
}
