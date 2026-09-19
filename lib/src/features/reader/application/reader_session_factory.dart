import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../library/application/book_queries.dart';
import '../data/services/epub_stream_service_provider.dart';
import 'book_session.dart';
import 'book_webview_handler.dart';
import 'txt_content_service_provider.dart';
import 'reader_workflow.dart';
import 'reader_viewport.dart';

part 'reader_session_factory.g.dart';

/// 阅读会话的装配入口：data 层依赖的注入集中在这里，
/// presentation 只取装配好的会话与 WebView 处理器。
@riverpod
class ReaderSessionFactory extends _$ReaderSessionFactory {
  @override
  void build() {}

  /// 为 [fileHash] 创建一次阅读会话（书目 + 清单 + spine）。
  BookSession createSession(String fileHash) =>
      BookSession(fileHash: fileHash, queries: ref.read(bookQueriesProvider));

  /// 会话持有导航与进度资源，页面结束时调用 close。
  ReaderWorkflow createWorkflow(String fileHash, ReaderViewport viewport) =>
      ReaderWorkflow(book: createSession(fileHash), viewport: viewport);

  /// 创建阅读内容供给处理器（虚拟域拦截 + LRU 缓存）。
  BookWebViewHandler createWebViewHandler() => BookWebViewHandler(
    streamService: ref.read(epubStreamServiceProvider),
    txtContentService: ref.read(txtContentServiceProvider),
  );
}
