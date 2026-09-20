import 'dart:async';

import 'package:flutter_readium/flutter_readium.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../library/application/book_queries.dart';
import 'readium_gateway.dart';
import 'readium_publication_source.dart';
import 'readium_session.dart';

/// 原生插件一次只拥有一本书；所有权仅在前一会话成功释放后转交。
class ReaderSessionFactory {
  ReaderSessionFactory({
    required this.prepare,
    required this.queries,
    required this.gateway,
  });
  final Future<PreparedReadiumPublication> Function(String) prepare;
  final BookQueries queries;
  final ReadiumGateway gateway;
  ReadiumSession? _owner;
  Future<void> _handover = Future.value();
  bool _disposed = false;

  ReadiumSession create(String fileHash) {
    late final ReadiumSession session;
    session = ReadiumSession(
      fileHash: fileHash,
      prepare: prepare,
      queries: queries,
      gateway: gateway,
      beforeOpen: () {
        final task = _handover.then((_) async {
          if (_disposed) throw StateError('阅读会话装配入口已关闭');
          if (identical(_owner, session)) return;
          final previous = _owner;
          if (previous != null && !await previous.close()) {
            throw StateError('上一阅读会话尚未完成保存或释放');
          }
          _owner = session;
        });
        // 失败会话仍持有所有权，下一请求必须重试释放；队列本身可以继续执行。
        _handover = task.then<void>(
          (_) {},
          onError: (Object _, StackTrace _) {},
        );
        return task;
      },
    );
    return session;
  }

  void dispose() {
    _disposed = true;
    unawaited(
      _handover.then((_) async {
        await _owner?.close();
      }),
    );
  }
}

final readerSessionFactoryProvider = Provider<ReaderSessionFactory>((ref) {
  final factory = ReaderSessionFactory(
    prepare: ref.watch(readiumPublicationSourceProvider).open,
    queries: ref.watch(bookQueriesProvider),
    gateway: NativeReadiumGateway(FlutterReadium()),
  );
  ref.onDispose(factory.dispose);
  return factory;
});
