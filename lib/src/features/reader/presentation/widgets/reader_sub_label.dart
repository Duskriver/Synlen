import 'package:flutter/material.dart';

/// 阅读样式面板中区块标题下的次级说明文字，用于描述一组控件的用途
/// （如"缩放""边距"）。
///
/// 以主题的 `onSurfaceVariant` 色 13sp 渲染 [label]。
class ReaderSubLabel extends StatelessWidget {
  const ReaderSubLabel({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
