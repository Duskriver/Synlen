// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sentence_pronunciation.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetSentencePronunciationCollection on Isar {
  IsarCollection<SentencePronunciation> get sentencePronunciations =>
      this.collection();
}

const SentencePronunciationSchema = CollectionSchema(
  name: r'SentencePronunciation',
  id: -8841789925205684871,
  properties: {
    r'audioUrl': PropertySchema(
      id: 0,
      name: r'audioUrl',
      type: IsarType.string,
    ),
    r'lastUpdated': PropertySchema(
      id: 1,
      name: r'lastUpdated',
      type: IsarType.dateTime,
    ),
    r'sentence': PropertySchema(
      id: 2,
      name: r'sentence',
      type: IsarType.string,
    )
  },
  estimateSize: _sentencePronunciationEstimateSize,
  serialize: _sentencePronunciationSerialize,
  deserialize: _sentencePronunciationDeserialize,
  deserializeProp: _sentencePronunciationDeserializeProp,
  idName: r'id',
  indexes: {
    r'sentence': IndexSchema(
      id: 548411362200987026,
      name: r'sentence',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'sentence',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _sentencePronunciationGetId,
  getLinks: _sentencePronunciationGetLinks,
  attach: _sentencePronunciationAttach,
  version: '3.1.0+1',
);

int _sentencePronunciationEstimateSize(
  SentencePronunciation object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.audioUrl;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.sentence.length * 3;
  return bytesCount;
}

void _sentencePronunciationSerialize(
  SentencePronunciation object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.audioUrl);
  writer.writeDateTime(offsets[1], object.lastUpdated);
  writer.writeString(offsets[2], object.sentence);
}

SentencePronunciation _sentencePronunciationDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = SentencePronunciation();
  object.audioUrl = reader.readStringOrNull(offsets[0]);
  object.id = id;
  object.lastUpdated = reader.readDateTime(offsets[1]);
  object.sentence = reader.readString(offsets[2]);
  return object;
}

P _sentencePronunciationDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset)) as P;
    case 1:
      return (reader.readDateTime(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _sentencePronunciationGetId(SentencePronunciation object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _sentencePronunciationGetLinks(
    SentencePronunciation object) {
  return [];
}

void _sentencePronunciationAttach(
    IsarCollection<dynamic> col, Id id, SentencePronunciation object) {
  object.id = id;
}

extension SentencePronunciationByIndex
    on IsarCollection<SentencePronunciation> {
  Future<SentencePronunciation?> getBySentence(String sentence) {
    return getByIndex(r'sentence', [sentence]);
  }

  SentencePronunciation? getBySentenceSync(String sentence) {
    return getByIndexSync(r'sentence', [sentence]);
  }

  Future<bool> deleteBySentence(String sentence) {
    return deleteByIndex(r'sentence', [sentence]);
  }

  bool deleteBySentenceSync(String sentence) {
    return deleteByIndexSync(r'sentence', [sentence]);
  }

  Future<List<SentencePronunciation?>> getAllBySentence(
      List<String> sentenceValues) {
    final values = sentenceValues.map((e) => [e]).toList();
    return getAllByIndex(r'sentence', values);
  }

  List<SentencePronunciation?> getAllBySentenceSync(
      List<String> sentenceValues) {
    final values = sentenceValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'sentence', values);
  }

  Future<int> deleteAllBySentence(List<String> sentenceValues) {
    final values = sentenceValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'sentence', values);
  }

  int deleteAllBySentenceSync(List<String> sentenceValues) {
    final values = sentenceValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'sentence', values);
  }

  Future<Id> putBySentence(SentencePronunciation object) {
    return putByIndex(r'sentence', object);
  }

  Id putBySentenceSync(SentencePronunciation object, {bool saveLinks = true}) {
    return putByIndexSync(r'sentence', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllBySentence(List<SentencePronunciation> objects) {
    return putAllByIndex(r'sentence', objects);
  }

  List<Id> putAllBySentenceSync(List<SentencePronunciation> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'sentence', objects, saveLinks: saveLinks);
  }
}

extension SentencePronunciationQueryWhereSort
    on QueryBuilder<SentencePronunciation, SentencePronunciation, QWhere> {
  QueryBuilder<SentencePronunciation, SentencePronunciation, QAfterWhere>
      anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension SentencePronunciationQueryWhere on QueryBuilder<SentencePronunciation,
    SentencePronunciation, QWhereClause> {
  QueryBuilder<SentencePronunciation, SentencePronunciation, QAfterWhereClause>
      idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<SentencePronunciation, SentencePronunciation, QAfterWhereClause>
      idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<SentencePronunciation, SentencePronunciation, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<SentencePronunciation, SentencePronunciation, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<SentencePronunciation, SentencePronunciation, QAfterWhereClause>
      idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SentencePronunciation, SentencePronunciation, QAfterWhereClause>
      sentenceEqualTo(String sentence) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'sentence',
        value: [sentence],
      ));
    });
  }

  QueryBuilder<SentencePronunciation, SentencePronunciation, QAfterWhereClause>
      sentenceNotEqualTo(String sentence) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'sentence',
              lower: [],
              upper: [sentence],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'sentence',
              lower: [sentence],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'sentence',
              lower: [sentence],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'sentence',
              lower: [],
              upper: [sentence],
              includeUpper: false,
            ));
      }
    });
  }
}

extension SentencePronunciationQueryFilter on QueryBuilder<
    SentencePronunciation, SentencePronunciation, QFilterCondition> {
  QueryBuilder<SentencePronunciation, SentencePronunciation,
      QAfterFilterCondition> audioUrlIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'audioUrl',
      ));
    });
  }

  QueryBuilder<SentencePronunciation, SentencePronunciation,
      QAfterFilterCondition> audioUrlIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'audioUrl',
      ));
    });
  }

  QueryBuilder<SentencePronunciation, SentencePronunciation,
      QAfterFilterCondition> audioUrlEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'audioUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SentencePronunciation, SentencePronunciation,
      QAfterFilterCondition> audioUrlGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'audioUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SentencePronunciation, SentencePronunciation,
      QAfterFilterCondition> audioUrlLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'audioUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SentencePronunciation, SentencePronunciation,
      QAfterFilterCondition> audioUrlBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'audioUrl',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SentencePronunciation, SentencePronunciation,
      QAfterFilterCondition> audioUrlStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'audioUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SentencePronunciation, SentencePronunciation,
      QAfterFilterCondition> audioUrlEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'audioUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SentencePronunciation, SentencePronunciation,
          QAfterFilterCondition>
      audioUrlContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'audioUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SentencePronunciation, SentencePronunciation,
          QAfterFilterCondition>
      audioUrlMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'audioUrl',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SentencePronunciation, SentencePronunciation,
      QAfterFilterCondition> audioUrlIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'audioUrl',
        value: '',
      ));
    });
  }

  QueryBuilder<SentencePronunciation, SentencePronunciation,
      QAfterFilterCondition> audioUrlIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'audioUrl',
        value: '',
      ));
    });
  }

  QueryBuilder<SentencePronunciation, SentencePronunciation,
      QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<SentencePronunciation, SentencePronunciation,
      QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<SentencePronunciation, SentencePronunciation,
      QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<SentencePronunciation, SentencePronunciation,
      QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SentencePronunciation, SentencePronunciation,
      QAfterFilterCondition> lastUpdatedEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastUpdated',
        value: value,
      ));
    });
  }

  QueryBuilder<SentencePronunciation, SentencePronunciation,
      QAfterFilterCondition> lastUpdatedGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastUpdated',
        value: value,
      ));
    });
  }

  QueryBuilder<SentencePronunciation, SentencePronunciation,
      QAfterFilterCondition> lastUpdatedLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastUpdated',
        value: value,
      ));
    });
  }

  QueryBuilder<SentencePronunciation, SentencePronunciation,
      QAfterFilterCondition> lastUpdatedBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastUpdated',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SentencePronunciation, SentencePronunciation,
      QAfterFilterCondition> sentenceEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sentence',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SentencePronunciation, SentencePronunciation,
      QAfterFilterCondition> sentenceGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sentence',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SentencePronunciation, SentencePronunciation,
      QAfterFilterCondition> sentenceLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sentence',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SentencePronunciation, SentencePronunciation,
      QAfterFilterCondition> sentenceBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sentence',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SentencePronunciation, SentencePronunciation,
      QAfterFilterCondition> sentenceStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'sentence',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SentencePronunciation, SentencePronunciation,
      QAfterFilterCondition> sentenceEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'sentence',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SentencePronunciation, SentencePronunciation,
          QAfterFilterCondition>
      sentenceContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'sentence',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SentencePronunciation, SentencePronunciation,
          QAfterFilterCondition>
      sentenceMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'sentence',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SentencePronunciation, SentencePronunciation,
      QAfterFilterCondition> sentenceIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sentence',
        value: '',
      ));
    });
  }

  QueryBuilder<SentencePronunciation, SentencePronunciation,
      QAfterFilterCondition> sentenceIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'sentence',
        value: '',
      ));
    });
  }
}

extension SentencePronunciationQueryObject on QueryBuilder<
    SentencePronunciation, SentencePronunciation, QFilterCondition> {}

extension SentencePronunciationQueryLinks on QueryBuilder<SentencePronunciation,
    SentencePronunciation, QFilterCondition> {}

extension SentencePronunciationQuerySortBy
    on QueryBuilder<SentencePronunciation, SentencePronunciation, QSortBy> {
  QueryBuilder<SentencePronunciation, SentencePronunciation, QAfterSortBy>
      sortByAudioUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'audioUrl', Sort.asc);
    });
  }

  QueryBuilder<SentencePronunciation, SentencePronunciation, QAfterSortBy>
      sortByAudioUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'audioUrl', Sort.desc);
    });
  }

  QueryBuilder<SentencePronunciation, SentencePronunciation, QAfterSortBy>
      sortByLastUpdated() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUpdated', Sort.asc);
    });
  }

  QueryBuilder<SentencePronunciation, SentencePronunciation, QAfterSortBy>
      sortByLastUpdatedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUpdated', Sort.desc);
    });
  }

  QueryBuilder<SentencePronunciation, SentencePronunciation, QAfterSortBy>
      sortBySentence() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sentence', Sort.asc);
    });
  }

  QueryBuilder<SentencePronunciation, SentencePronunciation, QAfterSortBy>
      sortBySentenceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sentence', Sort.desc);
    });
  }
}

extension SentencePronunciationQuerySortThenBy
    on QueryBuilder<SentencePronunciation, SentencePronunciation, QSortThenBy> {
  QueryBuilder<SentencePronunciation, SentencePronunciation, QAfterSortBy>
      thenByAudioUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'audioUrl', Sort.asc);
    });
  }

  QueryBuilder<SentencePronunciation, SentencePronunciation, QAfterSortBy>
      thenByAudioUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'audioUrl', Sort.desc);
    });
  }

  QueryBuilder<SentencePronunciation, SentencePronunciation, QAfterSortBy>
      thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<SentencePronunciation, SentencePronunciation, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<SentencePronunciation, SentencePronunciation, QAfterSortBy>
      thenByLastUpdated() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUpdated', Sort.asc);
    });
  }

  QueryBuilder<SentencePronunciation, SentencePronunciation, QAfterSortBy>
      thenByLastUpdatedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUpdated', Sort.desc);
    });
  }

  QueryBuilder<SentencePronunciation, SentencePronunciation, QAfterSortBy>
      thenBySentence() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sentence', Sort.asc);
    });
  }

  QueryBuilder<SentencePronunciation, SentencePronunciation, QAfterSortBy>
      thenBySentenceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sentence', Sort.desc);
    });
  }
}

extension SentencePronunciationQueryWhereDistinct
    on QueryBuilder<SentencePronunciation, SentencePronunciation, QDistinct> {
  QueryBuilder<SentencePronunciation, SentencePronunciation, QDistinct>
      distinctByAudioUrl({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'audioUrl', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SentencePronunciation, SentencePronunciation, QDistinct>
      distinctByLastUpdated() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastUpdated');
    });
  }

  QueryBuilder<SentencePronunciation, SentencePronunciation, QDistinct>
      distinctBySentence({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sentence', caseSensitive: caseSensitive);
    });
  }
}

extension SentencePronunciationQueryProperty on QueryBuilder<
    SentencePronunciation, SentencePronunciation, QQueryProperty> {
  QueryBuilder<SentencePronunciation, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<SentencePronunciation, String?, QQueryOperations>
      audioUrlProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'audioUrl');
    });
  }

  QueryBuilder<SentencePronunciation, DateTime, QQueryOperations>
      lastUpdatedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastUpdated');
    });
  }

  QueryBuilder<SentencePronunciation, String, QQueryOperations>
      sentenceProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sentence');
    });
  }
}
