import 'package:flutter/material.dart';
import 'package:synlen/src/core/config/app_info.dart';

/// 设置页顶部的应用图标、名称与版本号。
class SettingsAppHeader extends StatelessWidget {
  const SettingsAppHeader({super.key, required this.version});

  final String version;

  static const _appIconPath = 'assets/icons/icon_opaque.png';
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: Image.asset(_appIconPath, fit: BoxFit.cover),
        ),

        const SizedBox(height: 16),

        Text(
          AppInfo.appName,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
        ),

        const SizedBox(height: 8),

        if (version.isNotEmpty)
          Text(
            'v$version',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
      ],
    );
  }
}
