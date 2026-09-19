import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'book_file_store.dart';

part 'book_file_store_provider.g.dart';

@riverpod
BookFileStore bookFileStore(Ref ref) => const BookFileStore();
