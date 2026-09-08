import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/library/application/library_notifier.dart';
import 'features/library/application/bookshelf_notifier.dart';
import 'features/library/domain/import_progress.dart';
import 'features/library/presentation/widgets/progress_dialog.dart';
import '../l10n/app_localizations.dart';
import 'core/services/toast_service.dart';
import 'core/file_handling/platform_path.dart';
import 'features/library/data/services/unified_import_service_provider.dart';

/// 待处理文件路径（"用其他应用打开"/分享进入应用后，等待返回书架页处理）
class PendingRouteFileNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? value) => state = value;

  void clear() => state = null;
}

final pendingRouteFileProvider =
    NotifierProvider<PendingRouteFileNotifier, String?>(
      PendingRouteFileNotifier.new,
    );

/// A transparent widget that lives above the app navigator and listens for
/// incoming EPUB files from the OS ("Open with" / share-sheet).
class GolbalShareHandler extends ConsumerWidget {
  final Widget child;

  const GolbalShareHandler({required this.child, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    _listenPendingRouteFile(context, ref);
    return child;
  }

  void _listenPendingRouteFile(BuildContext context, WidgetRef ref) {
    ref.listen<String?>(pendingRouteFileProvider, (previous, nextPath) {
      if (nextPath != null && nextPath.isNotEmpty) {
        final platformPath = PlatformPath.fromString(nextPath);

        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await _runImportPipeline(context, ref, [platformPath]);
        });

        Future.microtask(() {
          ref.read(pendingRouteFileProvider.notifier).clear();
        });
      }
    });
  }

  Future<void> _runImportPipeline(
    BuildContext context,
    WidgetRef ref,
    List<PlatformPath> paths,
  ) async {
    // 使用 navigator key 的 context，这样无论当前路由如何，我们都能在整个树中的任意位置弹出对话框或遮罩层。
    final navContext = ToastService.navigatorKey.currentContext;
    if (navContext == null || !navContext.mounted) return;

    final l10n = AppLocalizations.of(navContext)!;

    final stream = ref
        .read(libraryProvider.notifier)
        .importPipelineStream(paths);

    await showDialog(
      context: navContext,
      barrierDismissible: false,
      barrierColor: Theme.of(
        navContext,
      ).colorScheme.scrim.withValues(alpha: 0.5),
      builder: (ctx) => _ShareImportProgressDialog(stream: stream, l10n: l10n),
    );

    // Clean up any leftover temp cache files created during this session.
    ref.read(unifiedImportServiceProvider).clearAllCache();

    // Refresh the bookshelf so the newly imported book appears immediately.
    await ref.read(bookshelfProvider.notifier).refresh();
  }
}

// ---------------------------------------------------------------------------
// Private stream-aware host widget for GolbalShareHandler's import dialog.
// ---------------------------------------------------------------------------

class _ShareImportProgressDialog extends StatefulWidget {
  final Stream<ProgressLog> stream;
  final AppLocalizations l10n;

  const _ShareImportProgressDialog({required this.stream, required this.l10n});

  @override
  State<_ShareImportProgressDialog> createState() =>
      _ShareImportProgressDialogState();
}

class _ShareImportProgressDialogState
    extends State<_ShareImportProgressDialog> {
  StreamSubscription<ProgressLog>? _sub;

  int _totalCount = 0;
  int _currentCount = 0;
  int _successCount = 0;
  int _failedCount = 0;
  String _currentFileName = '';
  bool _isCompleted = false;
  final List<ProgressLog> _logs = [];

  @override
  void initState() {
    super.initState();
    _sub = widget.stream.listen(
      _onData,
      onError: _onError,
      onDone: _onDone,
      cancelOnError: false,
    );
  }

  void _onData(ProgressLog log) {
    if (!mounted) return;
    setState(() {
      _logs.add(log);
      if (log is ImportProgress) {
        _totalCount = log.totalCount;
        _currentCount = log.currentCount;
        _currentFileName = log.currentFileName;
        if (log.status == ImportStatus.success) {
          _successCount++;
        } else if (log.status == ImportStatus.failed) {
          _failedCount++;
        }
      }
    });
  }

  void _onError(Object error, StackTrace st) {
    if (!mounted) return;
    setState(() => _isCompleted = true);
    ToastService.showError(widget.l10n.importFailed(error.toString()));
  }

  void _onDone() {
    if (!mounted) return;
    setState(() => _isCompleted = true);
    ToastService.showSuccess(widget.l10n.importCompleted);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasProgress = _totalCount > 0;
    final isDone =
        _isCompleted || (_totalCount > 0 && _currentCount == _totalCount);
    final progressValue = hasProgress
        ? (isDone ? 1.0 : _currentCount / _totalCount)
        : null;

    return ProgressDialog(
      title: widget.l10n.importing,
      completeTitle: widget.l10n.importCompleted,
      progressMessage: widget.l10n.importingProgress(
        _successCount,
        _failedCount,
        _totalCount - _successCount - _failedCount,
      ),
      processingMessage: widget.l10n.progressing(_currentFileName),
      progressValue: progressValue,
      isCompleted: isDone,
      logs: _logs,
    );
  }
}
