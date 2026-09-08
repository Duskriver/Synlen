import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synlen/src/core/services/toast_service.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../application/backup_export.dart';

/// List tile that triggers a full library backup export.
///
/// Manages its own [_isExporting] busy state and uses a [GlobalKey] to anchor
/// the iOS Share Sheet popover to the tile's screen position.
class BackupTile extends ConsumerStatefulWidget {
  const BackupTile({super.key});

  @override
  ConsumerState<BackupTile> createState() => _BackupTileState();
}

class _BackupTileState extends ConsumerState<BackupTile> {
  bool _isExporting = false;
  final _tileKey = GlobalKey();

  /// Returns the screen-space [Rect] of this tile for the Share Sheet anchor.
  Rect? _tileRect() {
    final box = _tileKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final offset = box.localToGlobal(Offset.zero);
    return offset & box.size;
  }

  Future<void> _export() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    // Capture l10n before the async gap to avoid BuildContext use after await.
    final l10n = AppLocalizations.of(context)!;

    final error = await ref
        .read(backupExportProvider.notifier)
        .exportToShareSheet(
          sharePositionOrigin: _tileRect(),
          shareTitle: l10n.backupShareTitle,
        );

    if (!mounted) return;

    if (error == null) {
      ToastService.showSuccess(l10n.backupShared);
    } else {
      ToastService.showError(l10n.exportFailed(error));
    }

    setState(() => _isExporting = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListTile(
      key: _tileKey,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
      leading: Icon(
        Icons.archive_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      title: Text(l10n.backupLibrary),
      subtitle: Text(
        l10n.backupLibraryDescription,
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: _isExporting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      onTap: _isExporting ? null : _export,
    );
  }
}
