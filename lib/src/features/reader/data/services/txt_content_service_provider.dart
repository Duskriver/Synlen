import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:synlen/src/features/library/data/repositories/book_manifest_repository_provider.dart';
import 'txt_content_service.dart';

part 'txt_content_service_provider.g.dart';

/// Provider for TxtContentService
/// TXT 章节内容供给：按 manifest 中的字节范围随机读取并包装为 XHTML
@Riverpod(keepAlive: true)
TxtContentService txtContentService(Ref ref) {
  final service = TxtContentService(
    manifestRepo: ref.watch(bookManifestRepositoryProvider),
  );

  ref.onDispose(() {
    service.dispose();
  });

  return service;
}
