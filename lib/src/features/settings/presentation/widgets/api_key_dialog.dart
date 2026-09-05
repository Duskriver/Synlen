import 'package:flutter/material.dart';
import 'package:synlen/l10n/app_localizations.dart';
import 'package:synlen/src/core/services/toast_service.dart';

class ApiKeyDialog extends StatefulWidget {
  const ApiKeyDialog({
    super.key,
    required this.title,
    required this.providerName,
    required this.initialValue,
    required this.onSave,
  });

  final String title;
  final String providerName;
  final String initialValue;
  final Future<bool> Function(String) onSave;

  @override
  State<ApiKeyDialog> createState() => _ApiKeyDialogState();
}

class _ApiKeyDialogState extends State<ApiKeyDialog> {
  late final _controller = TextEditingController(text: widget.initialValue);
  var _obscure = true;
  var _saving = false;
  var _saveFailed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save(String value) async {
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    final success = await widget.onSave(value);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    if (success) {
      ToastService.showSuccess(
        value.isEmpty ? l10n.apiKeyCleared : l10n.apiKeySaved,
      );
      Navigator.of(context).pop();
    } else {
      setState(() {
        _saving = false;
        _saveFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            enabled: !_saving,
            obscureText: _obscure,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              hintText: l10n.apiKeyInputHint,
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          if (_saveFailed)
            Text(
              l10n.apiKeySaveFailed,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 8),
          Text(
            l10n.apiKeyObtainHint(widget.providerName),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
      actions: [
        if (widget.initialValue.isNotEmpty)
          TextButton(
            onPressed: _saving ? null : () => _save(''),
            child: Text(l10n.clearKey),
          ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : () => _save(_controller.text.trim()),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
