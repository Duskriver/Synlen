// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ShelfGroupsTable extends ShelfGroups
    with TableInfo<$ShelfGroupsTable, ShelfGroup> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ShelfGroupsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _creationDateMeta = const VerificationMeta(
    'creationDate',
  );
  @override
  late final GeneratedColumn<int> creationDate = GeneratedColumn<int>(
    'creation_date',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    creationDate,
    updatedAt,
    isDeleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shelf_groups';
  @override
  VerificationContext validateIntegrity(
    Insertable<ShelfGroup> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('creation_date')) {
      context.handle(
        _creationDateMeta,
        creationDate.isAcceptableOrUnknown(
          data['creation_date']!,
          _creationDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_creationDateMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ShelfGroup map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ShelfGroup(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      creationDate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}creation_date'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
    );
  }

  @override
  $ShelfGroupsTable createAlias(String alias) {
    return $ShelfGroupsTable(attachedDatabase, alias);
  }
}

class ShelfGroup extends DataClass implements Insertable<ShelfGroup> {
  final int id;
  final String name;
  final int creationDate;
  final int updatedAt;
  final bool isDeleted;
  const ShelfGroup({
    required this.id,
    required this.name,
    required this.creationDate,
    required this.updatedAt,
    required this.isDeleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['creation_date'] = Variable<int>(creationDate);
    map['updated_at'] = Variable<int>(updatedAt);
    map['is_deleted'] = Variable<bool>(isDeleted);
    return map;
  }

  ShelfGroupsCompanion toCompanion(bool nullToAbsent) {
    return ShelfGroupsCompanion(
      id: Value(id),
      name: Value(name),
      creationDate: Value(creationDate),
      updatedAt: Value(updatedAt),
      isDeleted: Value(isDeleted),
    );
  }

  factory ShelfGroup.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ShelfGroup(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      creationDate: serializer.fromJson<int>(json['creationDate']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'creationDate': serializer.toJson<int>(creationDate),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'isDeleted': serializer.toJson<bool>(isDeleted),
    };
  }

  ShelfGroup copyWith({
    int? id,
    String? name,
    int? creationDate,
    int? updatedAt,
    bool? isDeleted,
  }) => ShelfGroup(
    id: id ?? this.id,
    name: name ?? this.name,
    creationDate: creationDate ?? this.creationDate,
    updatedAt: updatedAt ?? this.updatedAt,
    isDeleted: isDeleted ?? this.isDeleted,
  );
  ShelfGroup copyWithCompanion(ShelfGroupsCompanion data) {
    return ShelfGroup(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      creationDate: data.creationDate.present
          ? data.creationDate.value
          : this.creationDate,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ShelfGroup(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('creationDate: $creationDate, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, creationDate, updatedAt, isDeleted);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ShelfGroup &&
          other.id == this.id &&
          other.name == this.name &&
          other.creationDate == this.creationDate &&
          other.updatedAt == this.updatedAt &&
          other.isDeleted == this.isDeleted);
}

class ShelfGroupsCompanion extends UpdateCompanion<ShelfGroup> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> creationDate;
  final Value<int> updatedAt;
  final Value<bool> isDeleted;
  const ShelfGroupsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.creationDate = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
  });
  ShelfGroupsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required int creationDate,
    required int updatedAt,
    this.isDeleted = const Value.absent(),
  }) : name = Value(name),
       creationDate = Value(creationDate),
       updatedAt = Value(updatedAt);
  static Insertable<ShelfGroup> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? creationDate,
    Expression<int>? updatedAt,
    Expression<bool>? isDeleted,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (creationDate != null) 'creation_date': creationDate,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
    });
  }

  ShelfGroupsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int>? creationDate,
    Value<int>? updatedAt,
    Value<bool>? isDeleted,
  }) {
    return ShelfGroupsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      creationDate: creationDate ?? this.creationDate,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (creationDate.present) {
      map['creation_date'] = Variable<int>(creationDate.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ShelfGroupsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('creationDate: $creationDate, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }
}

class $ShelfBooksTable extends ShelfBooks
    with TableInfo<$ShelfBooksTable, ShelfBook> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ShelfBooksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _fileHashMeta = const VerificationMeta(
    'fileHash',
  );
  @override
  late final GeneratedColumn<String> fileHash = GeneratedColumn<String>(
    'file_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverPathMeta = const VerificationMeta(
    'coverPath',
  );
  @override
  late final GeneratedColumn<String> coverPath = GeneratedColumn<String>(
    'cover_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> authors =
      GeneratedColumn<String>(
        'authors',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      ).withConverter<List<String>>($ShelfBooksTable.$converterauthors);
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> subjects =
      GeneratedColumn<String>(
        'subjects',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      ).withConverter<List<String>>($ShelfBooksTable.$convertersubjects);
  static const VerificationMeta _totalChaptersMeta = const VerificationMeta(
    'totalChapters',
  );
  @override
  late final GeneratedColumn<int> totalChapters = GeneratedColumn<int>(
    'total_chapters',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _epubVersionMeta = const VerificationMeta(
    'epubVersion',
  );
  @override
  late final GeneratedColumn<String> epubVersion = GeneratedColumn<String>(
    'epub_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  late final GeneratedColumnWithTypeConverter<BookFormat, String> format =
      GeneratedColumn<String>(
        'format',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('epub'),
      ).withConverter<BookFormat>($ShelfBooksTable.$converterformat);
  static const VerificationMeta _importDateMeta = const VerificationMeta(
    'importDate',
  );
  @override
  late final GeneratedColumn<int> importDate = GeneratedColumn<int>(
    'import_date',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _directionMeta = const VerificationMeta(
    'direction',
  );
  @override
  late final GeneratedColumn<int> direction = GeneratedColumn<int>(
    'direction',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  late final GeneratedColumnWithTypeConverter<BookProgress?, String> progress =
      GeneratedColumn<String>(
        'progress',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<BookProgress?>($ShelfBooksTable.$converterprogressn);
  static const VerificationMeta _readingProgressMeta = const VerificationMeta(
    'readingProgress',
  );
  @override
  late final GeneratedColumn<double> readingProgress = GeneratedColumn<double>(
    'reading_progress',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _lastOpenedDateMeta = const VerificationMeta(
    'lastOpenedDate',
  );
  @override
  late final GeneratedColumn<int> lastOpenedDate = GeneratedColumn<int>(
    'last_opened_date',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isFinishedMeta = const VerificationMeta(
    'isFinished',
  );
  @override
  late final GeneratedColumn<bool> isFinished = GeneratedColumn<bool>(
    'is_finished',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_finished" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _groupNameMeta = const VerificationMeta(
    'groupName',
  );
  @override
  late final GeneratedColumn<String> groupName = GeneratedColumn<String>(
    'group_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSyncedDateMeta = const VerificationMeta(
    'lastSyncedDate',
  );
  @override
  late final GeneratedColumn<int> lastSyncedDate = GeneratedColumn<int>(
    'last_synced_date',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    fileHash,
    filePath,
    coverPath,
    title,
    author,
    authors,
    description,
    subjects,
    totalChapters,
    epubVersion,
    format,
    importDate,
    direction,
    progress,
    readingProgress,
    lastOpenedDate,
    isFinished,
    groupName,
    isDeleted,
    updatedAt,
    lastSyncedDate,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shelf_books';
  @override
  VerificationContext validateIntegrity(
    Insertable<ShelfBook> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('file_hash')) {
      context.handle(
        _fileHashMeta,
        fileHash.isAcceptableOrUnknown(data['file_hash']!, _fileHashMeta),
      );
    } else if (isInserting) {
      context.missing(_fileHashMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    }
    if (data.containsKey('cover_path')) {
      context.handle(
        _coverPathMeta,
        coverPath.isAcceptableOrUnknown(data['cover_path']!, _coverPathMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    } else if (isInserting) {
      context.missing(_authorMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('total_chapters')) {
      context.handle(
        _totalChaptersMeta,
        totalChapters.isAcceptableOrUnknown(
          data['total_chapters']!,
          _totalChaptersMeta,
        ),
      );
    }
    if (data.containsKey('epub_version')) {
      context.handle(
        _epubVersionMeta,
        epubVersion.isAcceptableOrUnknown(
          data['epub_version']!,
          _epubVersionMeta,
        ),
      );
    }
    if (data.containsKey('import_date')) {
      context.handle(
        _importDateMeta,
        importDate.isAcceptableOrUnknown(data['import_date']!, _importDateMeta),
      );
    } else if (isInserting) {
      context.missing(_importDateMeta);
    }
    if (data.containsKey('direction')) {
      context.handle(
        _directionMeta,
        direction.isAcceptableOrUnknown(data['direction']!, _directionMeta),
      );
    }
    if (data.containsKey('reading_progress')) {
      context.handle(
        _readingProgressMeta,
        readingProgress.isAcceptableOrUnknown(
          data['reading_progress']!,
          _readingProgressMeta,
        ),
      );
    }
    if (data.containsKey('last_opened_date')) {
      context.handle(
        _lastOpenedDateMeta,
        lastOpenedDate.isAcceptableOrUnknown(
          data['last_opened_date']!,
          _lastOpenedDateMeta,
        ),
      );
    }
    if (data.containsKey('is_finished')) {
      context.handle(
        _isFinishedMeta,
        isFinished.isAcceptableOrUnknown(data['is_finished']!, _isFinishedMeta),
      );
    }
    if (data.containsKey('group_name')) {
      context.handle(
        _groupNameMeta,
        groupName.isAcceptableOrUnknown(data['group_name']!, _groupNameMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('last_synced_date')) {
      context.handle(
        _lastSyncedDateMeta,
        lastSyncedDate.isAcceptableOrUnknown(
          data['last_synced_date']!,
          _lastSyncedDateMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ShelfBook map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ShelfBook(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      fileHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_hash'],
      )!,
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      ),
      coverPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_path'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      )!,
      authors: $ShelfBooksTable.$converterauthors.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}authors'],
        )!,
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      subjects: $ShelfBooksTable.$convertersubjects.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}subjects'],
        )!,
      ),
      totalChapters: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_chapters'],
      )!,
      epubVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}epub_version'],
      )!,
      format: $ShelfBooksTable.$converterformat.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}format'],
        )!,
      ),
      importDate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}import_date'],
      )!,
      direction: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}direction'],
      )!,
      progress: $ShelfBooksTable.$converterprogressn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}progress'],
        ),
      ),
      readingProgress: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}reading_progress'],
      )!,
      lastOpenedDate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_opened_date'],
      ),
      isFinished: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_finished'],
      )!,
      groupName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_name'],
      ),
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      lastSyncedDate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_synced_date'],
      ),
    );
  }

  @override
  $ShelfBooksTable createAlias(String alias) {
    return $ShelfBooksTable(attachedDatabase, alias);
  }

  static TypeConverter<List<String>, String> $converterauthors =
      const StringListConverter();
  static TypeConverter<List<String>, String> $convertersubjects =
      const StringListConverter();
  static TypeConverter<BookFormat, String> $converterformat =
      const BookFormatConverter();
  static TypeConverter<BookProgress, String> $converterprogress =
      const BookProgressConverter();
  static TypeConverter<BookProgress?, String?> $converterprogressn =
      NullAwareTypeConverter.wrap($converterprogress);
}

class ShelfBook extends DataClass implements Insertable<ShelfBook> {
  final int id;
  final String fileHash;
  final String? filePath;
  final String? coverPath;
  final String title;
  final String author;
  final List<String> authors;
  final String? description;
  final List<String> subjects;
  final int totalChapters;
  final String epubVersion;

  /// 书籍格式（'epub' / 'txt'），v1 存量数据默认 EPUB
  final BookFormat format;
  final int importDate;
  final int direction;
  final BookProgress? progress;
  final double readingProgress;
  final int? lastOpenedDate;
  final bool isFinished;
  final String? groupName;
  final bool isDeleted;
  final int updatedAt;
  final int? lastSyncedDate;
  const ShelfBook({
    required this.id,
    required this.fileHash,
    this.filePath,
    this.coverPath,
    required this.title,
    required this.author,
    required this.authors,
    this.description,
    required this.subjects,
    required this.totalChapters,
    required this.epubVersion,
    required this.format,
    required this.importDate,
    required this.direction,
    this.progress,
    required this.readingProgress,
    this.lastOpenedDate,
    required this.isFinished,
    this.groupName,
    required this.isDeleted,
    required this.updatedAt,
    this.lastSyncedDate,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['file_hash'] = Variable<String>(fileHash);
    if (!nullToAbsent || filePath != null) {
      map['file_path'] = Variable<String>(filePath);
    }
    if (!nullToAbsent || coverPath != null) {
      map['cover_path'] = Variable<String>(coverPath);
    }
    map['title'] = Variable<String>(title);
    map['author'] = Variable<String>(author);
    {
      map['authors'] = Variable<String>(
        $ShelfBooksTable.$converterauthors.toSql(authors),
      );
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    {
      map['subjects'] = Variable<String>(
        $ShelfBooksTable.$convertersubjects.toSql(subjects),
      );
    }
    map['total_chapters'] = Variable<int>(totalChapters);
    map['epub_version'] = Variable<String>(epubVersion);
    {
      map['format'] = Variable<String>(
        $ShelfBooksTable.$converterformat.toSql(format),
      );
    }
    map['import_date'] = Variable<int>(importDate);
    map['direction'] = Variable<int>(direction);
    if (!nullToAbsent || progress != null) {
      map['progress'] = Variable<String>(
        $ShelfBooksTable.$converterprogressn.toSql(progress),
      );
    }
    map['reading_progress'] = Variable<double>(readingProgress);
    if (!nullToAbsent || lastOpenedDate != null) {
      map['last_opened_date'] = Variable<int>(lastOpenedDate);
    }
    map['is_finished'] = Variable<bool>(isFinished);
    if (!nullToAbsent || groupName != null) {
      map['group_name'] = Variable<String>(groupName);
    }
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || lastSyncedDate != null) {
      map['last_synced_date'] = Variable<int>(lastSyncedDate);
    }
    return map;
  }

  ShelfBooksCompanion toCompanion(bool nullToAbsent) {
    return ShelfBooksCompanion(
      id: Value(id),
      fileHash: Value(fileHash),
      filePath: filePath == null && nullToAbsent
          ? const Value.absent()
          : Value(filePath),
      coverPath: coverPath == null && nullToAbsent
          ? const Value.absent()
          : Value(coverPath),
      title: Value(title),
      author: Value(author),
      authors: Value(authors),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      subjects: Value(subjects),
      totalChapters: Value(totalChapters),
      epubVersion: Value(epubVersion),
      format: Value(format),
      importDate: Value(importDate),
      direction: Value(direction),
      progress: progress == null && nullToAbsent
          ? const Value.absent()
          : Value(progress),
      readingProgress: Value(readingProgress),
      lastOpenedDate: lastOpenedDate == null && nullToAbsent
          ? const Value.absent()
          : Value(lastOpenedDate),
      isFinished: Value(isFinished),
      groupName: groupName == null && nullToAbsent
          ? const Value.absent()
          : Value(groupName),
      isDeleted: Value(isDeleted),
      updatedAt: Value(updatedAt),
      lastSyncedDate: lastSyncedDate == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedDate),
    );
  }

  factory ShelfBook.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ShelfBook(
      id: serializer.fromJson<int>(json['id']),
      fileHash: serializer.fromJson<String>(json['fileHash']),
      filePath: serializer.fromJson<String?>(json['filePath']),
      coverPath: serializer.fromJson<String?>(json['coverPath']),
      title: serializer.fromJson<String>(json['title']),
      author: serializer.fromJson<String>(json['author']),
      authors: serializer.fromJson<List<String>>(json['authors']),
      description: serializer.fromJson<String?>(json['description']),
      subjects: serializer.fromJson<List<String>>(json['subjects']),
      totalChapters: serializer.fromJson<int>(json['totalChapters']),
      epubVersion: serializer.fromJson<String>(json['epubVersion']),
      format: serializer.fromJson<BookFormat>(json['format']),
      importDate: serializer.fromJson<int>(json['importDate']),
      direction: serializer.fromJson<int>(json['direction']),
      progress: serializer.fromJson<BookProgress?>(json['progress']),
      readingProgress: serializer.fromJson<double>(json['readingProgress']),
      lastOpenedDate: serializer.fromJson<int?>(json['lastOpenedDate']),
      isFinished: serializer.fromJson<bool>(json['isFinished']),
      groupName: serializer.fromJson<String?>(json['groupName']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      lastSyncedDate: serializer.fromJson<int?>(json['lastSyncedDate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'fileHash': serializer.toJson<String>(fileHash),
      'filePath': serializer.toJson<String?>(filePath),
      'coverPath': serializer.toJson<String?>(coverPath),
      'title': serializer.toJson<String>(title),
      'author': serializer.toJson<String>(author),
      'authors': serializer.toJson<List<String>>(authors),
      'description': serializer.toJson<String?>(description),
      'subjects': serializer.toJson<List<String>>(subjects),
      'totalChapters': serializer.toJson<int>(totalChapters),
      'epubVersion': serializer.toJson<String>(epubVersion),
      'format': serializer.toJson<BookFormat>(format),
      'importDate': serializer.toJson<int>(importDate),
      'direction': serializer.toJson<int>(direction),
      'progress': serializer.toJson<BookProgress?>(progress),
      'readingProgress': serializer.toJson<double>(readingProgress),
      'lastOpenedDate': serializer.toJson<int?>(lastOpenedDate),
      'isFinished': serializer.toJson<bool>(isFinished),
      'groupName': serializer.toJson<String?>(groupName),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'lastSyncedDate': serializer.toJson<int?>(lastSyncedDate),
    };
  }

  ShelfBook copyWith({
    int? id,
    String? fileHash,
    Value<String?> filePath = const Value.absent(),
    Value<String?> coverPath = const Value.absent(),
    String? title,
    String? author,
    List<String>? authors,
    Value<String?> description = const Value.absent(),
    List<String>? subjects,
    int? totalChapters,
    String? epubVersion,
    BookFormat? format,
    int? importDate,
    int? direction,
    Value<BookProgress?> progress = const Value.absent(),
    double? readingProgress,
    Value<int?> lastOpenedDate = const Value.absent(),
    bool? isFinished,
    Value<String?> groupName = const Value.absent(),
    bool? isDeleted,
    int? updatedAt,
    Value<int?> lastSyncedDate = const Value.absent(),
  }) => ShelfBook(
    id: id ?? this.id,
    fileHash: fileHash ?? this.fileHash,
    filePath: filePath.present ? filePath.value : this.filePath,
    coverPath: coverPath.present ? coverPath.value : this.coverPath,
    title: title ?? this.title,
    author: author ?? this.author,
    authors: authors ?? this.authors,
    description: description.present ? description.value : this.description,
    subjects: subjects ?? this.subjects,
    totalChapters: totalChapters ?? this.totalChapters,
    epubVersion: epubVersion ?? this.epubVersion,
    format: format ?? this.format,
    importDate: importDate ?? this.importDate,
    direction: direction ?? this.direction,
    progress: progress.present ? progress.value : this.progress,
    readingProgress: readingProgress ?? this.readingProgress,
    lastOpenedDate: lastOpenedDate.present
        ? lastOpenedDate.value
        : this.lastOpenedDate,
    isFinished: isFinished ?? this.isFinished,
    groupName: groupName.present ? groupName.value : this.groupName,
    isDeleted: isDeleted ?? this.isDeleted,
    updatedAt: updatedAt ?? this.updatedAt,
    lastSyncedDate: lastSyncedDate.present
        ? lastSyncedDate.value
        : this.lastSyncedDate,
  );
  ShelfBook copyWithCompanion(ShelfBooksCompanion data) {
    return ShelfBook(
      id: data.id.present ? data.id.value : this.id,
      fileHash: data.fileHash.present ? data.fileHash.value : this.fileHash,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      coverPath: data.coverPath.present ? data.coverPath.value : this.coverPath,
      title: data.title.present ? data.title.value : this.title,
      author: data.author.present ? data.author.value : this.author,
      authors: data.authors.present ? data.authors.value : this.authors,
      description: data.description.present
          ? data.description.value
          : this.description,
      subjects: data.subjects.present ? data.subjects.value : this.subjects,
      totalChapters: data.totalChapters.present
          ? data.totalChapters.value
          : this.totalChapters,
      epubVersion: data.epubVersion.present
          ? data.epubVersion.value
          : this.epubVersion,
      format: data.format.present ? data.format.value : this.format,
      importDate: data.importDate.present
          ? data.importDate.value
          : this.importDate,
      direction: data.direction.present ? data.direction.value : this.direction,
      progress: data.progress.present ? data.progress.value : this.progress,
      readingProgress: data.readingProgress.present
          ? data.readingProgress.value
          : this.readingProgress,
      lastOpenedDate: data.lastOpenedDate.present
          ? data.lastOpenedDate.value
          : this.lastOpenedDate,
      isFinished: data.isFinished.present
          ? data.isFinished.value
          : this.isFinished,
      groupName: data.groupName.present ? data.groupName.value : this.groupName,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      lastSyncedDate: data.lastSyncedDate.present
          ? data.lastSyncedDate.value
          : this.lastSyncedDate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ShelfBook(')
          ..write('id: $id, ')
          ..write('fileHash: $fileHash, ')
          ..write('filePath: $filePath, ')
          ..write('coverPath: $coverPath, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('authors: $authors, ')
          ..write('description: $description, ')
          ..write('subjects: $subjects, ')
          ..write('totalChapters: $totalChapters, ')
          ..write('epubVersion: $epubVersion, ')
          ..write('format: $format, ')
          ..write('importDate: $importDate, ')
          ..write('direction: $direction, ')
          ..write('progress: $progress, ')
          ..write('readingProgress: $readingProgress, ')
          ..write('lastOpenedDate: $lastOpenedDate, ')
          ..write('isFinished: $isFinished, ')
          ..write('groupName: $groupName, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastSyncedDate: $lastSyncedDate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    fileHash,
    filePath,
    coverPath,
    title,
    author,
    authors,
    description,
    subjects,
    totalChapters,
    epubVersion,
    format,
    importDate,
    direction,
    progress,
    readingProgress,
    lastOpenedDate,
    isFinished,
    groupName,
    isDeleted,
    updatedAt,
    lastSyncedDate,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ShelfBook &&
          other.id == this.id &&
          other.fileHash == this.fileHash &&
          other.filePath == this.filePath &&
          other.coverPath == this.coverPath &&
          other.title == this.title &&
          other.author == this.author &&
          other.authors == this.authors &&
          other.description == this.description &&
          other.subjects == this.subjects &&
          other.totalChapters == this.totalChapters &&
          other.epubVersion == this.epubVersion &&
          other.format == this.format &&
          other.importDate == this.importDate &&
          other.direction == this.direction &&
          other.progress == this.progress &&
          other.readingProgress == this.readingProgress &&
          other.lastOpenedDate == this.lastOpenedDate &&
          other.isFinished == this.isFinished &&
          other.groupName == this.groupName &&
          other.isDeleted == this.isDeleted &&
          other.updatedAt == this.updatedAt &&
          other.lastSyncedDate == this.lastSyncedDate);
}

class ShelfBooksCompanion extends UpdateCompanion<ShelfBook> {
  final Value<int> id;
  final Value<String> fileHash;
  final Value<String?> filePath;
  final Value<String?> coverPath;
  final Value<String> title;
  final Value<String> author;
  final Value<List<String>> authors;
  final Value<String?> description;
  final Value<List<String>> subjects;
  final Value<int> totalChapters;
  final Value<String> epubVersion;
  final Value<BookFormat> format;
  final Value<int> importDate;
  final Value<int> direction;
  final Value<BookProgress?> progress;
  final Value<double> readingProgress;
  final Value<int?> lastOpenedDate;
  final Value<bool> isFinished;
  final Value<String?> groupName;
  final Value<bool> isDeleted;
  final Value<int> updatedAt;
  final Value<int?> lastSyncedDate;
  const ShelfBooksCompanion({
    this.id = const Value.absent(),
    this.fileHash = const Value.absent(),
    this.filePath = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.authors = const Value.absent(),
    this.description = const Value.absent(),
    this.subjects = const Value.absent(),
    this.totalChapters = const Value.absent(),
    this.epubVersion = const Value.absent(),
    this.format = const Value.absent(),
    this.importDate = const Value.absent(),
    this.direction = const Value.absent(),
    this.progress = const Value.absent(),
    this.readingProgress = const Value.absent(),
    this.lastOpenedDate = const Value.absent(),
    this.isFinished = const Value.absent(),
    this.groupName = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.lastSyncedDate = const Value.absent(),
  });
  ShelfBooksCompanion.insert({
    this.id = const Value.absent(),
    required String fileHash,
    this.filePath = const Value.absent(),
    this.coverPath = const Value.absent(),
    required String title,
    required String author,
    this.authors = const Value.absent(),
    this.description = const Value.absent(),
    this.subjects = const Value.absent(),
    this.totalChapters = const Value.absent(),
    this.epubVersion = const Value.absent(),
    this.format = const Value.absent(),
    required int importDate,
    this.direction = const Value.absent(),
    this.progress = const Value.absent(),
    this.readingProgress = const Value.absent(),
    this.lastOpenedDate = const Value.absent(),
    this.isFinished = const Value.absent(),
    this.groupName = const Value.absent(),
    this.isDeleted = const Value.absent(),
    required int updatedAt,
    this.lastSyncedDate = const Value.absent(),
  }) : fileHash = Value(fileHash),
       title = Value(title),
       author = Value(author),
       importDate = Value(importDate),
       updatedAt = Value(updatedAt);
  static Insertable<ShelfBook> custom({
    Expression<int>? id,
    Expression<String>? fileHash,
    Expression<String>? filePath,
    Expression<String>? coverPath,
    Expression<String>? title,
    Expression<String>? author,
    Expression<String>? authors,
    Expression<String>? description,
    Expression<String>? subjects,
    Expression<int>? totalChapters,
    Expression<String>? epubVersion,
    Expression<String>? format,
    Expression<int>? importDate,
    Expression<int>? direction,
    Expression<String>? progress,
    Expression<double>? readingProgress,
    Expression<int>? lastOpenedDate,
    Expression<bool>? isFinished,
    Expression<String>? groupName,
    Expression<bool>? isDeleted,
    Expression<int>? updatedAt,
    Expression<int>? lastSyncedDate,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (fileHash != null) 'file_hash': fileHash,
      if (filePath != null) 'file_path': filePath,
      if (coverPath != null) 'cover_path': coverPath,
      if (title != null) 'title': title,
      if (author != null) 'author': author,
      if (authors != null) 'authors': authors,
      if (description != null) 'description': description,
      if (subjects != null) 'subjects': subjects,
      if (totalChapters != null) 'total_chapters': totalChapters,
      if (epubVersion != null) 'epub_version': epubVersion,
      if (format != null) 'format': format,
      if (importDate != null) 'import_date': importDate,
      if (direction != null) 'direction': direction,
      if (progress != null) 'progress': progress,
      if (readingProgress != null) 'reading_progress': readingProgress,
      if (lastOpenedDate != null) 'last_opened_date': lastOpenedDate,
      if (isFinished != null) 'is_finished': isFinished,
      if (groupName != null) 'group_name': groupName,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (lastSyncedDate != null) 'last_synced_date': lastSyncedDate,
    });
  }

  ShelfBooksCompanion copyWith({
    Value<int>? id,
    Value<String>? fileHash,
    Value<String?>? filePath,
    Value<String?>? coverPath,
    Value<String>? title,
    Value<String>? author,
    Value<List<String>>? authors,
    Value<String?>? description,
    Value<List<String>>? subjects,
    Value<int>? totalChapters,
    Value<String>? epubVersion,
    Value<BookFormat>? format,
    Value<int>? importDate,
    Value<int>? direction,
    Value<BookProgress?>? progress,
    Value<double>? readingProgress,
    Value<int?>? lastOpenedDate,
    Value<bool>? isFinished,
    Value<String?>? groupName,
    Value<bool>? isDeleted,
    Value<int>? updatedAt,
    Value<int?>? lastSyncedDate,
  }) {
    return ShelfBooksCompanion(
      id: id ?? this.id,
      fileHash: fileHash ?? this.fileHash,
      filePath: filePath ?? this.filePath,
      coverPath: coverPath ?? this.coverPath,
      title: title ?? this.title,
      author: author ?? this.author,
      authors: authors ?? this.authors,
      description: description ?? this.description,
      subjects: subjects ?? this.subjects,
      totalChapters: totalChapters ?? this.totalChapters,
      epubVersion: epubVersion ?? this.epubVersion,
      format: format ?? this.format,
      importDate: importDate ?? this.importDate,
      direction: direction ?? this.direction,
      progress: progress ?? this.progress,
      readingProgress: readingProgress ?? this.readingProgress,
      lastOpenedDate: lastOpenedDate ?? this.lastOpenedDate,
      isFinished: isFinished ?? this.isFinished,
      groupName: groupName ?? this.groupName,
      isDeleted: isDeleted ?? this.isDeleted,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSyncedDate: lastSyncedDate ?? this.lastSyncedDate,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (fileHash.present) {
      map['file_hash'] = Variable<String>(fileHash.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (coverPath.present) {
      map['cover_path'] = Variable<String>(coverPath.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (authors.present) {
      map['authors'] = Variable<String>(
        $ShelfBooksTable.$converterauthors.toSql(authors.value),
      );
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (subjects.present) {
      map['subjects'] = Variable<String>(
        $ShelfBooksTable.$convertersubjects.toSql(subjects.value),
      );
    }
    if (totalChapters.present) {
      map['total_chapters'] = Variable<int>(totalChapters.value);
    }
    if (epubVersion.present) {
      map['epub_version'] = Variable<String>(epubVersion.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(
        $ShelfBooksTable.$converterformat.toSql(format.value),
      );
    }
    if (importDate.present) {
      map['import_date'] = Variable<int>(importDate.value);
    }
    if (direction.present) {
      map['direction'] = Variable<int>(direction.value);
    }
    if (progress.present) {
      map['progress'] = Variable<String>(
        $ShelfBooksTable.$converterprogressn.toSql(progress.value),
      );
    }
    if (readingProgress.present) {
      map['reading_progress'] = Variable<double>(readingProgress.value);
    }
    if (lastOpenedDate.present) {
      map['last_opened_date'] = Variable<int>(lastOpenedDate.value);
    }
    if (isFinished.present) {
      map['is_finished'] = Variable<bool>(isFinished.value);
    }
    if (groupName.present) {
      map['group_name'] = Variable<String>(groupName.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (lastSyncedDate.present) {
      map['last_synced_date'] = Variable<int>(lastSyncedDate.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ShelfBooksCompanion(')
          ..write('id: $id, ')
          ..write('fileHash: $fileHash, ')
          ..write('filePath: $filePath, ')
          ..write('coverPath: $coverPath, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('authors: $authors, ')
          ..write('description: $description, ')
          ..write('subjects: $subjects, ')
          ..write('totalChapters: $totalChapters, ')
          ..write('epubVersion: $epubVersion, ')
          ..write('format: $format, ')
          ..write('importDate: $importDate, ')
          ..write('direction: $direction, ')
          ..write('progress: $progress, ')
          ..write('readingProgress: $readingProgress, ')
          ..write('lastOpenedDate: $lastOpenedDate, ')
          ..write('isFinished: $isFinished, ')
          ..write('groupName: $groupName, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastSyncedDate: $lastSyncedDate')
          ..write(')'))
        .toString();
  }
}

class $BookManifestsTable extends BookManifests
    with TableInfo<$BookManifestsTable, BookManifest> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookManifestsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _fileHashMeta = const VerificationMeta(
    'fileHash',
  );
  @override
  late final GeneratedColumn<String> fileHash = GeneratedColumn<String>(
    'file_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _opfRootPathMeta = const VerificationMeta(
    'opfRootPath',
  );
  @override
  late final GeneratedColumn<String> opfRootPath = GeneratedColumn<String>(
    'opf_root_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<SpineItem>, String> spine =
      GeneratedColumn<String>(
        'spine',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<List<SpineItem>>($BookManifestsTable.$converterspine);
  @override
  late final GeneratedColumnWithTypeConverter<List<TocItem>, String> toc =
      GeneratedColumn<String>(
        'toc',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<List<TocItem>>($BookManifestsTable.$convertertoc);
  @override
  late final GeneratedColumnWithTypeConverter<List<ManifestItem>, String>
  manifest = GeneratedColumn<String>(
    'manifest',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<List<ManifestItem>>($BookManifestsTable.$convertermanifest);
  static const VerificationMeta _epubVersionMeta = const VerificationMeta(
    'epubVersion',
  );
  @override
  late final GeneratedColumn<String> epubVersion = GeneratedColumn<String>(
    'epub_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<BookFormat, String> format =
      GeneratedColumn<String>(
        'format',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('epub'),
      ).withConverter<BookFormat>($BookManifestsTable.$converterformat);
  static const VerificationMeta _lastUpdatedMeta = const VerificationMeta(
    'lastUpdated',
  );
  @override
  late final GeneratedColumn<DateTime> lastUpdated = GeneratedColumn<DateTime>(
    'last_updated',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    fileHash,
    opfRootPath,
    spine,
    toc,
    manifest,
    epubVersion,
    format,
    lastUpdated,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'book_manifests';
  @override
  VerificationContext validateIntegrity(
    Insertable<BookManifest> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('file_hash')) {
      context.handle(
        _fileHashMeta,
        fileHash.isAcceptableOrUnknown(data['file_hash']!, _fileHashMeta),
      );
    } else if (isInserting) {
      context.missing(_fileHashMeta);
    }
    if (data.containsKey('opf_root_path')) {
      context.handle(
        _opfRootPathMeta,
        opfRootPath.isAcceptableOrUnknown(
          data['opf_root_path']!,
          _opfRootPathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_opfRootPathMeta);
    }
    if (data.containsKey('epub_version')) {
      context.handle(
        _epubVersionMeta,
        epubVersion.isAcceptableOrUnknown(
          data['epub_version']!,
          _epubVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_epubVersionMeta);
    }
    if (data.containsKey('last_updated')) {
      context.handle(
        _lastUpdatedMeta,
        lastUpdated.isAcceptableOrUnknown(
          data['last_updated']!,
          _lastUpdatedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastUpdatedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BookManifest map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookManifest(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      fileHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_hash'],
      )!,
      opfRootPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}opf_root_path'],
      )!,
      spine: $BookManifestsTable.$converterspine.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}spine'],
        )!,
      ),
      toc: $BookManifestsTable.$convertertoc.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}toc'],
        )!,
      ),
      manifest: $BookManifestsTable.$convertermanifest.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}manifest'],
        )!,
      ),
      epubVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}epub_version'],
      )!,
      format: $BookManifestsTable.$converterformat.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}format'],
        )!,
      ),
      lastUpdated: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_updated'],
      )!,
    );
  }

  @override
  $BookManifestsTable createAlias(String alias) {
    return $BookManifestsTable(attachedDatabase, alias);
  }

  static TypeConverter<List<SpineItem>, String> $converterspine =
      const SpineListConverter();
  static TypeConverter<List<TocItem>, String> $convertertoc =
      const TocListConverter();
  static TypeConverter<List<ManifestItem>, String> $convertermanifest =
      const ManifestListConverter();
  static TypeConverter<BookFormat, String> $converterformat =
      const BookFormatConverter();
}

class BookManifest extends DataClass implements Insertable<BookManifest> {
  final int id;
  final String fileHash;
  final String opfRootPath;
  final List<SpineItem> spine;
  final List<TocItem> toc;
  final List<ManifestItem> manifest;
  final String epubVersion;

  /// 书籍格式（'epub' / 'txt'），v1 存量数据默认 EPUB
  final BookFormat format;
  final DateTime lastUpdated;
  const BookManifest({
    required this.id,
    required this.fileHash,
    required this.opfRootPath,
    required this.spine,
    required this.toc,
    required this.manifest,
    required this.epubVersion,
    required this.format,
    required this.lastUpdated,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['file_hash'] = Variable<String>(fileHash);
    map['opf_root_path'] = Variable<String>(opfRootPath);
    {
      map['spine'] = Variable<String>(
        $BookManifestsTable.$converterspine.toSql(spine),
      );
    }
    {
      map['toc'] = Variable<String>(
        $BookManifestsTable.$convertertoc.toSql(toc),
      );
    }
    {
      map['manifest'] = Variable<String>(
        $BookManifestsTable.$convertermanifest.toSql(manifest),
      );
    }
    map['epub_version'] = Variable<String>(epubVersion);
    {
      map['format'] = Variable<String>(
        $BookManifestsTable.$converterformat.toSql(format),
      );
    }
    map['last_updated'] = Variable<DateTime>(lastUpdated);
    return map;
  }

  BookManifestsCompanion toCompanion(bool nullToAbsent) {
    return BookManifestsCompanion(
      id: Value(id),
      fileHash: Value(fileHash),
      opfRootPath: Value(opfRootPath),
      spine: Value(spine),
      toc: Value(toc),
      manifest: Value(manifest),
      epubVersion: Value(epubVersion),
      format: Value(format),
      lastUpdated: Value(lastUpdated),
    );
  }

  factory BookManifest.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookManifest(
      id: serializer.fromJson<int>(json['id']),
      fileHash: serializer.fromJson<String>(json['fileHash']),
      opfRootPath: serializer.fromJson<String>(json['opfRootPath']),
      spine: serializer.fromJson<List<SpineItem>>(json['spine']),
      toc: serializer.fromJson<List<TocItem>>(json['toc']),
      manifest: serializer.fromJson<List<ManifestItem>>(json['manifest']),
      epubVersion: serializer.fromJson<String>(json['epubVersion']),
      format: serializer.fromJson<BookFormat>(json['format']),
      lastUpdated: serializer.fromJson<DateTime>(json['lastUpdated']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'fileHash': serializer.toJson<String>(fileHash),
      'opfRootPath': serializer.toJson<String>(opfRootPath),
      'spine': serializer.toJson<List<SpineItem>>(spine),
      'toc': serializer.toJson<List<TocItem>>(toc),
      'manifest': serializer.toJson<List<ManifestItem>>(manifest),
      'epubVersion': serializer.toJson<String>(epubVersion),
      'format': serializer.toJson<BookFormat>(format),
      'lastUpdated': serializer.toJson<DateTime>(lastUpdated),
    };
  }

  BookManifest copyWith({
    int? id,
    String? fileHash,
    String? opfRootPath,
    List<SpineItem>? spine,
    List<TocItem>? toc,
    List<ManifestItem>? manifest,
    String? epubVersion,
    BookFormat? format,
    DateTime? lastUpdated,
  }) => BookManifest(
    id: id ?? this.id,
    fileHash: fileHash ?? this.fileHash,
    opfRootPath: opfRootPath ?? this.opfRootPath,
    spine: spine ?? this.spine,
    toc: toc ?? this.toc,
    manifest: manifest ?? this.manifest,
    epubVersion: epubVersion ?? this.epubVersion,
    format: format ?? this.format,
    lastUpdated: lastUpdated ?? this.lastUpdated,
  );
  BookManifest copyWithCompanion(BookManifestsCompanion data) {
    return BookManifest(
      id: data.id.present ? data.id.value : this.id,
      fileHash: data.fileHash.present ? data.fileHash.value : this.fileHash,
      opfRootPath: data.opfRootPath.present
          ? data.opfRootPath.value
          : this.opfRootPath,
      spine: data.spine.present ? data.spine.value : this.spine,
      toc: data.toc.present ? data.toc.value : this.toc,
      manifest: data.manifest.present ? data.manifest.value : this.manifest,
      epubVersion: data.epubVersion.present
          ? data.epubVersion.value
          : this.epubVersion,
      format: data.format.present ? data.format.value : this.format,
      lastUpdated: data.lastUpdated.present
          ? data.lastUpdated.value
          : this.lastUpdated,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookManifest(')
          ..write('id: $id, ')
          ..write('fileHash: $fileHash, ')
          ..write('opfRootPath: $opfRootPath, ')
          ..write('spine: $spine, ')
          ..write('toc: $toc, ')
          ..write('manifest: $manifest, ')
          ..write('epubVersion: $epubVersion, ')
          ..write('format: $format, ')
          ..write('lastUpdated: $lastUpdated')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    fileHash,
    opfRootPath,
    spine,
    toc,
    manifest,
    epubVersion,
    format,
    lastUpdated,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookManifest &&
          other.id == this.id &&
          other.fileHash == this.fileHash &&
          other.opfRootPath == this.opfRootPath &&
          other.spine == this.spine &&
          other.toc == this.toc &&
          other.manifest == this.manifest &&
          other.epubVersion == this.epubVersion &&
          other.format == this.format &&
          other.lastUpdated == this.lastUpdated);
}

class BookManifestsCompanion extends UpdateCompanion<BookManifest> {
  final Value<int> id;
  final Value<String> fileHash;
  final Value<String> opfRootPath;
  final Value<List<SpineItem>> spine;
  final Value<List<TocItem>> toc;
  final Value<List<ManifestItem>> manifest;
  final Value<String> epubVersion;
  final Value<BookFormat> format;
  final Value<DateTime> lastUpdated;
  const BookManifestsCompanion({
    this.id = const Value.absent(),
    this.fileHash = const Value.absent(),
    this.opfRootPath = const Value.absent(),
    this.spine = const Value.absent(),
    this.toc = const Value.absent(),
    this.manifest = const Value.absent(),
    this.epubVersion = const Value.absent(),
    this.format = const Value.absent(),
    this.lastUpdated = const Value.absent(),
  });
  BookManifestsCompanion.insert({
    this.id = const Value.absent(),
    required String fileHash,
    required String opfRootPath,
    required List<SpineItem> spine,
    required List<TocItem> toc,
    required List<ManifestItem> manifest,
    required String epubVersion,
    this.format = const Value.absent(),
    required DateTime lastUpdated,
  }) : fileHash = Value(fileHash),
       opfRootPath = Value(opfRootPath),
       spine = Value(spine),
       toc = Value(toc),
       manifest = Value(manifest),
       epubVersion = Value(epubVersion),
       lastUpdated = Value(lastUpdated);
  static Insertable<BookManifest> custom({
    Expression<int>? id,
    Expression<String>? fileHash,
    Expression<String>? opfRootPath,
    Expression<String>? spine,
    Expression<String>? toc,
    Expression<String>? manifest,
    Expression<String>? epubVersion,
    Expression<String>? format,
    Expression<DateTime>? lastUpdated,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (fileHash != null) 'file_hash': fileHash,
      if (opfRootPath != null) 'opf_root_path': opfRootPath,
      if (spine != null) 'spine': spine,
      if (toc != null) 'toc': toc,
      if (manifest != null) 'manifest': manifest,
      if (epubVersion != null) 'epub_version': epubVersion,
      if (format != null) 'format': format,
      if (lastUpdated != null) 'last_updated': lastUpdated,
    });
  }

  BookManifestsCompanion copyWith({
    Value<int>? id,
    Value<String>? fileHash,
    Value<String>? opfRootPath,
    Value<List<SpineItem>>? spine,
    Value<List<TocItem>>? toc,
    Value<List<ManifestItem>>? manifest,
    Value<String>? epubVersion,
    Value<BookFormat>? format,
    Value<DateTime>? lastUpdated,
  }) {
    return BookManifestsCompanion(
      id: id ?? this.id,
      fileHash: fileHash ?? this.fileHash,
      opfRootPath: opfRootPath ?? this.opfRootPath,
      spine: spine ?? this.spine,
      toc: toc ?? this.toc,
      manifest: manifest ?? this.manifest,
      epubVersion: epubVersion ?? this.epubVersion,
      format: format ?? this.format,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (fileHash.present) {
      map['file_hash'] = Variable<String>(fileHash.value);
    }
    if (opfRootPath.present) {
      map['opf_root_path'] = Variable<String>(opfRootPath.value);
    }
    if (spine.present) {
      map['spine'] = Variable<String>(
        $BookManifestsTable.$converterspine.toSql(spine.value),
      );
    }
    if (toc.present) {
      map['toc'] = Variable<String>(
        $BookManifestsTable.$convertertoc.toSql(toc.value),
      );
    }
    if (manifest.present) {
      map['manifest'] = Variable<String>(
        $BookManifestsTable.$convertermanifest.toSql(manifest.value),
      );
    }
    if (epubVersion.present) {
      map['epub_version'] = Variable<String>(epubVersion.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(
        $BookManifestsTable.$converterformat.toSql(format.value),
      );
    }
    if (lastUpdated.present) {
      map['last_updated'] = Variable<DateTime>(lastUpdated.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookManifestsCompanion(')
          ..write('id: $id, ')
          ..write('fileHash: $fileHash, ')
          ..write('opfRootPath: $opfRootPath, ')
          ..write('spine: $spine, ')
          ..write('toc: $toc, ')
          ..write('manifest: $manifest, ')
          ..write('epubVersion: $epubVersion, ')
          ..write('format: $format, ')
          ..write('lastUpdated: $lastUpdated')
          ..write(')'))
        .toString();
  }
}

class $WordExplanationsTable extends WordExplanations
    with TableInfo<$WordExplanationsTable, WordExplanation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WordExplanationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _wordMeta = const VerificationMeta('word');
  @override
  late final GeneratedColumn<String> word = GeneratedColumn<String>(
    'word',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _explanationMeta = const VerificationMeta(
    'explanation',
  );
  @override
  late final GeneratedColumn<String> explanation = GeneratedColumn<String>(
    'explanation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastUpdatedMeta = const VerificationMeta(
    'lastUpdated',
  );
  @override
  late final GeneratedColumn<DateTime> lastUpdated = GeneratedColumn<DateTime>(
    'last_updated',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contextMeta = const VerificationMeta(
    'context',
  );
  @override
  late final GeneratedColumn<String> context = GeneratedColumn<String>(
    'context',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    word,
    explanation,
    lastUpdated,
    context,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'word_explanations';
  @override
  VerificationContext validateIntegrity(
    Insertable<WordExplanation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('word')) {
      context.handle(
        _wordMeta,
        word.isAcceptableOrUnknown(data['word']!, _wordMeta),
      );
    } else if (isInserting) {
      context.missing(_wordMeta);
    }
    if (data.containsKey('explanation')) {
      context.handle(
        _explanationMeta,
        explanation.isAcceptableOrUnknown(
          data['explanation']!,
          _explanationMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_explanationMeta);
    }
    if (data.containsKey('last_updated')) {
      context.handle(
        _lastUpdatedMeta,
        lastUpdated.isAcceptableOrUnknown(
          data['last_updated']!,
          _lastUpdatedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastUpdatedMeta);
    }
    if (data.containsKey('context')) {
      context.handle(
        _contextMeta,
        this.context.isAcceptableOrUnknown(data['context']!, _contextMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WordExplanation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WordExplanation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      word: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}word'],
      )!,
      explanation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}explanation'],
      )!,
      lastUpdated: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_updated'],
      )!,
      context: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}context'],
      ),
    );
  }

  @override
  $WordExplanationsTable createAlias(String alias) {
    return $WordExplanationsTable(attachedDatabase, alias);
  }
}

class WordExplanation extends DataClass implements Insertable<WordExplanation> {
  final int id;
  final String word;
  final String explanation;
  final DateTime lastUpdated;
  final String? context;
  const WordExplanation({
    required this.id,
    required this.word,
    required this.explanation,
    required this.lastUpdated,
    this.context,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['word'] = Variable<String>(word);
    map['explanation'] = Variable<String>(explanation);
    map['last_updated'] = Variable<DateTime>(lastUpdated);
    if (!nullToAbsent || context != null) {
      map['context'] = Variable<String>(context);
    }
    return map;
  }

  WordExplanationsCompanion toCompanion(bool nullToAbsent) {
    return WordExplanationsCompanion(
      id: Value(id),
      word: Value(word),
      explanation: Value(explanation),
      lastUpdated: Value(lastUpdated),
      context: context == null && nullToAbsent
          ? const Value.absent()
          : Value(context),
    );
  }

  factory WordExplanation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WordExplanation(
      id: serializer.fromJson<int>(json['id']),
      word: serializer.fromJson<String>(json['word']),
      explanation: serializer.fromJson<String>(json['explanation']),
      lastUpdated: serializer.fromJson<DateTime>(json['lastUpdated']),
      context: serializer.fromJson<String?>(json['context']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'word': serializer.toJson<String>(word),
      'explanation': serializer.toJson<String>(explanation),
      'lastUpdated': serializer.toJson<DateTime>(lastUpdated),
      'context': serializer.toJson<String?>(context),
    };
  }

  WordExplanation copyWith({
    int? id,
    String? word,
    String? explanation,
    DateTime? lastUpdated,
    Value<String?> context = const Value.absent(),
  }) => WordExplanation(
    id: id ?? this.id,
    word: word ?? this.word,
    explanation: explanation ?? this.explanation,
    lastUpdated: lastUpdated ?? this.lastUpdated,
    context: context.present ? context.value : this.context,
  );
  WordExplanation copyWithCompanion(WordExplanationsCompanion data) {
    return WordExplanation(
      id: data.id.present ? data.id.value : this.id,
      word: data.word.present ? data.word.value : this.word,
      explanation: data.explanation.present
          ? data.explanation.value
          : this.explanation,
      lastUpdated: data.lastUpdated.present
          ? data.lastUpdated.value
          : this.lastUpdated,
      context: data.context.present ? data.context.value : this.context,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WordExplanation(')
          ..write('id: $id, ')
          ..write('word: $word, ')
          ..write('explanation: $explanation, ')
          ..write('lastUpdated: $lastUpdated, ')
          ..write('context: $context')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, word, explanation, lastUpdated, context);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WordExplanation &&
          other.id == this.id &&
          other.word == this.word &&
          other.explanation == this.explanation &&
          other.lastUpdated == this.lastUpdated &&
          other.context == this.context);
}

class WordExplanationsCompanion extends UpdateCompanion<WordExplanation> {
  final Value<int> id;
  final Value<String> word;
  final Value<String> explanation;
  final Value<DateTime> lastUpdated;
  final Value<String?> context;
  const WordExplanationsCompanion({
    this.id = const Value.absent(),
    this.word = const Value.absent(),
    this.explanation = const Value.absent(),
    this.lastUpdated = const Value.absent(),
    this.context = const Value.absent(),
  });
  WordExplanationsCompanion.insert({
    this.id = const Value.absent(),
    required String word,
    required String explanation,
    required DateTime lastUpdated,
    this.context = const Value.absent(),
  }) : word = Value(word),
       explanation = Value(explanation),
       lastUpdated = Value(lastUpdated);
  static Insertable<WordExplanation> custom({
    Expression<int>? id,
    Expression<String>? word,
    Expression<String>? explanation,
    Expression<DateTime>? lastUpdated,
    Expression<String>? context,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (word != null) 'word': word,
      if (explanation != null) 'explanation': explanation,
      if (lastUpdated != null) 'last_updated': lastUpdated,
      if (context != null) 'context': context,
    });
  }

  WordExplanationsCompanion copyWith({
    Value<int>? id,
    Value<String>? word,
    Value<String>? explanation,
    Value<DateTime>? lastUpdated,
    Value<String?>? context,
  }) {
    return WordExplanationsCompanion(
      id: id ?? this.id,
      word: word ?? this.word,
      explanation: explanation ?? this.explanation,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      context: context ?? this.context,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (word.present) {
      map['word'] = Variable<String>(word.value);
    }
    if (explanation.present) {
      map['explanation'] = Variable<String>(explanation.value);
    }
    if (lastUpdated.present) {
      map['last_updated'] = Variable<DateTime>(lastUpdated.value);
    }
    if (context.present) {
      map['context'] = Variable<String>(context.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WordExplanationsCompanion(')
          ..write('id: $id, ')
          ..write('word: $word, ')
          ..write('explanation: $explanation, ')
          ..write('lastUpdated: $lastUpdated, ')
          ..write('context: $context')
          ..write(')'))
        .toString();
  }
}

class $WordPronunciationsTable extends WordPronunciations
    with TableInfo<$WordPronunciationsTable, WordPronunciation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WordPronunciationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _wordMeta = const VerificationMeta('word');
  @override
  late final GeneratedColumn<String> word = GeneratedColumn<String>(
    'word',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _audioUrlMeta = const VerificationMeta(
    'audioUrl',
  );
  @override
  late final GeneratedColumn<String> audioUrl = GeneratedColumn<String>(
    'audio_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastUpdatedMeta = const VerificationMeta(
    'lastUpdated',
  );
  @override
  late final GeneratedColumn<DateTime> lastUpdated = GeneratedColumn<DateTime>(
    'last_updated',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, word, audioUrl, lastUpdated];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'word_pronunciations';
  @override
  VerificationContext validateIntegrity(
    Insertable<WordPronunciation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('word')) {
      context.handle(
        _wordMeta,
        word.isAcceptableOrUnknown(data['word']!, _wordMeta),
      );
    } else if (isInserting) {
      context.missing(_wordMeta);
    }
    if (data.containsKey('audio_url')) {
      context.handle(
        _audioUrlMeta,
        audioUrl.isAcceptableOrUnknown(data['audio_url']!, _audioUrlMeta),
      );
    }
    if (data.containsKey('last_updated')) {
      context.handle(
        _lastUpdatedMeta,
        lastUpdated.isAcceptableOrUnknown(
          data['last_updated']!,
          _lastUpdatedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastUpdatedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WordPronunciation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WordPronunciation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      word: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}word'],
      )!,
      audioUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_url'],
      ),
      lastUpdated: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_updated'],
      )!,
    );
  }

  @override
  $WordPronunciationsTable createAlias(String alias) {
    return $WordPronunciationsTable(attachedDatabase, alias);
  }
}

class WordPronunciation extends DataClass
    implements Insertable<WordPronunciation> {
  final int id;
  final String word;
  final String? audioUrl;
  final DateTime lastUpdated;
  const WordPronunciation({
    required this.id,
    required this.word,
    this.audioUrl,
    required this.lastUpdated,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['word'] = Variable<String>(word);
    if (!nullToAbsent || audioUrl != null) {
      map['audio_url'] = Variable<String>(audioUrl);
    }
    map['last_updated'] = Variable<DateTime>(lastUpdated);
    return map;
  }

  WordPronunciationsCompanion toCompanion(bool nullToAbsent) {
    return WordPronunciationsCompanion(
      id: Value(id),
      word: Value(word),
      audioUrl: audioUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(audioUrl),
      lastUpdated: Value(lastUpdated),
    );
  }

  factory WordPronunciation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WordPronunciation(
      id: serializer.fromJson<int>(json['id']),
      word: serializer.fromJson<String>(json['word']),
      audioUrl: serializer.fromJson<String?>(json['audioUrl']),
      lastUpdated: serializer.fromJson<DateTime>(json['lastUpdated']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'word': serializer.toJson<String>(word),
      'audioUrl': serializer.toJson<String?>(audioUrl),
      'lastUpdated': serializer.toJson<DateTime>(lastUpdated),
    };
  }

  WordPronunciation copyWith({
    int? id,
    String? word,
    Value<String?> audioUrl = const Value.absent(),
    DateTime? lastUpdated,
  }) => WordPronunciation(
    id: id ?? this.id,
    word: word ?? this.word,
    audioUrl: audioUrl.present ? audioUrl.value : this.audioUrl,
    lastUpdated: lastUpdated ?? this.lastUpdated,
  );
  WordPronunciation copyWithCompanion(WordPronunciationsCompanion data) {
    return WordPronunciation(
      id: data.id.present ? data.id.value : this.id,
      word: data.word.present ? data.word.value : this.word,
      audioUrl: data.audioUrl.present ? data.audioUrl.value : this.audioUrl,
      lastUpdated: data.lastUpdated.present
          ? data.lastUpdated.value
          : this.lastUpdated,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WordPronunciation(')
          ..write('id: $id, ')
          ..write('word: $word, ')
          ..write('audioUrl: $audioUrl, ')
          ..write('lastUpdated: $lastUpdated')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, word, audioUrl, lastUpdated);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WordPronunciation &&
          other.id == this.id &&
          other.word == this.word &&
          other.audioUrl == this.audioUrl &&
          other.lastUpdated == this.lastUpdated);
}

class WordPronunciationsCompanion extends UpdateCompanion<WordPronunciation> {
  final Value<int> id;
  final Value<String> word;
  final Value<String?> audioUrl;
  final Value<DateTime> lastUpdated;
  const WordPronunciationsCompanion({
    this.id = const Value.absent(),
    this.word = const Value.absent(),
    this.audioUrl = const Value.absent(),
    this.lastUpdated = const Value.absent(),
  });
  WordPronunciationsCompanion.insert({
    this.id = const Value.absent(),
    required String word,
    this.audioUrl = const Value.absent(),
    required DateTime lastUpdated,
  }) : word = Value(word),
       lastUpdated = Value(lastUpdated);
  static Insertable<WordPronunciation> custom({
    Expression<int>? id,
    Expression<String>? word,
    Expression<String>? audioUrl,
    Expression<DateTime>? lastUpdated,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (word != null) 'word': word,
      if (audioUrl != null) 'audio_url': audioUrl,
      if (lastUpdated != null) 'last_updated': lastUpdated,
    });
  }

  WordPronunciationsCompanion copyWith({
    Value<int>? id,
    Value<String>? word,
    Value<String?>? audioUrl,
    Value<DateTime>? lastUpdated,
  }) {
    return WordPronunciationsCompanion(
      id: id ?? this.id,
      word: word ?? this.word,
      audioUrl: audioUrl ?? this.audioUrl,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (word.present) {
      map['word'] = Variable<String>(word.value);
    }
    if (audioUrl.present) {
      map['audio_url'] = Variable<String>(audioUrl.value);
    }
    if (lastUpdated.present) {
      map['last_updated'] = Variable<DateTime>(lastUpdated.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WordPronunciationsCompanion(')
          ..write('id: $id, ')
          ..write('word: $word, ')
          ..write('audioUrl: $audioUrl, ')
          ..write('lastUpdated: $lastUpdated')
          ..write(')'))
        .toString();
  }
}

class $SentenceAnalysesTable extends SentenceAnalyses
    with TableInfo<$SentenceAnalysesTable, SentenceAnalysis> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SentenceAnalysesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _sentenceMeta = const VerificationMeta(
    'sentence',
  );
  @override
  late final GeneratedColumn<String> sentence = GeneratedColumn<String>(
    'sentence',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _analysisMeta = const VerificationMeta(
    'analysis',
  );
  @override
  late final GeneratedColumn<String> analysis = GeneratedColumn<String>(
    'analysis',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastUpdatedMeta = const VerificationMeta(
    'lastUpdated',
  );
  @override
  late final GeneratedColumn<DateTime> lastUpdated = GeneratedColumn<DateTime>(
    'last_updated',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, sentence, analysis, lastUpdated];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sentence_analyses';
  @override
  VerificationContext validateIntegrity(
    Insertable<SentenceAnalysis> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('sentence')) {
      context.handle(
        _sentenceMeta,
        sentence.isAcceptableOrUnknown(data['sentence']!, _sentenceMeta),
      );
    } else if (isInserting) {
      context.missing(_sentenceMeta);
    }
    if (data.containsKey('analysis')) {
      context.handle(
        _analysisMeta,
        analysis.isAcceptableOrUnknown(data['analysis']!, _analysisMeta),
      );
    } else if (isInserting) {
      context.missing(_analysisMeta);
    }
    if (data.containsKey('last_updated')) {
      context.handle(
        _lastUpdatedMeta,
        lastUpdated.isAcceptableOrUnknown(
          data['last_updated']!,
          _lastUpdatedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastUpdatedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SentenceAnalysis map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SentenceAnalysis(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sentence: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sentence'],
      )!,
      analysis: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}analysis'],
      )!,
      lastUpdated: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_updated'],
      )!,
    );
  }

  @override
  $SentenceAnalysesTable createAlias(String alias) {
    return $SentenceAnalysesTable(attachedDatabase, alias);
  }
}

class SentenceAnalysis extends DataClass
    implements Insertable<SentenceAnalysis> {
  final int id;
  final String sentence;
  final String analysis;
  final DateTime lastUpdated;
  const SentenceAnalysis({
    required this.id,
    required this.sentence,
    required this.analysis,
    required this.lastUpdated,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['sentence'] = Variable<String>(sentence);
    map['analysis'] = Variable<String>(analysis);
    map['last_updated'] = Variable<DateTime>(lastUpdated);
    return map;
  }

  SentenceAnalysesCompanion toCompanion(bool nullToAbsent) {
    return SentenceAnalysesCompanion(
      id: Value(id),
      sentence: Value(sentence),
      analysis: Value(analysis),
      lastUpdated: Value(lastUpdated),
    );
  }

  factory SentenceAnalysis.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SentenceAnalysis(
      id: serializer.fromJson<int>(json['id']),
      sentence: serializer.fromJson<String>(json['sentence']),
      analysis: serializer.fromJson<String>(json['analysis']),
      lastUpdated: serializer.fromJson<DateTime>(json['lastUpdated']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sentence': serializer.toJson<String>(sentence),
      'analysis': serializer.toJson<String>(analysis),
      'lastUpdated': serializer.toJson<DateTime>(lastUpdated),
    };
  }

  SentenceAnalysis copyWith({
    int? id,
    String? sentence,
    String? analysis,
    DateTime? lastUpdated,
  }) => SentenceAnalysis(
    id: id ?? this.id,
    sentence: sentence ?? this.sentence,
    analysis: analysis ?? this.analysis,
    lastUpdated: lastUpdated ?? this.lastUpdated,
  );
  SentenceAnalysis copyWithCompanion(SentenceAnalysesCompanion data) {
    return SentenceAnalysis(
      id: data.id.present ? data.id.value : this.id,
      sentence: data.sentence.present ? data.sentence.value : this.sentence,
      analysis: data.analysis.present ? data.analysis.value : this.analysis,
      lastUpdated: data.lastUpdated.present
          ? data.lastUpdated.value
          : this.lastUpdated,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SentenceAnalysis(')
          ..write('id: $id, ')
          ..write('sentence: $sentence, ')
          ..write('analysis: $analysis, ')
          ..write('lastUpdated: $lastUpdated')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sentence, analysis, lastUpdated);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SentenceAnalysis &&
          other.id == this.id &&
          other.sentence == this.sentence &&
          other.analysis == this.analysis &&
          other.lastUpdated == this.lastUpdated);
}

class SentenceAnalysesCompanion extends UpdateCompanion<SentenceAnalysis> {
  final Value<int> id;
  final Value<String> sentence;
  final Value<String> analysis;
  final Value<DateTime> lastUpdated;
  const SentenceAnalysesCompanion({
    this.id = const Value.absent(),
    this.sentence = const Value.absent(),
    this.analysis = const Value.absent(),
    this.lastUpdated = const Value.absent(),
  });
  SentenceAnalysesCompanion.insert({
    this.id = const Value.absent(),
    required String sentence,
    required String analysis,
    required DateTime lastUpdated,
  }) : sentence = Value(sentence),
       analysis = Value(analysis),
       lastUpdated = Value(lastUpdated);
  static Insertable<SentenceAnalysis> custom({
    Expression<int>? id,
    Expression<String>? sentence,
    Expression<String>? analysis,
    Expression<DateTime>? lastUpdated,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sentence != null) 'sentence': sentence,
      if (analysis != null) 'analysis': analysis,
      if (lastUpdated != null) 'last_updated': lastUpdated,
    });
  }

  SentenceAnalysesCompanion copyWith({
    Value<int>? id,
    Value<String>? sentence,
    Value<String>? analysis,
    Value<DateTime>? lastUpdated,
  }) {
    return SentenceAnalysesCompanion(
      id: id ?? this.id,
      sentence: sentence ?? this.sentence,
      analysis: analysis ?? this.analysis,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sentence.present) {
      map['sentence'] = Variable<String>(sentence.value);
    }
    if (analysis.present) {
      map['analysis'] = Variable<String>(analysis.value);
    }
    if (lastUpdated.present) {
      map['last_updated'] = Variable<DateTime>(lastUpdated.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SentenceAnalysesCompanion(')
          ..write('id: $id, ')
          ..write('sentence: $sentence, ')
          ..write('analysis: $analysis, ')
          ..write('lastUpdated: $lastUpdated')
          ..write(')'))
        .toString();
  }
}

class $SentencePronunciationsTable extends SentencePronunciations
    with TableInfo<$SentencePronunciationsTable, SentencePronunciation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SentencePronunciationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sentenceMeta = const VerificationMeta(
    'sentence',
  );
  @override
  late final GeneratedColumn<String> sentence = GeneratedColumn<String>(
    'sentence',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _audioUrlMeta = const VerificationMeta(
    'audioUrl',
  );
  @override
  late final GeneratedColumn<String> audioUrl = GeneratedColumn<String>(
    'audio_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastUpdatedMeta = const VerificationMeta(
    'lastUpdated',
  );
  @override
  late final GeneratedColumn<DateTime> lastUpdated = GeneratedColumn<DateTime>(
    'last_updated',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, sentence, audioUrl, lastUpdated];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sentence_pronunciations';
  @override
  VerificationContext validateIntegrity(
    Insertable<SentencePronunciation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('sentence')) {
      context.handle(
        _sentenceMeta,
        sentence.isAcceptableOrUnknown(data['sentence']!, _sentenceMeta),
      );
    } else if (isInserting) {
      context.missing(_sentenceMeta);
    }
    if (data.containsKey('audio_url')) {
      context.handle(
        _audioUrlMeta,
        audioUrl.isAcceptableOrUnknown(data['audio_url']!, _audioUrlMeta),
      );
    }
    if (data.containsKey('last_updated')) {
      context.handle(
        _lastUpdatedMeta,
        lastUpdated.isAcceptableOrUnknown(
          data['last_updated']!,
          _lastUpdatedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastUpdatedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SentencePronunciation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SentencePronunciation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sentence: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sentence'],
      )!,
      audioUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_url'],
      ),
      lastUpdated: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_updated'],
      )!,
    );
  }

  @override
  $SentencePronunciationsTable createAlias(String alias) {
    return $SentencePronunciationsTable(attachedDatabase, alias);
  }
}

class SentencePronunciation extends DataClass
    implements Insertable<SentencePronunciation> {
  final int id;
  final String sentence;
  final String? audioUrl;
  final DateTime lastUpdated;
  const SentencePronunciation({
    required this.id,
    required this.sentence,
    this.audioUrl,
    required this.lastUpdated,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['sentence'] = Variable<String>(sentence);
    if (!nullToAbsent || audioUrl != null) {
      map['audio_url'] = Variable<String>(audioUrl);
    }
    map['last_updated'] = Variable<DateTime>(lastUpdated);
    return map;
  }

  SentencePronunciationsCompanion toCompanion(bool nullToAbsent) {
    return SentencePronunciationsCompanion(
      id: Value(id),
      sentence: Value(sentence),
      audioUrl: audioUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(audioUrl),
      lastUpdated: Value(lastUpdated),
    );
  }

  factory SentencePronunciation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SentencePronunciation(
      id: serializer.fromJson<int>(json['id']),
      sentence: serializer.fromJson<String>(json['sentence']),
      audioUrl: serializer.fromJson<String?>(json['audioUrl']),
      lastUpdated: serializer.fromJson<DateTime>(json['lastUpdated']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sentence': serializer.toJson<String>(sentence),
      'audioUrl': serializer.toJson<String?>(audioUrl),
      'lastUpdated': serializer.toJson<DateTime>(lastUpdated),
    };
  }

  SentencePronunciation copyWith({
    int? id,
    String? sentence,
    Value<String?> audioUrl = const Value.absent(),
    DateTime? lastUpdated,
  }) => SentencePronunciation(
    id: id ?? this.id,
    sentence: sentence ?? this.sentence,
    audioUrl: audioUrl.present ? audioUrl.value : this.audioUrl,
    lastUpdated: lastUpdated ?? this.lastUpdated,
  );
  SentencePronunciation copyWithCompanion(
    SentencePronunciationsCompanion data,
  ) {
    return SentencePronunciation(
      id: data.id.present ? data.id.value : this.id,
      sentence: data.sentence.present ? data.sentence.value : this.sentence,
      audioUrl: data.audioUrl.present ? data.audioUrl.value : this.audioUrl,
      lastUpdated: data.lastUpdated.present
          ? data.lastUpdated.value
          : this.lastUpdated,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SentencePronunciation(')
          ..write('id: $id, ')
          ..write('sentence: $sentence, ')
          ..write('audioUrl: $audioUrl, ')
          ..write('lastUpdated: $lastUpdated')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sentence, audioUrl, lastUpdated);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SentencePronunciation &&
          other.id == this.id &&
          other.sentence == this.sentence &&
          other.audioUrl == this.audioUrl &&
          other.lastUpdated == this.lastUpdated);
}

class SentencePronunciationsCompanion
    extends UpdateCompanion<SentencePronunciation> {
  final Value<int> id;
  final Value<String> sentence;
  final Value<String?> audioUrl;
  final Value<DateTime> lastUpdated;
  const SentencePronunciationsCompanion({
    this.id = const Value.absent(),
    this.sentence = const Value.absent(),
    this.audioUrl = const Value.absent(),
    this.lastUpdated = const Value.absent(),
  });
  SentencePronunciationsCompanion.insert({
    this.id = const Value.absent(),
    required String sentence,
    this.audioUrl = const Value.absent(),
    required DateTime lastUpdated,
  }) : sentence = Value(sentence),
       lastUpdated = Value(lastUpdated);
  static Insertable<SentencePronunciation> custom({
    Expression<int>? id,
    Expression<String>? sentence,
    Expression<String>? audioUrl,
    Expression<DateTime>? lastUpdated,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sentence != null) 'sentence': sentence,
      if (audioUrl != null) 'audio_url': audioUrl,
      if (lastUpdated != null) 'last_updated': lastUpdated,
    });
  }

  SentencePronunciationsCompanion copyWith({
    Value<int>? id,
    Value<String>? sentence,
    Value<String?>? audioUrl,
    Value<DateTime>? lastUpdated,
  }) {
    return SentencePronunciationsCompanion(
      id: id ?? this.id,
      sentence: sentence ?? this.sentence,
      audioUrl: audioUrl ?? this.audioUrl,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sentence.present) {
      map['sentence'] = Variable<String>(sentence.value);
    }
    if (audioUrl.present) {
      map['audio_url'] = Variable<String>(audioUrl.value);
    }
    if (lastUpdated.present) {
      map['last_updated'] = Variable<DateTime>(lastUpdated.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SentencePronunciationsCompanion(')
          ..write('id: $id, ')
          ..write('sentence: $sentence, ')
          ..write('audioUrl: $audioUrl, ')
          ..write('lastUpdated: $lastUpdated')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ShelfGroupsTable shelfGroups = $ShelfGroupsTable(this);
  late final $ShelfBooksTable shelfBooks = $ShelfBooksTable(this);
  late final $BookManifestsTable bookManifests = $BookManifestsTable(this);
  late final $WordExplanationsTable wordExplanations = $WordExplanationsTable(
    this,
  );
  late final $WordPronunciationsTable wordPronunciations =
      $WordPronunciationsTable(this);
  late final $SentenceAnalysesTable sentenceAnalyses = $SentenceAnalysesTable(
    this,
  );
  late final $SentencePronunciationsTable sentencePronunciations =
      $SentencePronunciationsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    shelfGroups,
    shelfBooks,
    bookManifests,
    wordExplanations,
    wordPronunciations,
    sentenceAnalyses,
    sentencePronunciations,
  ];
}

typedef $$ShelfGroupsTableCreateCompanionBuilder =
    ShelfGroupsCompanion Function({
      Value<int> id,
      required String name,
      required int creationDate,
      required int updatedAt,
      Value<bool> isDeleted,
    });
typedef $$ShelfGroupsTableUpdateCompanionBuilder =
    ShelfGroupsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<int> creationDate,
      Value<int> updatedAt,
      Value<bool> isDeleted,
    });

class $$ShelfGroupsTableFilterComposer
    extends Composer<_$AppDatabase, $ShelfGroupsTable> {
  $$ShelfGroupsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get creationDate => $composableBuilder(
    column: $table.creationDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ShelfGroupsTableOrderingComposer
    extends Composer<_$AppDatabase, $ShelfGroupsTable> {
  $$ShelfGroupsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get creationDate => $composableBuilder(
    column: $table.creationDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ShelfGroupsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ShelfGroupsTable> {
  $$ShelfGroupsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get creationDate => $composableBuilder(
    column: $table.creationDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);
}

class $$ShelfGroupsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ShelfGroupsTable,
          ShelfGroup,
          $$ShelfGroupsTableFilterComposer,
          $$ShelfGroupsTableOrderingComposer,
          $$ShelfGroupsTableAnnotationComposer,
          $$ShelfGroupsTableCreateCompanionBuilder,
          $$ShelfGroupsTableUpdateCompanionBuilder,
          (
            ShelfGroup,
            BaseReferences<_$AppDatabase, $ShelfGroupsTable, ShelfGroup>,
          ),
          ShelfGroup,
          PrefetchHooks Function()
        > {
  $$ShelfGroupsTableTableManager(_$AppDatabase db, $ShelfGroupsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ShelfGroupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ShelfGroupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ShelfGroupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> creationDate = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
              }) => ShelfGroupsCompanion(
                id: id,
                name: name,
                creationDate: creationDate,
                updatedAt: updatedAt,
                isDeleted: isDeleted,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required int creationDate,
                required int updatedAt,
                Value<bool> isDeleted = const Value.absent(),
              }) => ShelfGroupsCompanion.insert(
                id: id,
                name: name,
                creationDate: creationDate,
                updatedAt: updatedAt,
                isDeleted: isDeleted,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ShelfGroupsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ShelfGroupsTable,
      ShelfGroup,
      $$ShelfGroupsTableFilterComposer,
      $$ShelfGroupsTableOrderingComposer,
      $$ShelfGroupsTableAnnotationComposer,
      $$ShelfGroupsTableCreateCompanionBuilder,
      $$ShelfGroupsTableUpdateCompanionBuilder,
      (
        ShelfGroup,
        BaseReferences<_$AppDatabase, $ShelfGroupsTable, ShelfGroup>,
      ),
      ShelfGroup,
      PrefetchHooks Function()
    >;
typedef $$ShelfBooksTableCreateCompanionBuilder =
    ShelfBooksCompanion Function({
      Value<int> id,
      required String fileHash,
      Value<String?> filePath,
      Value<String?> coverPath,
      required String title,
      required String author,
      Value<List<String>> authors,
      Value<String?> description,
      Value<List<String>> subjects,
      Value<int> totalChapters,
      Value<String> epubVersion,
      Value<BookFormat> format,
      required int importDate,
      Value<int> direction,
      Value<BookProgress?> progress,
      Value<double> readingProgress,
      Value<int?> lastOpenedDate,
      Value<bool> isFinished,
      Value<String?> groupName,
      Value<bool> isDeleted,
      required int updatedAt,
      Value<int?> lastSyncedDate,
    });
typedef $$ShelfBooksTableUpdateCompanionBuilder =
    ShelfBooksCompanion Function({
      Value<int> id,
      Value<String> fileHash,
      Value<String?> filePath,
      Value<String?> coverPath,
      Value<String> title,
      Value<String> author,
      Value<List<String>> authors,
      Value<String?> description,
      Value<List<String>> subjects,
      Value<int> totalChapters,
      Value<String> epubVersion,
      Value<BookFormat> format,
      Value<int> importDate,
      Value<int> direction,
      Value<BookProgress?> progress,
      Value<double> readingProgress,
      Value<int?> lastOpenedDate,
      Value<bool> isFinished,
      Value<String?> groupName,
      Value<bool> isDeleted,
      Value<int> updatedAt,
      Value<int?> lastSyncedDate,
    });

class $$ShelfBooksTableFilterComposer
    extends Composer<_$AppDatabase, $ShelfBooksTable> {
  $$ShelfBooksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileHash => $composableBuilder(
    column: $table.fileHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get authors => $composableBuilder(
    column: $table.authors,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
  get subjects => $composableBuilder(
    column: $table.subjects,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get totalChapters => $composableBuilder(
    column: $table.totalChapters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get epubVersion => $composableBuilder(
    column: $table.epubVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<BookFormat, BookFormat, String> get format =>
      $composableBuilder(
        column: $table.format,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get importDate => $composableBuilder(
    column: $table.importDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<BookProgress?, BookProgress, String>
  get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<double> get readingProgress => $composableBuilder(
    column: $table.readingProgress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastOpenedDate => $composableBuilder(
    column: $table.lastOpenedDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFinished => $composableBuilder(
    column: $table.isFinished,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupName => $composableBuilder(
    column: $table.groupName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSyncedDate => $composableBuilder(
    column: $table.lastSyncedDate,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ShelfBooksTableOrderingComposer
    extends Composer<_$AppDatabase, $ShelfBooksTable> {
  $$ShelfBooksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileHash => $composableBuilder(
    column: $table.fileHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authors => $composableBuilder(
    column: $table.authors,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjects => $composableBuilder(
    column: $table.subjects,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalChapters => $composableBuilder(
    column: $table.totalChapters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get epubVersion => $composableBuilder(
    column: $table.epubVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get importDate => $composableBuilder(
    column: $table.importDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get readingProgress => $composableBuilder(
    column: $table.readingProgress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastOpenedDate => $composableBuilder(
    column: $table.lastOpenedDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFinished => $composableBuilder(
    column: $table.isFinished,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupName => $composableBuilder(
    column: $table.groupName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSyncedDate => $composableBuilder(
    column: $table.lastSyncedDate,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ShelfBooksTableAnnotationComposer
    extends Composer<_$AppDatabase, $ShelfBooksTable> {
  $$ShelfBooksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get fileHash =>
      $composableBuilder(column: $table.fileHash, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<String> get coverPath =>
      $composableBuilder(column: $table.coverPath, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String> get authors =>
      $composableBuilder(column: $table.authors, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<List<String>, String> get subjects =>
      $composableBuilder(column: $table.subjects, builder: (column) => column);

  GeneratedColumn<int> get totalChapters => $composableBuilder(
    column: $table.totalChapters,
    builder: (column) => column,
  );

  GeneratedColumn<String> get epubVersion => $composableBuilder(
    column: $table.epubVersion,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<BookFormat, String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<int> get importDate => $composableBuilder(
    column: $table.importDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => column);

  GeneratedColumnWithTypeConverter<BookProgress?, String> get progress =>
      $composableBuilder(column: $table.progress, builder: (column) => column);

  GeneratedColumn<double> get readingProgress => $composableBuilder(
    column: $table.readingProgress,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastOpenedDate => $composableBuilder(
    column: $table.lastOpenedDate,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isFinished => $composableBuilder(
    column: $table.isFinished,
    builder: (column) => column,
  );

  GeneratedColumn<String> get groupName =>
      $composableBuilder(column: $table.groupName, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get lastSyncedDate => $composableBuilder(
    column: $table.lastSyncedDate,
    builder: (column) => column,
  );
}

class $$ShelfBooksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ShelfBooksTable,
          ShelfBook,
          $$ShelfBooksTableFilterComposer,
          $$ShelfBooksTableOrderingComposer,
          $$ShelfBooksTableAnnotationComposer,
          $$ShelfBooksTableCreateCompanionBuilder,
          $$ShelfBooksTableUpdateCompanionBuilder,
          (
            ShelfBook,
            BaseReferences<_$AppDatabase, $ShelfBooksTable, ShelfBook>,
          ),
          ShelfBook,
          PrefetchHooks Function()
        > {
  $$ShelfBooksTableTableManager(_$AppDatabase db, $ShelfBooksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ShelfBooksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ShelfBooksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ShelfBooksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> fileHash = const Value.absent(),
                Value<String?> filePath = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> author = const Value.absent(),
                Value<List<String>> authors = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<List<String>> subjects = const Value.absent(),
                Value<int> totalChapters = const Value.absent(),
                Value<String> epubVersion = const Value.absent(),
                Value<BookFormat> format = const Value.absent(),
                Value<int> importDate = const Value.absent(),
                Value<int> direction = const Value.absent(),
                Value<BookProgress?> progress = const Value.absent(),
                Value<double> readingProgress = const Value.absent(),
                Value<int?> lastOpenedDate = const Value.absent(),
                Value<bool> isFinished = const Value.absent(),
                Value<String?> groupName = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> lastSyncedDate = const Value.absent(),
              }) => ShelfBooksCompanion(
                id: id,
                fileHash: fileHash,
                filePath: filePath,
                coverPath: coverPath,
                title: title,
                author: author,
                authors: authors,
                description: description,
                subjects: subjects,
                totalChapters: totalChapters,
                epubVersion: epubVersion,
                format: format,
                importDate: importDate,
                direction: direction,
                progress: progress,
                readingProgress: readingProgress,
                lastOpenedDate: lastOpenedDate,
                isFinished: isFinished,
                groupName: groupName,
                isDeleted: isDeleted,
                updatedAt: updatedAt,
                lastSyncedDate: lastSyncedDate,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String fileHash,
                Value<String?> filePath = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                required String title,
                required String author,
                Value<List<String>> authors = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<List<String>> subjects = const Value.absent(),
                Value<int> totalChapters = const Value.absent(),
                Value<String> epubVersion = const Value.absent(),
                Value<BookFormat> format = const Value.absent(),
                required int importDate,
                Value<int> direction = const Value.absent(),
                Value<BookProgress?> progress = const Value.absent(),
                Value<double> readingProgress = const Value.absent(),
                Value<int?> lastOpenedDate = const Value.absent(),
                Value<bool> isFinished = const Value.absent(),
                Value<String?> groupName = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                required int updatedAt,
                Value<int?> lastSyncedDate = const Value.absent(),
              }) => ShelfBooksCompanion.insert(
                id: id,
                fileHash: fileHash,
                filePath: filePath,
                coverPath: coverPath,
                title: title,
                author: author,
                authors: authors,
                description: description,
                subjects: subjects,
                totalChapters: totalChapters,
                epubVersion: epubVersion,
                format: format,
                importDate: importDate,
                direction: direction,
                progress: progress,
                readingProgress: readingProgress,
                lastOpenedDate: lastOpenedDate,
                isFinished: isFinished,
                groupName: groupName,
                isDeleted: isDeleted,
                updatedAt: updatedAt,
                lastSyncedDate: lastSyncedDate,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ShelfBooksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ShelfBooksTable,
      ShelfBook,
      $$ShelfBooksTableFilterComposer,
      $$ShelfBooksTableOrderingComposer,
      $$ShelfBooksTableAnnotationComposer,
      $$ShelfBooksTableCreateCompanionBuilder,
      $$ShelfBooksTableUpdateCompanionBuilder,
      (ShelfBook, BaseReferences<_$AppDatabase, $ShelfBooksTable, ShelfBook>),
      ShelfBook,
      PrefetchHooks Function()
    >;
typedef $$BookManifestsTableCreateCompanionBuilder =
    BookManifestsCompanion Function({
      Value<int> id,
      required String fileHash,
      required String opfRootPath,
      required List<SpineItem> spine,
      required List<TocItem> toc,
      required List<ManifestItem> manifest,
      required String epubVersion,
      Value<BookFormat> format,
      required DateTime lastUpdated,
    });
typedef $$BookManifestsTableUpdateCompanionBuilder =
    BookManifestsCompanion Function({
      Value<int> id,
      Value<String> fileHash,
      Value<String> opfRootPath,
      Value<List<SpineItem>> spine,
      Value<List<TocItem>> toc,
      Value<List<ManifestItem>> manifest,
      Value<String> epubVersion,
      Value<BookFormat> format,
      Value<DateTime> lastUpdated,
    });

class $$BookManifestsTableFilterComposer
    extends Composer<_$AppDatabase, $BookManifestsTable> {
  $$BookManifestsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileHash => $composableBuilder(
    column: $table.fileHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get opfRootPath => $composableBuilder(
    column: $table.opfRootPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<SpineItem>, List<SpineItem>, String>
  get spine => $composableBuilder(
    column: $table.spine,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<List<TocItem>, List<TocItem>, String>
  get toc => $composableBuilder(
    column: $table.toc,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<List<ManifestItem>, List<ManifestItem>, String>
  get manifest => $composableBuilder(
    column: $table.manifest,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get epubVersion => $composableBuilder(
    column: $table.epubVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<BookFormat, BookFormat, String> get format =>
      $composableBuilder(
        column: $table.format,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BookManifestsTableOrderingComposer
    extends Composer<_$AppDatabase, $BookManifestsTable> {
  $$BookManifestsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileHash => $composableBuilder(
    column: $table.fileHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get opfRootPath => $composableBuilder(
    column: $table.opfRootPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get spine => $composableBuilder(
    column: $table.spine,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toc => $composableBuilder(
    column: $table.toc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get manifest => $composableBuilder(
    column: $table.manifest,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get epubVersion => $composableBuilder(
    column: $table.epubVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BookManifestsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BookManifestsTable> {
  $$BookManifestsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get fileHash =>
      $composableBuilder(column: $table.fileHash, builder: (column) => column);

  GeneratedColumn<String> get opfRootPath => $composableBuilder(
    column: $table.opfRootPath,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<List<SpineItem>, String> get spine =>
      $composableBuilder(column: $table.spine, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<TocItem>, String> get toc =>
      $composableBuilder(column: $table.toc, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<ManifestItem>, String> get manifest =>
      $composableBuilder(column: $table.manifest, builder: (column) => column);

  GeneratedColumn<String> get epubVersion => $composableBuilder(
    column: $table.epubVersion,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<BookFormat, String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => column,
  );
}

class $$BookManifestsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BookManifestsTable,
          BookManifest,
          $$BookManifestsTableFilterComposer,
          $$BookManifestsTableOrderingComposer,
          $$BookManifestsTableAnnotationComposer,
          $$BookManifestsTableCreateCompanionBuilder,
          $$BookManifestsTableUpdateCompanionBuilder,
          (
            BookManifest,
            BaseReferences<_$AppDatabase, $BookManifestsTable, BookManifest>,
          ),
          BookManifest,
          PrefetchHooks Function()
        > {
  $$BookManifestsTableTableManager(_$AppDatabase db, $BookManifestsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookManifestsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookManifestsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookManifestsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> fileHash = const Value.absent(),
                Value<String> opfRootPath = const Value.absent(),
                Value<List<SpineItem>> spine = const Value.absent(),
                Value<List<TocItem>> toc = const Value.absent(),
                Value<List<ManifestItem>> manifest = const Value.absent(),
                Value<String> epubVersion = const Value.absent(),
                Value<BookFormat> format = const Value.absent(),
                Value<DateTime> lastUpdated = const Value.absent(),
              }) => BookManifestsCompanion(
                id: id,
                fileHash: fileHash,
                opfRootPath: opfRootPath,
                spine: spine,
                toc: toc,
                manifest: manifest,
                epubVersion: epubVersion,
                format: format,
                lastUpdated: lastUpdated,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String fileHash,
                required String opfRootPath,
                required List<SpineItem> spine,
                required List<TocItem> toc,
                required List<ManifestItem> manifest,
                required String epubVersion,
                Value<BookFormat> format = const Value.absent(),
                required DateTime lastUpdated,
              }) => BookManifestsCompanion.insert(
                id: id,
                fileHash: fileHash,
                opfRootPath: opfRootPath,
                spine: spine,
                toc: toc,
                manifest: manifest,
                epubVersion: epubVersion,
                format: format,
                lastUpdated: lastUpdated,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BookManifestsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BookManifestsTable,
      BookManifest,
      $$BookManifestsTableFilterComposer,
      $$BookManifestsTableOrderingComposer,
      $$BookManifestsTableAnnotationComposer,
      $$BookManifestsTableCreateCompanionBuilder,
      $$BookManifestsTableUpdateCompanionBuilder,
      (
        BookManifest,
        BaseReferences<_$AppDatabase, $BookManifestsTable, BookManifest>,
      ),
      BookManifest,
      PrefetchHooks Function()
    >;
typedef $$WordExplanationsTableCreateCompanionBuilder =
    WordExplanationsCompanion Function({
      Value<int> id,
      required String word,
      required String explanation,
      required DateTime lastUpdated,
      Value<String?> context,
    });
typedef $$WordExplanationsTableUpdateCompanionBuilder =
    WordExplanationsCompanion Function({
      Value<int> id,
      Value<String> word,
      Value<String> explanation,
      Value<DateTime> lastUpdated,
      Value<String?> context,
    });

class $$WordExplanationsTableFilterComposer
    extends Composer<_$AppDatabase, $WordExplanationsTable> {
  $$WordExplanationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get word => $composableBuilder(
    column: $table.word,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get explanation => $composableBuilder(
    column: $table.explanation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get context => $composableBuilder(
    column: $table.context,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WordExplanationsTableOrderingComposer
    extends Composer<_$AppDatabase, $WordExplanationsTable> {
  $$WordExplanationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get word => $composableBuilder(
    column: $table.word,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get explanation => $composableBuilder(
    column: $table.explanation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get context => $composableBuilder(
    column: $table.context,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WordExplanationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WordExplanationsTable> {
  $$WordExplanationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get word =>
      $composableBuilder(column: $table.word, builder: (column) => column);

  GeneratedColumn<String> get explanation => $composableBuilder(
    column: $table.explanation,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => column,
  );

  GeneratedColumn<String> get context =>
      $composableBuilder(column: $table.context, builder: (column) => column);
}

class $$WordExplanationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WordExplanationsTable,
          WordExplanation,
          $$WordExplanationsTableFilterComposer,
          $$WordExplanationsTableOrderingComposer,
          $$WordExplanationsTableAnnotationComposer,
          $$WordExplanationsTableCreateCompanionBuilder,
          $$WordExplanationsTableUpdateCompanionBuilder,
          (
            WordExplanation,
            BaseReferences<
              _$AppDatabase,
              $WordExplanationsTable,
              WordExplanation
            >,
          ),
          WordExplanation,
          PrefetchHooks Function()
        > {
  $$WordExplanationsTableTableManager(
    _$AppDatabase db,
    $WordExplanationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WordExplanationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WordExplanationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WordExplanationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> word = const Value.absent(),
                Value<String> explanation = const Value.absent(),
                Value<DateTime> lastUpdated = const Value.absent(),
                Value<String?> context = const Value.absent(),
              }) => WordExplanationsCompanion(
                id: id,
                word: word,
                explanation: explanation,
                lastUpdated: lastUpdated,
                context: context,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String word,
                required String explanation,
                required DateTime lastUpdated,
                Value<String?> context = const Value.absent(),
              }) => WordExplanationsCompanion.insert(
                id: id,
                word: word,
                explanation: explanation,
                lastUpdated: lastUpdated,
                context: context,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WordExplanationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WordExplanationsTable,
      WordExplanation,
      $$WordExplanationsTableFilterComposer,
      $$WordExplanationsTableOrderingComposer,
      $$WordExplanationsTableAnnotationComposer,
      $$WordExplanationsTableCreateCompanionBuilder,
      $$WordExplanationsTableUpdateCompanionBuilder,
      (
        WordExplanation,
        BaseReferences<_$AppDatabase, $WordExplanationsTable, WordExplanation>,
      ),
      WordExplanation,
      PrefetchHooks Function()
    >;
typedef $$WordPronunciationsTableCreateCompanionBuilder =
    WordPronunciationsCompanion Function({
      Value<int> id,
      required String word,
      Value<String?> audioUrl,
      required DateTime lastUpdated,
    });
typedef $$WordPronunciationsTableUpdateCompanionBuilder =
    WordPronunciationsCompanion Function({
      Value<int> id,
      Value<String> word,
      Value<String?> audioUrl,
      Value<DateTime> lastUpdated,
    });

class $$WordPronunciationsTableFilterComposer
    extends Composer<_$AppDatabase, $WordPronunciationsTable> {
  $$WordPronunciationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get word => $composableBuilder(
    column: $table.word,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioUrl => $composableBuilder(
    column: $table.audioUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WordPronunciationsTableOrderingComposer
    extends Composer<_$AppDatabase, $WordPronunciationsTable> {
  $$WordPronunciationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get word => $composableBuilder(
    column: $table.word,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioUrl => $composableBuilder(
    column: $table.audioUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WordPronunciationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WordPronunciationsTable> {
  $$WordPronunciationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get word =>
      $composableBuilder(column: $table.word, builder: (column) => column);

  GeneratedColumn<String> get audioUrl =>
      $composableBuilder(column: $table.audioUrl, builder: (column) => column);

  GeneratedColumn<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => column,
  );
}

class $$WordPronunciationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WordPronunciationsTable,
          WordPronunciation,
          $$WordPronunciationsTableFilterComposer,
          $$WordPronunciationsTableOrderingComposer,
          $$WordPronunciationsTableAnnotationComposer,
          $$WordPronunciationsTableCreateCompanionBuilder,
          $$WordPronunciationsTableUpdateCompanionBuilder,
          (
            WordPronunciation,
            BaseReferences<
              _$AppDatabase,
              $WordPronunciationsTable,
              WordPronunciation
            >,
          ),
          WordPronunciation,
          PrefetchHooks Function()
        > {
  $$WordPronunciationsTableTableManager(
    _$AppDatabase db,
    $WordPronunciationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WordPronunciationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WordPronunciationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WordPronunciationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> word = const Value.absent(),
                Value<String?> audioUrl = const Value.absent(),
                Value<DateTime> lastUpdated = const Value.absent(),
              }) => WordPronunciationsCompanion(
                id: id,
                word: word,
                audioUrl: audioUrl,
                lastUpdated: lastUpdated,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String word,
                Value<String?> audioUrl = const Value.absent(),
                required DateTime lastUpdated,
              }) => WordPronunciationsCompanion.insert(
                id: id,
                word: word,
                audioUrl: audioUrl,
                lastUpdated: lastUpdated,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WordPronunciationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WordPronunciationsTable,
      WordPronunciation,
      $$WordPronunciationsTableFilterComposer,
      $$WordPronunciationsTableOrderingComposer,
      $$WordPronunciationsTableAnnotationComposer,
      $$WordPronunciationsTableCreateCompanionBuilder,
      $$WordPronunciationsTableUpdateCompanionBuilder,
      (
        WordPronunciation,
        BaseReferences<
          _$AppDatabase,
          $WordPronunciationsTable,
          WordPronunciation
        >,
      ),
      WordPronunciation,
      PrefetchHooks Function()
    >;
typedef $$SentenceAnalysesTableCreateCompanionBuilder =
    SentenceAnalysesCompanion Function({
      Value<int> id,
      required String sentence,
      required String analysis,
      required DateTime lastUpdated,
    });
typedef $$SentenceAnalysesTableUpdateCompanionBuilder =
    SentenceAnalysesCompanion Function({
      Value<int> id,
      Value<String> sentence,
      Value<String> analysis,
      Value<DateTime> lastUpdated,
    });

class $$SentenceAnalysesTableFilterComposer
    extends Composer<_$AppDatabase, $SentenceAnalysesTable> {
  $$SentenceAnalysesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sentence => $composableBuilder(
    column: $table.sentence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get analysis => $composableBuilder(
    column: $table.analysis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SentenceAnalysesTableOrderingComposer
    extends Composer<_$AppDatabase, $SentenceAnalysesTable> {
  $$SentenceAnalysesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sentence => $composableBuilder(
    column: $table.sentence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get analysis => $composableBuilder(
    column: $table.analysis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SentenceAnalysesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SentenceAnalysesTable> {
  $$SentenceAnalysesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sentence =>
      $composableBuilder(column: $table.sentence, builder: (column) => column);

  GeneratedColumn<String> get analysis =>
      $composableBuilder(column: $table.analysis, builder: (column) => column);

  GeneratedColumn<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => column,
  );
}

class $$SentenceAnalysesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SentenceAnalysesTable,
          SentenceAnalysis,
          $$SentenceAnalysesTableFilterComposer,
          $$SentenceAnalysesTableOrderingComposer,
          $$SentenceAnalysesTableAnnotationComposer,
          $$SentenceAnalysesTableCreateCompanionBuilder,
          $$SentenceAnalysesTableUpdateCompanionBuilder,
          (
            SentenceAnalysis,
            BaseReferences<
              _$AppDatabase,
              $SentenceAnalysesTable,
              SentenceAnalysis
            >,
          ),
          SentenceAnalysis,
          PrefetchHooks Function()
        > {
  $$SentenceAnalysesTableTableManager(
    _$AppDatabase db,
    $SentenceAnalysesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SentenceAnalysesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SentenceAnalysesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SentenceAnalysesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> sentence = const Value.absent(),
                Value<String> analysis = const Value.absent(),
                Value<DateTime> lastUpdated = const Value.absent(),
              }) => SentenceAnalysesCompanion(
                id: id,
                sentence: sentence,
                analysis: analysis,
                lastUpdated: lastUpdated,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String sentence,
                required String analysis,
                required DateTime lastUpdated,
              }) => SentenceAnalysesCompanion.insert(
                id: id,
                sentence: sentence,
                analysis: analysis,
                lastUpdated: lastUpdated,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SentenceAnalysesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SentenceAnalysesTable,
      SentenceAnalysis,
      $$SentenceAnalysesTableFilterComposer,
      $$SentenceAnalysesTableOrderingComposer,
      $$SentenceAnalysesTableAnnotationComposer,
      $$SentenceAnalysesTableCreateCompanionBuilder,
      $$SentenceAnalysesTableUpdateCompanionBuilder,
      (
        SentenceAnalysis,
        BaseReferences<_$AppDatabase, $SentenceAnalysesTable, SentenceAnalysis>,
      ),
      SentenceAnalysis,
      PrefetchHooks Function()
    >;
typedef $$SentencePronunciationsTableCreateCompanionBuilder =
    SentencePronunciationsCompanion Function({
      Value<int> id,
      required String sentence,
      Value<String?> audioUrl,
      required DateTime lastUpdated,
    });
typedef $$SentencePronunciationsTableUpdateCompanionBuilder =
    SentencePronunciationsCompanion Function({
      Value<int> id,
      Value<String> sentence,
      Value<String?> audioUrl,
      Value<DateTime> lastUpdated,
    });

class $$SentencePronunciationsTableFilterComposer
    extends Composer<_$AppDatabase, $SentencePronunciationsTable> {
  $$SentencePronunciationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sentence => $composableBuilder(
    column: $table.sentence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioUrl => $composableBuilder(
    column: $table.audioUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SentencePronunciationsTableOrderingComposer
    extends Composer<_$AppDatabase, $SentencePronunciationsTable> {
  $$SentencePronunciationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sentence => $composableBuilder(
    column: $table.sentence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioUrl => $composableBuilder(
    column: $table.audioUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SentencePronunciationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SentencePronunciationsTable> {
  $$SentencePronunciationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sentence =>
      $composableBuilder(column: $table.sentence, builder: (column) => column);

  GeneratedColumn<String> get audioUrl =>
      $composableBuilder(column: $table.audioUrl, builder: (column) => column);

  GeneratedColumn<DateTime> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => column,
  );
}

class $$SentencePronunciationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SentencePronunciationsTable,
          SentencePronunciation,
          $$SentencePronunciationsTableFilterComposer,
          $$SentencePronunciationsTableOrderingComposer,
          $$SentencePronunciationsTableAnnotationComposer,
          $$SentencePronunciationsTableCreateCompanionBuilder,
          $$SentencePronunciationsTableUpdateCompanionBuilder,
          (
            SentencePronunciation,
            BaseReferences<
              _$AppDatabase,
              $SentencePronunciationsTable,
              SentencePronunciation
            >,
          ),
          SentencePronunciation,
          PrefetchHooks Function()
        > {
  $$SentencePronunciationsTableTableManager(
    _$AppDatabase db,
    $SentencePronunciationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SentencePronunciationsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$SentencePronunciationsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SentencePronunciationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> sentence = const Value.absent(),
                Value<String?> audioUrl = const Value.absent(),
                Value<DateTime> lastUpdated = const Value.absent(),
              }) => SentencePronunciationsCompanion(
                id: id,
                sentence: sentence,
                audioUrl: audioUrl,
                lastUpdated: lastUpdated,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String sentence,
                Value<String?> audioUrl = const Value.absent(),
                required DateTime lastUpdated,
              }) => SentencePronunciationsCompanion.insert(
                id: id,
                sentence: sentence,
                audioUrl: audioUrl,
                lastUpdated: lastUpdated,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SentencePronunciationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SentencePronunciationsTable,
      SentencePronunciation,
      $$SentencePronunciationsTableFilterComposer,
      $$SentencePronunciationsTableOrderingComposer,
      $$SentencePronunciationsTableAnnotationComposer,
      $$SentencePronunciationsTableCreateCompanionBuilder,
      $$SentencePronunciationsTableUpdateCompanionBuilder,
      (
        SentencePronunciation,
        BaseReferences<
          _$AppDatabase,
          $SentencePronunciationsTable,
          SentencePronunciation
        >,
      ),
      SentencePronunciation,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ShelfGroupsTableTableManager get shelfGroups =>
      $$ShelfGroupsTableTableManager(_db, _db.shelfGroups);
  $$ShelfBooksTableTableManager get shelfBooks =>
      $$ShelfBooksTableTableManager(_db, _db.shelfBooks);
  $$BookManifestsTableTableManager get bookManifests =>
      $$BookManifestsTableTableManager(_db, _db.bookManifests);
  $$WordExplanationsTableTableManager get wordExplanations =>
      $$WordExplanationsTableTableManager(_db, _db.wordExplanations);
  $$WordPronunciationsTableTableManager get wordPronunciations =>
      $$WordPronunciationsTableTableManager(_db, _db.wordPronunciations);
  $$SentenceAnalysesTableTableManager get sentenceAnalyses =>
      $$SentenceAnalysesTableTableManager(_db, _db.sentenceAnalyses);
  $$SentencePronunciationsTableTableManager get sentencePronunciations =>
      $$SentencePronunciationsTableTableManager(
        _db,
        _db.sentencePronunciations,
      );
}
