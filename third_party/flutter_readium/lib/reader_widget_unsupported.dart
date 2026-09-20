import 'package:flutter/material.dart';
import 'flutter_readium.dart';

class ReadiumReaderWidget extends StatelessWidget {
  const ReadiumReaderWidget({
    required this.publication,
    this.loadingWidget = const Center(child: CircularProgressIndicator()),
    this.initialLocator,
    this.shouldShowControls,
    this.onExternalLinkActivated,
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
    this.selectionActions = const [],
    this.allowedDefaultActions,
    this.fontFamilyDeclarations = const [],
    this.goBackwardSemanticLabel = 'Go Backward',
    this.goForwardSemanticLabel = 'Go Forward',
    this.toggleShowControlsSemanticLabel = 'Toggle show controls',
    this.verticalScroll = false,
    super.key,
  });

  final Publication publication;
  final Widget loadingWidget;
  final Locator? initialLocator;
  final ValueNotifier<bool>? shouldShowControls;
  final Function(String)? onExternalLinkActivated;
  final ValueChanged<TextSelectionEvent>? onTextSelected;

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

  final ValueChanged<SelectionActionEvent>? onSelectionAction;
  final ValueChanged<DecorationInteractionEvent>? onDecorationInteraction;
  final ValueChanged<ImageTapEvent>? onImageTapped;
  final List<SelectionAction> selectionActions;
  final Set<DefaultSelectionAction>? allowedDefaultActions;
  final List<ReaderFontFamily> fontFamilyDeclarations;
  final String goBackwardSemanticLabel;
  final String goForwardSemanticLabel;
  final String toggleShowControlsSemanticLabel;
  final bool verticalScroll;

  @override
  Widget build(final BuildContext context) => Center(child: Text('ReaderWidget is not available on this platform.'));
}
