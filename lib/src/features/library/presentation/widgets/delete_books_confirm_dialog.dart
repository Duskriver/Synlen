import 'package:flutter/material.dart';

import '../../../../../l10n/app_localizations.dart';

/// 删除选中书籍的确认对话框；返回 true 表示确认删除。
class DeleteBooksConfirmDialog extends StatelessWidget {
  const DeleteBooksConfirmDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.deleteBooks),
      content: Text(l10n.deleteBooksConfirm),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.delete),
        ),
      ],
    );
  }
}
