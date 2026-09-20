import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// 原生视口之外的留白接收菜单短点；视口内的触摸仍归原生阅读器。
class ReaderPageStage extends StatefulWidget {
  const ReaderPageStage({
    super.key,
    required this.padding,
    required this.child,
    required this.onBlankTap,
  });

  final EdgeInsets padding;
  final Widget child;
  final VoidCallback? onBlankTap;

  @override
  State<ReaderPageStage> createState() => _ReaderPageStageState();
}

class _ReaderPageStageState extends State<ReaderPageStage> {
  final _pointers = <int>{};
  PointerDownEvent? _start;

  void _down(PointerDownEvent event) {
    _pointers.add(event.pointer);
    if (_pointers.length != 1 || event.buttons != kPrimaryButton) {
      _start = null;
    }
  }

  void _move(PointerMoveEvent event) {
    final start = _start;
    if (start != null &&
        event.pointer == start.pointer &&
        (event.position - start.position).distance > 10) {
      _start = null;
    }
  }

  void _up(PointerUpEvent event) {
    _pointers.remove(event.pointer);
    final start = _start;
    if (start?.pointer != event.pointer) return;
    _start = null;
    if ((event.position - start!.position).distance <= 10 &&
        event.timeStamp - start.timeStamp < const Duration(milliseconds: 550)) {
      widget.onBlankTap?.call();
    }
  }

  @override
  Widget build(BuildContext context) => Listener(
    // 观察整页指针以取消跨留白与正文的多指序列，不参加原生手势竞争。
    onPointerDown: _down,
    onPointerMove: _move,
    onPointerUp: _up,
    onPointerCancel: (event) {
      _pointers.remove(event.pointer);
      _start = null;
    },
    child: Stack(
      fit: StackFit.expand,
      children: [
        Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) {
            _start = widget.onBlankTap != null && _pointers.isEmpty
                ? event
                : null;
          },
        ),
        Padding(padding: widget.padding, child: widget.child),
      ],
    ),
  );
}
