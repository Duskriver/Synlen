import 'package:flutter/material.dart';

/// 阅读样式面板中的开关行：左侧 [icon] 与 [label]，右侧 [Switch]。
///
/// 用于阅读器的布尔偏好，如"跟随应用主题"。
class LabeledSwitchTile extends StatelessWidget {
  const LabeledSwitchTile({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.icon = Icons.brightness_auto_outlined,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  /// Leading icon displayed to the left of [label].
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
