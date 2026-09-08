import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 阅读器外壳：系统 UI 样式与返回拦截。
///
/// 返回键行为由宿主决定：脚注浮层打开时先关浮层，否则落盘进度后退出。
class ReaderShell extends StatelessWidget {
  const ReaderShell({
    super.key,
    required this.overlayStyle,
    required this.canPop,
    required this.onPopInvoked,
    required this.child,
  });

  final SystemUiOverlayStyle overlayStyle;
  final bool canPop;
  final void Function(bool didPop) onPopInvoked;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, result) => onPopInvoked(didPop),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlayStyle,
        child: child,
      ),
    );
  }
}
