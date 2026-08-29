import 'package:flutter/material.dart';

/// 展开式 FAB 的子按钮定义
class ExpandableFabChild {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const ExpandableFabChild({
    required this.icon,
    required this.label,
    required this.onTap,
    this.backgroundColor,
    this.foregroundColor,
  });
}

/// 自研展开式悬浮按钮。
///
/// 替换已停更（2023-05 后无更新）的 flutter_speed_dial：
/// 点击主按钮展开/收起子按钮列表，点击子按钮执行动作并收起。
/// 无第三方依赖，样式与 Material 3 FAB 一致。
class ExpandableFab extends StatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final List<ExpandableFabChild> children;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double spaceBetweenChildren;

  const ExpandableFab({
    super.key,
    required this.icon,
    this.activeIcon = Icons.close,
    required this.children,
    this.backgroundColor,
    this.foregroundColor,
    this.spaceBetweenChildren = 12,
  });

  @override
  State<ExpandableFab> createState() => _ExpandableFabState();
}

class _ExpandableFabState extends State<ExpandableFab>
    with SingleTickerProviderStateMixin {
  bool _isOpen = false;
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );

  void _toggle() {
    setState(() => _isOpen = !_isOpen);
    _isOpen ? _controller.forward() : _controller.reverse();
  }

  void _close() {
    if (!_isOpen) return;
    setState(() => _isOpen = false);
    _controller.reverse();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildChildButton(ExpandableFabChild child) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 标签
        FadeTransition(
          opacity: _controller,
          child: Material(
            color: theme.colorScheme.surface,
            elevation: 2,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                child.label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // 圆形子按钮
        FloatingActionButton.small(
          heroTag: null,
          backgroundColor:
              child.backgroundColor ?? theme.colorScheme.primaryContainer,
          foregroundColor:
              child.foregroundColor ?? theme.colorScheme.onPrimaryContainer,
          onPressed: () {
            _close();
            child.onTap();
          },
          child: Icon(child.icon),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // 子按钮必须占据真实布局空间：此前用 Stack + 位移把子按钮绘制到
    // Stack 边界外，超出父组件边界的区域不参与命中测试，导致子按钮
    // 可见但永远点不到。改为 Column + AnimatedSize，在布局空间内展开。
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ClipRect(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.bottomCenter,
            child: _isOpen
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // 视觉上最后一个 child 显示在最上方
                      for (var i = widget.children.length - 1; i >= 0; i--)
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: widget.spaceBetweenChildren,
                          ),
                          child: _buildChildButton(widget.children[i]),
                        ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ),
        // 主按钮
        FloatingActionButton(
          heroTag: null,
          backgroundColor: widget.backgroundColor,
          foregroundColor: widget.foregroundColor,
          onPressed: _toggle,
          child: AnimatedRotation(
            turns: _isOpen ? 0.125 : 0,
            duration: const Duration(milliseconds: 200),
            child: Icon(_isOpen ? widget.activeIcon : widget.icon),
          ),
        ),
      ],
    );
  }
}
