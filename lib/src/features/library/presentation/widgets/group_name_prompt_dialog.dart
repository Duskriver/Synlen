import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../l10n/app_localizations.dart';

/// 新建分组时输入名称的对话框；返回 trim 后的输入内容（未 trim 判空交给调用方）。
class GroupNamePromptDialog extends StatefulWidget {
  const GroupNamePromptDialog({super.key});

  @override
  State<GroupNamePromptDialog> createState() => _GroupNamePromptDialogState();
}

class _GroupNamePromptDialogState extends State<GroupNamePromptDialog> {
  var _draftName = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.newCategory),
      content: TextField(
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(labelText: l10n.categoryName),
        onChanged: (value) => _draftName = value,
        onSubmitted: (value) => Navigator.pop(context, value.trim()),
        inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'[\n\r]'))],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _draftName.trim()),
          child: Text(l10n.create),
        ),
      ],
    );
  }
}
