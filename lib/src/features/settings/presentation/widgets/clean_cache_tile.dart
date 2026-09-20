import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synlen/src/core/services/toast_service.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../application/cache_cleanup.dart';

/// 订阅缓存清理状态，展示进度与本地化结果。
class CleanCacheTile extends ConsumerWidget {
  const CleanCacheTile({super.key});

  Future<void> _clean(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    await ref.read(cacheCleanupProvider.notifier).cleanAll();
    if (!context.mounted) return;
    ref
        .read(cacheCleanupProvider)
        .when(
          data: (deletedCount) {
            if (deletedCount == null) return;
            ToastService.showSuccess(
              deletedCount == 0
                  ? l10n.cleanCacheSuccess
                  : l10n.cleanCacheSuccessWithCount(deletedCount),
            );
          },
          error: (_, _) => ToastService.showError(l10n.cleanCacheFailed),
          loading: () {},
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isCleaning = ref.watch(cacheCleanupProvider).isLoading;

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
      trailing: isCleaning
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      onTap: isCleaning ? null : () => _clean(context, ref),
    );
  }
}
