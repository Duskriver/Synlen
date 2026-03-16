import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:synlen/src/core/storage/app_storage.dart';
import '../../features/library/domain/shelf_book.dart';
import '../../features/library/domain/book_manifest.dart';
import '../../features/library/domain/shelf_group.dart';
import '../../features/learning/domain/word_explanation.dart';
import '../../features/learning/domain/word_pronunciation.dart';
import '../../features/learning/domain/sentence_analysis.dart';
import 'isar_database.dart';

/// Concrete implementation of IsarDatabase
/// Manages Isar database lifecycle and provides access to the instance
class IsarDatabaseImpl implements IsarDatabase {
  Isar? _instance;

  @override
  Future<Isar> getInstance() async {
    if (_instance != null) {
      return _instance!;
    }

    _instance = await Isar.open(
      [
        ShelfBookSchema, // Lightweight UI entity
        ShelfGroupSchema, // Folder/group entity
        BookManifestSchema, // Heavy reader entity
        WordExplanationSchema, // Word explanation cache
        WordPronunciationSchema, // Word audio cache
        SentenceAnalysisSchema, // Sentence analysis cache
      ],
      directory: AppStorage.supportPath,
      inspector: kDebugMode, // Isar Inspector for debug builds only
    );

    return _instance!;
  }

  @override
  Future<void> close() async {
    await _instance?.close();
    _instance = null;
  }
}

