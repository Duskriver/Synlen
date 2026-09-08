import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synlen/src/core/services/toast_service.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../application/cache_cleanup.dart';

/// List tile that cleans cached and orphaned files when tapped.
/// Manages its own [_isCleaning] busy state so the parent screen stays lean.
class CleanCacheTile extends ConsumerStatefulWidget {
  const CleanCacheTile({super.key});

  @override
  ConsumerState<CleanCacheTile> createState() => _CleanCacheTileState();
}

class _CleanCacheTileState extends ConsumerState<CleanCacheTile> {
  bool _isCleaning = false;

  Future<void> _clean() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isCleaning = true);

    final deletedCount = await ref
        .read(cacheCleanupProvider.notifier)
        .cleanAll();

    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    setState(() => _isCleaning = false);

    final message = deletedCount == 0
        ? l10n.cleanCacheSuccess
        : l10n.cleanCacheSuccessWithCount(deletedCount);

    ToastService.showSuccess(message);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
      leading: Icon(
        Icons.cleaning_services_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      title: Text(l10n.cleanCache),
      subtitle: Text(
        l10n.cleanCacheSubtitle,
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: _isCleaning
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      onTap: _isCleaning ? null : _clean,
    );
  }
}
