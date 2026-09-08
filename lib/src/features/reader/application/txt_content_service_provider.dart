import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:synlen/src/features/library/application/book_queries.dart';
import 'package:synlen/src/features/library/domain/book_manifest.dart';

import '../data/services/txt_content_service.dart';
import '../data/services/txt_spine_source.dart';

part 'txt_content_service_provider.g.dart';

/// 用书目查询接口适配 TXT 章节供给的 spine 来源。
class BookQueriesTxtSpineSource implements TxtSpineSource {
  const BookQueriesTxtSpineSource(this._queries);

  final BookQueries _queries;

  @override
  Future<List<SpineItem>?> spineFor(String fileHash) async =>
      (await _queries.findManifest(fileHash))?.spine;
}

/// TXT 章节内容供给：按 manifest 中的字节范围随机读取并包装为 XHTML
@Riverpod(keepAlive: true)
TxtContentService txtContentService(Ref ref) {
  final service = TxtContentService(
    spineSource: BookQueriesTxtSpineSource(ref.watch(bookQueriesProvider)),
  );

  ref.onDispose(() {
    service.dispose();
  });

  return service;
}
