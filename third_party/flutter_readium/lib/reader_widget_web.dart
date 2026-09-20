import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'flutter_readium.dart';
import 'src/index.dart';

class ReadiumReaderWidget extends StatefulWidget {
  const ReadiumReaderWidget({
    required this.publication,
    this.loadingWidget = const Center(child: CircularProgressIndicator()),
    this.initialLocator,
    this.shouldShowControls,
    this.onExternalLinkActivated,
    this.goBackwardSemanticLabel = 'Go Backward',
    this.goForwardSemanticLabel = 'Go Forward',
    this.toggleShowControlsSemanticLabel = 'Toggle show controls',
    this.verticalScroll = false,
    this.onTextSelected,
    this.onTextInteraction,
    this.onLocatorChanged,
    this.onReaderReady,
    this.onReaderError,
    this.onReaderDisposed,
    this.sessionId,
    this.handlePointerControls = true,
    this.handleInternalLinks = true,
    this.onSelectionAction,
    this.onDecorationInteraction,
    this.onImageTapped,
    this.selectionActions,
    this.allowedDefaultActions,
    this.fontFamilyDeclarations = const [],
    super.key,
  });

  final Publication publication;
  final Widget loadingWidget;
  final Locator? initialLocator;
  final ValueNotifier<bool>? shouldShowControls;
  final Function(String)? onExternalLinkActivated;
  final String goBackwardSemanticLabel;
  final String goForwardSemanticLabel;
  final String toggleShowControlsSemanticLabel;
  final bool verticalScroll;
  final void Function(TextSelectionEvent)? onTextSelected;

  /// 原生视口绑定的文字事件；身份字段由原生覆盖，宿主校验内容协议。
  final ValueChanged<String>? onTextInteraction;

  /// 当前视口的位置回执，不共享其他阅读会话的事件流。
  final ValueChanged<Locator>? onLocatorChanged;

  /// 首次位置回执之后调用；不表示后续字号重排已经完成。
  final VoidCallback? onReaderReady;
  final ValueChanged<String>? onReaderError;

  /// 原生视口拆除完成后调用，允许宿主随后重新打开同一出版物。
  final VoidCallback? onReaderDisposed;
  final String? sessionId;

  /// 自定义学习手势接管正文点击时设为 false；保留无障碍语义操作。
  final bool handlePointerControls;

  /// 是否跟随普通书内链接；脚注链接仍由阅读器处理。
  final bool handleInternalLinks;

  final void Function(SelectionActionEvent)? onSelectionAction;
  final void Function(DecorationInteractionEvent)? onDecorationInteraction;
  final ValueChanged<ImageTapEvent>? onImageTapped;
  final List<SelectionAction>? selectionActions;
  final Set<DefaultSelectionAction>? allowedDefaultActions;
  final List<ReaderFontFamily> fontFamilyDeclarations;

  @override
  State<ReadiumReaderWidget> createState() => _ReadiumReaderWidgetState();
}

class _ReadiumReaderWidgetState extends State<ReadiumReaderWidget> implements ReadiumReaderWidgetInterface {
  static final _log = ReadiumLog.tag('ReaderWidget');

  @override
  void initState() {
    super.initState();
    _log.d('Widget initiated');
  }

  @override
  void dispose() {
    _log.d('Widget disposed');
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) => SizedBox.expand(
    child: ReadiumWebView(
      publication: widget.publication,
      currentLocator: widget.initialLocator,
      fontFamilyDeclarations: widget.fontFamilyDeclarations,
      onTextSelected: widget.onTextSelected,
      onSelectionAction: widget.onSelectionAction,
      onDecorationInteraction: widget.onDecorationInteraction,
      onImageTapped: widget.onImageTapped,
    ),
  );

  @override
  Future<void> go(
    final Locator locator, {
    required final bool isAudioBookWithText,
    final bool animated = false,
  }) async {
    try {
      await JsPublicationChannel.goToLocator(json.encode(locator));
    } on PlatformException catch (e) {
      throw ReadiumException.fromPlatformException(e);
    }
  }

  @override
  Future<void> goBackward({final bool animated = true}) async {
    JsPublicationChannel.goBackward();
  }

  @override
  Future<void> goForward({final bool animated = true}) async {
    JsPublicationChannel.goForward();
  }

  @override
  Future<void> setEPUBPreferences(EPUBPreferences preferences) async {
    _log.d('setEPUBPreferences not implemented in web version');
  }

  @override
  Future<void> setPDFPreferences(PDFPreferences preferences) async {
    _log.d('setPDFPreferences not supported on web');
  }

  @override
  Future<void> applyDecorations(
    String id,
    List<ReaderDecoration> decorations,
  ) async {
    JsPublicationChannel().applyDecorations(
      id,
      json.encode(decorations.map((d) => d.toJson()).toList()),
    );
  }
}
