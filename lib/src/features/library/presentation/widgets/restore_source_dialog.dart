import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';

/// 恢复备份的来源：标准 ZIP 备份文件，或旧版本导出的文件夹。
enum RestoreBackupSource { zipFile, folder }

/// 恢复备份前选择来源的对话框。
class RestoreSourceDialog extends StatelessWidget {
  const RestoreSourceDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.restoreFromBackup),
      content: Text(l10n.restoreSourceHint),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, RestoreBackupSource.folder),
          child: Text(l10n.restoreSourceFolder),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, RestoreBackupSource.zipFile),
          child: Text(l10n.restoreSourceFile),
        ),
      ],
    );
  }
}
