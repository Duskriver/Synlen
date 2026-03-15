// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sentence_analysis.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetSentenceAnalysisCollection on Isar {
  IsarCollection<SentenceAnalysis> get sentenceAnalysis => this.collection();
}

const SentenceAnalysisSchema = CollectionSchema(
  name: r'SentenceAnalysis',
  id: 4237526127947078241,
  properties: {
    r'analysis': PropertySchema(
      id: 0,
      name: r'analysis',
      type: IsarType.string,
    ),
    r'audioUrl': PropertySchema(
      id: 1,
      name: r'audioUrl',
      type: IsarType.string,
    ),
    r'lastUpdated': PropertySchema(
      id: 2,
      name: r'lastUpdated',
      type: IsarType.dateTime,
    ),
    r'sentence': PropertySchema(
      id: 3,
      name: r'sentence',
      type: IsarType.string,
    )
  },
  estimateSize: _sentenceAnalysisEstimateSize,
  serialize: _sentenceAnalysisSerialize,
  deserialize: _sentenceAnalysisDeserialize,
  deserializeProp: _sentenceAnalysisDeserializeProp,
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
  getId: _sentenceAnalysisGetId,
  getLinks: _sentenceAnalysisGetLinks,
  attach: _sentenceAnalysisAttach,
  version: '3.1.0+1',
);

int _sentenceAnalysisEstimateSize(
  SentenceAnalysis object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.analysis.length * 3;
  {
    final value = object.audioUrl;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.sentence.length * 3;
  return bytesCount;
}

void _sentenceAnalysisSerialize(
  SentenceAnalysis object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.analysis);
  writer.writeString(offsets[1], object.audioUrl);
  writer.writeDateTime(offsets[2], object.lastUpdated);
  writer.writeString(offsets[3], object.sentence);
}

SentenceAnalysis _sentenceAnalysisDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = SentenceAnalysis();
  object.analysis = reader.readString(offsets[0]);
  object.audioUrl = reader.readStringOrNull(offsets[1]);
  object.id = id;
  object.lastUpdated = reader.readDateTime(offsets[2]);
  object.sentence = reader.readString(offsets[3]);
  return object;
}

P _sentenceAnalysisDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readDateTime(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _sentenceAnalysisGetId(SentenceAnalysis object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _sentenceAnalysisGetLinks(SentenceAnalysis object) {
  return [];
}

void _sentenceAnalysisAttach(
    IsarCollection<dynamic> col, Id id, SentenceAnalysis object) {
  object.id = id;
}

extension SentenceAnalysisByIndex on IsarCollection<SentenceAnalysis> {
  Future<SentenceAnalysis?> getBySentence(String sentence) {
    return getByIndex(r'sentence', [sentence]);
  }

  SentenceAnalysis? getBySentenceSync(String sentence) {
    return getByIndexSync(r'sentence', [sentence]);
  }

  Future<bool> deleteBySentence(String sentence) {
    return deleteByIndex(r'sentence', [sentence]);
  }

  bool deleteBySentenceSync(String sentence) {
    return deleteByIndexSync(r'sentence', [sentence]);
  }

  Future<List<SentenceAnalysis?>> getAllBySentence(
      List<String> sentenceValues) {
    final values = sentenceValues.map((e) => [e]).toList();
    return getAllByIndex(r'sentence', values);
  }

  List<SentenceAnalysis?> getAllBySentenceSync(List<String> sentenceValues) {
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

  Future<Id> putBySentence(SentenceAnalysis object) {
    return putByIndex(r'sentence', object);
  }

  Id putBySentenceSync(SentenceAnalysis object, {bool saveLinks = true}) {
    return putByIndexSync(r'sentence', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllBySentence(List<SentenceAnalysis> objects) {
    return putAllByIndex(r'sentence', objects);
  }

  List<Id> putAllBySentenceSync(List<SentenceAnalysis> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'sentence', objects, saveLinks: saveLinks);
  }
}

extension SentenceAnalysisQueryWhereSort
    on QueryBuilder<SentenceAnalysis, SentenceAnalysis, QWhere> {
  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension SentenceAnalysisQueryWhere
    on QueryBuilder<SentenceAnalysis, SentenceAnalysis, QWhereClause> {
  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterWhereClause>
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

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterWhereClause> idBetween(
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

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterWhereClause>
      sentenceEqualTo(String sentence) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'sentence',
        value: [sentence],
      ));
    });
  }

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterWhereClause>
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

extension SentenceAnalysisQueryFilter
    on QueryBuilder<SentenceAnalysis, SentenceAnalysis, QFilterCondition> {
  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterFilterCondition>
      analysisEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'analysis',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterFilterCondition>
      analysisGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'analysis',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterFilterCondition>
      analysisLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'analysis',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterFilterCondition>
      analysisBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'analysis',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterFilterCondition>
      analysisStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'analysis',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterFilterCondition>
      analysisEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'analysis',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterFilterCondition>
      analysisContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'analysis',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterFilterCondition>
      analysisMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'analysis',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterFilterCondition>
      analysisIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'analysis',
        value: '',
      ));
    });
  }

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterFilterCondition>
      analysisIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'analysis',
        value: '',
      ));
    });
  }

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterFilterCondition>
      audioUrlIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'audioUrl',
      ));
    });
  }

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterFilterCondition>
      audioUrlIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'audioUrl',
      ));
    });
  }

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterFilterCondition>
      audioUrlEqualTo(
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

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterFilterCondition>
      audioUrlGreaterThan(
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

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterFilterCondition>
      audioUrlLessThan(
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

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterFilterCondition>
      audioUrlBetween(
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

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterFilterCondition>
      audioUrlStartsWith(
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

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterFilterCondition>
      audioUrlEndsWith(
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

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterFilterCondition>
      audioUrlContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'audioUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterFilterCondition>
      audioUrlMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'audioUrl',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterFilterCondition>
      audioUrlIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'audioUrl',
        value: '',
      ));
    });
  }

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterFilterCondition>
      audioUrlIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'audioUrl',
        value: '',
      ));
    });
  }

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterFilterCondition>
      idGreaterThan(
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

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterFilterCondition>
      idLessThan(
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

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterFilterCondition>
      idBetween(
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

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterFilterCondition>
      lastUpdatedEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastUpdated',
        value: value,
      ));
    });
  }

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterFilterCondition>
      lastUpdatedGreaterThan(
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

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterFilterCondition>
      lastUpdatedLessThan(
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

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterFilterCondition>
      lastUpdatedBetween(
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

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterFilterCondition>
      sentenceEqualTo(
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

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterFilterCondition>
      sentenceGreaterThan(
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

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterFilterCondition>
      sentenceLessThan(
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

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterFilterCondition>
      sentenceBetween(
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

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterFilterCondition>
      sentenceStartsWith(
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

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterFilterCondition>
      sentenceEndsWith(
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

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterFilterCondition>
      sentenceContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'sentence',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterFilterCondition>
      sentenceMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'sentence',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterFilterCondition>
      sentenceIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sentence',
        value: '',
      ));
    });
  }

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterFilterCondition>
      sentenceIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'sentence',
        value: '',
      ));
    });
  }
}

extension SentenceAnalysisQueryObject
    on QueryBuilder<SentenceAnalysis, SentenceAnalysis, QFilterCondition> {}

extension SentenceAnalysisQueryLinks
    on QueryBuilder<SentenceAnalysis, SentenceAnalysis, QFilterCondition> {}

extension SentenceAnalysisQuerySortBy
    on QueryBuilder<SentenceAnalysis, SentenceAnalysis, QSortBy> {
  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterSortBy>
      sortByAnalysis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'analysis', Sort.asc);
    });
  }

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterSortBy>
      sortByAnalysisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'analysis', Sort.desc);
    });
  }

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterSortBy>
      sortByAudioUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'audioUrl', Sort.asc);
    });
  }

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterSortBy>
      sortByAudioUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'audioUrl', Sort.desc);
    });
  }

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterSortBy>
      sortByLastUpdated() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUpdated', Sort.asc);
    });
  }

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterSortBy>
      sortByLastUpdatedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUpdated', Sort.desc);
    });
  }

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterSortBy>
      sortBySentence() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sentence', Sort.asc);
    });
  }

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterSortBy>
      sortBySentenceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sentence', Sort.desc);
    });
  }
}

extension SentenceAnalysisQuerySortThenBy
    on QueryBuilder<SentenceAnalysis, SentenceAnalysis, QSortThenBy> {
  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterSortBy>
      thenByAnalysis() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'analysis', Sort.asc);
    });
  }

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterSortBy>
      thenByAnalysisDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'analysis', Sort.desc);
    });
  }

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterSortBy>
      thenByAudioUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'audioUrl', Sort.asc);
    });
  }

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterSortBy>
      thenByAudioUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'audioUrl', Sort.desc);
    });
  }

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterSortBy>
      thenByLastUpdated() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUpdated', Sort.asc);
    });
  }

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterSortBy>
      thenByLastUpdatedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUpdated', Sort.desc);
    });
  }

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterSortBy>
      thenBySentence() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sentence', Sort.asc);
    });
  }

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QAfterSortBy>
      thenBySentenceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sentence', Sort.desc);
    });
  }
}

extension SentenceAnalysisQueryWhereDistinct
    on QueryBuilder<SentenceAnalysis, SentenceAnalysis, QDistinct> {
  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QDistinct>
      distinctByAnalysis({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'analysis', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QDistinct>
      distinctByAudioUrl({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'audioUrl', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QDistinct>
      distinctByLastUpdated() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastUpdated');
    });
  }

  QueryBuilder<SentenceAnalysis, SentenceAnalysis, QDistinct>
      distinctBySentence({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sentence', caseSensitive: caseSensitive);
    });
  }
}

extension SentenceAnalysisQueryProperty
    on QueryBuilder<SentenceAnalysis, SentenceAnalysis, QQueryProperty> {
  QueryBuilder<SentenceAnalysis, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<SentenceAnalysis, String, QQueryOperations> analysisProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'analysis');
    });
  }

  QueryBuilder<SentenceAnalysis, String?, QQueryOperations> audioUrlProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'audioUrl');
    });
  }

  QueryBuilder<SentenceAnalysis, DateTime, QQueryOperations>
      lastUpdatedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastUpdated');
    });
  }

  QueryBuilder<SentenceAnalysis, String, QQueryOperations> sentenceProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sentence');
    });
  }
}
