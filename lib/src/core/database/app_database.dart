import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:synlen/src/features/library/domain/book_format.dart';
import 'package:synlen/src/features/library/domain/book_manifest.dart';

part 'app_database.g.dart';

// ==================== 类型转换器 ====================

/// `BookFormat` ↔ 枚举名字符串（'epub' / 'txt'）；未知值回退 EPUB
class BookFormatConverter extends TypeConverter<BookFormat, String> {
  const BookFormatConverter();

  @override
  BookFormat fromSql(String fromDb) =>
      BookFormat.values.asNameMap()[fromDb] ?? BookFormat.epub;

  @override
  String toSql(BookFormat value) => value.name;
}

/// `List<String>` ↔ JSON 文本（如 authors、subjects）
class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) =>
      (jsonDecode(fromDb) as List).cast<String>();

  @override
  String toSql(List<String> value) => jsonEncode(value);
}

/// `List<SpineItem>` ↔ JSON 文本
class SpineListConverter extends TypeConverter<List<SpineItem>, String> {
  const SpineListConverter();

  @override
  List<SpineItem> fromSql(String fromDb) => (jsonDecode(fromDb) as List)
      .whereType<Map<String, dynamic>>()
      .map(SpineItem.fromJson)
      .toList();

  @override
  String toSql(List<SpineItem> value) =>
      jsonEncode(value.map((e) => e.toJson()).toList());
}

/// `List<TocItem>` ↔ JSON 文本
class TocListConverter extends TypeConverter<List<TocItem>, String> {
  const TocListConverter();

  @override
  List<TocItem> fromSql(String fromDb) => (jsonDecode(fromDb) as List)
      .whereType<Map<String, dynamic>>()
      .map(TocItem.fromJson)
      .toList();

  @override
  String toSql(List<TocItem> value) =>
      jsonEncode(value.map((e) => e.toJson()).toList());
}

/// `List<ManifestItem>` ↔ JSON 文本
class ManifestListConverter extends TypeConverter<List<ManifestItem>, String> {
  const ManifestListConverter();

  @override
  List<ManifestItem> fromSql(String fromDb) => (jsonDecode(fromDb) as List)
      .whereType<Map<String, dynamic>>()
      .map(ManifestItem.fromJson)
      .toList();

  @override
  String toSql(List<ManifestItem> value) =>
      jsonEncode(value.map((e) => e.toJson()).toList());
}

// ==================== 确定性 ID 哈希 ====================
// 学习缓存使用 FNV-1a 64 位哈希生成确定性主键，保证同一词条/句子的缓存键稳定。

int wordExplanationId(String word, String? context) =>
    _fastHash('$word|${context ?? ''}');

int wordPronunciationId(String word) => _fastHash(word);

int sentencePronunciationId(String sentence) => _fastHash(sentence);

int _fastHash(String string) {
  var hash = 0xcbf29ce484222325;

  var i = 0;
  while (i < string.length) {
    final codeUnit = string.codeUnitAt(i++);
    hash ^= codeUnit >> 8;
    hash *= 0x100000001b3;
    hash ^= codeUnit & 0xFF;
    hash *= 0x100000001b3;
  }

  return hash;
}

// ==================== 表定义 ====================

/// 书架分组（扁平结构，UUID 同步）
class ShelfGroups extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  IntColumn get creationDate => integer()();
  IntColumn get updatedAt => integer()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

/// 书架上的书（轻量元数据 + 阅读进度，EPUB 以压缩形式存盘）
@DataClassName('ShelfBook')
class ShelfBooks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get fileHash => text().unique()();
  TextColumn get filePath => text().nullable()();
  TextColumn get coverPath => text().nullable()();
  TextColumn get title => text()();
  TextColumn get author => text()();
  TextColumn get authors => text()
      .map(const StringListConverter())
      .withDefault(const Constant('[]'))();
  TextColumn get description => text().nullable()();
  TextColumn get subjects => text()
      .map(const StringListConverter())
      .withDefault(const Constant('[]'))();
  IntColumn get totalChapters => integer().withDefault(const Constant(0))();
  TextColumn get epubVersion => text().withDefault(const Constant(''))();

  /// 书籍格式（'epub' / 'txt'），v1 存量数据默认 EPUB
  TextColumn get format => text()
      .map(const BookFormatConverter())
      .withDefault(const Constant('epub'))();
  IntColumn get importDate => integer()();
  IntColumn get direction => integer().withDefault(const Constant(0))();
  IntColumn get currentChapterIndex =>
      integer().withDefault(const Constant(0))();
  RealColumn get readingProgress => real().withDefault(const Constant(0.0))();
  RealColumn get chapterScrollPosition =>
      real().nullable().withDefault(const Constant(0.0))();
  IntColumn get lastOpenedDate => integer().nullable()();
  BoolColumn get isFinished => boolean().withDefault(const Constant(false))();
  TextColumn get groupName => text().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  IntColumn get updatedAt => integer()();
  IntColumn get lastSyncedDate => integer().nullable()();
}

/// 阅读引擎使用的书籍结构（spine/TOC/manifest 存 JSON 文本）
///
/// EPUB 时 spine 指向包内条目路径；TXT 时 spine 指向虚拟章节路径
/// （`txt/chapter_N.xhtml`）并通过 [SpineItem.sourceRange] 记录字节范围。
@DataClassName('BookManifest')
class BookManifests extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get fileHash => text().unique()();
  TextColumn get opfRootPath => text()();
  TextColumn get spine => text().map(const SpineListConverter())();
  TextColumn get toc => text().map(const TocListConverter())();
  TextColumn get manifest => text().map(const ManifestListConverter())();
  TextColumn get epubVersion => text()();

  /// 书籍格式（'epub' / 'txt'），v1 存量数据默认 EPUB
  TextColumn get format => text()
      .map(const BookFormatConverter())
      .withDefault(const Constant('epub'))();
  DateTimeColumn get lastUpdated => dateTime()();
}

/// 单词解释缓存（id 为 word+context 的确定性哈希）
@DataClassName('WordExplanation')
class WordExplanations extends Table {
  IntColumn get id => integer()();
  TextColumn get word => text()();
  TextColumn get explanation => text()();
  DateTimeColumn get lastUpdated => dateTime()();
  TextColumn get context => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 单词发音缓存（id 为 word 的确定性哈希）
@DataClassName('WordPronunciation')
class WordPronunciations extends Table {
  IntColumn get id => integer()();
  TextColumn get word => text().unique()();
  TextColumn get audioUrl => text().nullable()();
  DateTimeColumn get lastUpdated => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 句子分析缓存
@DataClassName('SentenceAnalysis')
class SentenceAnalyses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sentence => text().unique()();
  TextColumn get analysis => text()();
  DateTimeColumn get lastUpdated => dateTime()();
}

/// 句子发音缓存（id 为 sentence 的确定性哈希）
@DataClassName('SentencePronunciation')
class SentencePronunciations extends Table {
  IntColumn get id => integer()();
  TextColumn get sentence => text().unique()();
  TextColumn get audioUrl => text().nullable()();
  DateTimeColumn get lastUpdated => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// ==================== 数据库 ====================

@DriftDatabase(
  tables: [
    ShelfGroups,
    ShelfBooks,
    BookManifests,
    WordExplanations,
    WordPronunciations,
    SentenceAnalyses,
    SentencePronunciations,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'synlen'));

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        // v2：ShelfBooks / BookManifests 增加 format 列（默认 'epub'）
        await migrator.addColumn(shelfBooks, shelfBooks.format);
        await migrator.addColumn(bookManifests, bookManifests.format);
      }
    },
  );
}
