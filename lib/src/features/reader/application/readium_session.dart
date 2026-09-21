import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_readium/flutter_readium.dart';

import '../../../core/services/app_logger.dart';
import '../../../core/url_launcher/url_launcher.dart';
import '../../library/application/book_queries.dart';
import '../../library/domain/book_progress.dart';
import '../domain/readium_interaction.dart';
import 'readium_gateway.dart';
import 'readium_layout.dart';
import 'readium_publication_source.dart';
import 'reading_progress_controller.dart';

enum ReaderFailure { load, render, progress, link, image }

/// 一次阅读拥有一份 Locator；重排期间冻结进度并串行销毁、重建原生视口。
class ReadiumSession extends ChangeNotifier {
  ReadiumSession({
    required this.fileHash,
    required Future<PreparedReadiumPublication> Function(String) prepare,
    required BookQueries queries,
    required ReadiumGateway gateway,
    Future<void> Function()? beforeOpen,
    Future<void> Function(Uri) launchLink = UrlLauncher.launch,
    Duration readyTimeout = const Duration(seconds: 20),
    Duration progressDebounce = const Duration(seconds: 1),
    Duration layoutDebounce = const Duration(milliseconds: 250),
  }) : _prepare = prepare,
       _queries = queries,
       _launchLink = launchLink,
       _gateway = gateway,
       _beforeOpen = beforeOpen,
       _readyTimeout = readyTimeout,
       _layoutDebounce = layoutDebounce {
    _progress = ReadingProgressController(
      save: (progress) =>
          _queries.saveProgress(bookId: prepared!.book.id, progress: progress),
      onSaveFailed: () => _fail(ReaderFailure.progress),
      debounce: progressDebounce,
    );
  }

  final String fileHash;
  final Future<PreparedReadiumPublication> Function(String) _prepare;
  final BookQueries _queries;
  final Future<void> Function(Uri) _launchLink;
  final ReadiumGateway _gateway;
  final Future<void> Function()? _beforeOpen;
  final Duration _readyTimeout;
  final Duration _layoutDebounce;
  late final ReadingProgressController _progress;
  final String _identity = DateTime.now().microsecondsSinceEpoch.toString();
  PreparedReadiumPublication? prepared;
  Publication? publication;
  Locator? locator;
  Locator? initialLocator;
  ReadiumLayout? layout;
  ReaderFailure? failure;
  bool ready = false;
  bool _closed = false;
  bool _disposed = false;
  bool _nativeReady = false;
  bool _ownsPublication = false;
  int _generation = 0;
  String? _mountedId;
  Locator? _candidate;
  Completer<void>? _detached;
  Completer<void>? _ready;
  Future<void>? _work;
  Future<bool>? _closing;
  ReadiumLayout? _pendingLayout;
  Timer? _layoutTimer;

  String get sessionId => '$_identity-$_generation';
  bool get isLoading => !ready && failure == null;
  List<Link> get readingOrder => publication?.readingOrder ?? const [];
  int get chapterIndex => readingOrder.indexWhere(
    (link) =>
        resourcePath(link.href) ==
        resourcePath(locator?.href ?? initialLocator?.href ?? ''),
  );

  /// 章节等权估算展示进度；部分原生 Locator 的全书比例只更新到章首。
  double get fraction {
    if (readingOrder.isEmpty || chapterIndex < 0) return 0;
    final progression = locator?.locations?.progression ?? 0;
    final withinChapter = progression.isFinite ? progression.clamp(0, 1) : 0;
    return (chapterIndex + withinChapter) / readingOrder.length;
  }

  Future<void> open(ReadiumLayout newLayout) {
    if (_closed) return Future.value();
    if (_work != null) return _work!;
    return _work = _open(newLayout).whenComplete(() => _work = null);
  }

  Future<void> _open(ReadiumLayout newLayout) async {
    try {
      failure = null;
      _notify();
      await _beforeOpen?.call();
      if (_closed) return;
      prepared ??= await _prepare(fileHash);
      if (_closed) return;
      initialLocator =
          locator ?? Locator.fromJson(prepared!.book.progress?.locator);
      await _replace(newLayout);
    } catch (error, stack) {
      _fail(ReaderFailure.load, error, stack);
    }
  }

  /// 可连续更新设置；排版完成后才接收下一份设置，过程中不保存中间位置。
  void requestLayout(ReadiumLayout next) {
    if (_closed || next == (_pendingLayout ?? layout)) return;
    _pendingLayout = next;
    _layoutTimer?.cancel();
    _layoutTimer = Timer(_layoutDebounce, () => unawaited(_drainLayouts()));
  }

  Future<void> _drainLayouts() async {
    await _work;
    if (_closed || _pendingLayout == null) return;
    final task = _applyLayouts();
    _work = task;
    await task;
    if (identical(_work, task)) _work = null;
  }

  Future<void> _applyLayouts() async {
    try {
      while (!_closed && _pendingLayout != null) {
        final next = _pendingLayout!;
        _pendingLayout = null;
        if (next == layout) continue;
        initialLocator = locator ?? initialLocator;
        await _replace(next);
      }
    } catch (error, stack) {
      _fail(ReaderFailure.render, error, stack);
    }
  }

  Future<void> _replace(ReadiumLayout next) async {
    ready = false;
    await _unmount();
    if (_ownsPublication) {
      await _gateway.close();
      _ownsPublication = false;
    }
    if (_closed) return;
    layout = next;
    _candidate = null;
    _nativeReady = false;
    _generation++;
    final opened = await _gateway.open(prepared!.path, next.preferences);
    _ownsPublication = true;
    if (_closed) return;
    initialLocator ??= _legacyLocator(opened);
    publication = opened;
    failure = null;
    _ready = Completer<void>();
    _notify();
    await _ready!.future.timeout(_readyTimeout);
  }

  /// 仅首次打开旧坐标时按原清单匹配资源；比例只用于近似落点。
  Locator? _legacyLocator(Publication opened) {
    final old = prepared!.book.progress?.legacy;
    if (old == null) return null;
    final spine = prepared!.manifest.spine;
    if (old.chapterIndex < 0 || old.chapterIndex >= spine.length) {
      throw StateError('旧阅读章节不在书籍清单中');
    }
    final href = spine[old.chapterIndex].href;
    final link = opened.readingOrder
        .where((link) => resourcePath(link.href) == resourcePath(href))
        .firstOrNull;
    if (link == null) throw StateError('旧阅读章节不在出版物中');
    return Locator(
      href: link.href,
      type: link.type ?? 'application/xhtml+xml',
      locations: Locations(progression: (old.progression ?? 0).clamp(0.0, 1.0)),
    );
  }

  void viewMounted(String id) {
    if (!_closed && id == sessionId) _mountedId = id;
  }

  void viewDisposed(String id) {
    if (_mountedId != id) return;
    _mountedId = null;
    if (_detached?.isCompleted == false) _detached!.complete();
  }

  Future<void> _unmount() async {
    final mounted = _mountedId != null;
    if (mounted) _detached = Completer<void>();
    publication = null;
    _notify();
    if (mounted) await _detached!.future.timeout(_readyTimeout);
    _detached = null;
  }

  void reportLocator(String id, Locator next) {
    if (_closed || id != sessionId || publication == null) return;
    if (!readingOrder.any(
      (link) => resourcePath(link.href) == resourcePath(next.href),
    )) {
      return;
    }
    if (!ready) {
      _candidate = next;
      _finishReady();
      return;
    }
    locator = next;
    _record();
    _notify();
  }

  void reportReady(String id) {
    if (_closed || id != sessionId) return;
    _nativeReady = true;
    _finishReady();
  }

  void _finishReady() {
    if (!_nativeReady || _candidate == null || ready) return;
    final expected = initialLocator;
    if (expected != null &&
        resourcePath(expected.href) != resourcePath(_candidate!.href)) {
      return;
    }
    locator = _candidate;
    ready = true;
    if (_ready?.isCompleted == false) _ready!.complete();
    _record();
    _notify();
  }

  void reportError(String id, String code) {
    if (_closed || id != sessionId) return;
    if (_ready?.isCompleted == false) _ready!.completeError(StateError(code));
    _fail(ReaderFailure.render, StateError(code));
  }

  ReadiumInteraction? interaction(String id, String payload) {
    if (!ready || _closed || id != sessionId || locator == null) return null;
    return ReadiumInteraction.parse(
      payload,
      sessionId: id,
      currentHref: locator!.href,
    );
  }

  Future<void> turnPage(bool forward, {required bool animated}) =>
      _navigate(() => _gateway.turnPage(forward, animated: animated));

  Future<void> goTo(String href) => _navigate(() async {
    final uri = Uri.parse(href);
    final target = readingOrder
        .where((link) => resourcePath(link.href) == resourcePath(href))
        .firstOrNull;
    if (target == null) return;
    await _gateway.go(
      Locator(
        href: target.href,
        type: target.type ?? 'application/xhtml+xml',
        locations: Locations(
          progression: 0,
          fragments: uri.fragment.isEmpty ? const [] : [uri.fragment],
        ),
      ),
      animated: false,
    );
  });

  Future<void> goToChapter(int index) {
    if (index < 0 || index >= readingOrder.length) return Future.value();
    return goTo(readingOrder[index].href);
  }

  Future<void> _navigate(Future<void> Function() action) async {
    if (_closed || !ready || _work != null) return;
    try {
      await action();
    } catch (error, stack) {
      _fail(ReaderFailure.render, error, stack);
    }
  }

  Future<void> openExternalLink(String url) async {
    final uri = Uri.tryParse(url);
    if (_closed ||
        uri == null ||
        !const ['http', 'https', 'mailto'].contains(uri.scheme)) {
      return;
    }
    try {
      await _launchLink(uri);
    } catch (error, stack) {
      _fail(ReaderFailure.link, error, stack);
    }
  }

  Future<String?> imageResource(String href) async {
    if (_closed || !ready) return null;
    try {
      return await _gateway.resource(href);
    } catch (error, stack) {
      _fail(ReaderFailure.image, error, stack);
      return null;
    }
  }

  void _record() {
    final current = locator;
    if (current == null || !ready || _closed) return;
    _progress.record(
      BookProgress.fromLocator(current.toJson(), fraction: fraction),
      isReady: true,
    );
  }

  Future<bool> flush() async {
    final saved = await _progress.flush();
    if (saved && !_closed && failure == ReaderFailure.progress) {
      failure = null;
      _notify();
    }
    return saved;
  }

  Future<bool> close() {
    if (_closing != null) return _closing!;
    _closed = true;
    ready = false;
    _layoutTimer?.cancel();
    _pendingLayout = null;
    if (_ready?.isCompleted == false) _ready!.complete();
    final task = _close();
    _closing = task;
    return task.then((saved) {
      if (!saved) _closing = null;
      return saved;
    });
  }

  Future<bool> _close() async {
    final saved = await _progress.close();
    await _work;
    try {
      await _unmount();
      if (_ownsPublication) {
        await _gateway.close();
        _ownsPublication = false;
      }
    } catch (error, stack) {
      appLogger.e('关闭阅读器失败', error: error, stackTrace: stack);
      return false;
    }
    return saved;
  }

  void _fail(ReaderFailure code, [Object? error, StackTrace? stack]) {
    if (error != null) {
      appLogger.e('阅读失败：${code.name}', error: error, stackTrace: stack);
    }
    if (_closed) return;
    failure = code;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(close());
    super.dispose();
  }
}
