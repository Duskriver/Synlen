import 'package:flutter/material.dart';

/// 阅读样式面板的主区块标题。
///
/// 以主题主色 14sp 渲染 [label]。
class ReaderSectionTitle extends StatelessWidget {
  const ReaderSectionTitle({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 14,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
