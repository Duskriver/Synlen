// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'word_explanation.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetWordExplanationCollection on Isar {
  IsarCollection<WordExplanation> get wordExplanations => this.collection();
}

const WordExplanationSchema = CollectionSchema(
  name: r'WordExplanation',
  id: 5127714445554109100,
  properties: {
    r'audioUrl': PropertySchema(
      id: 0,
      name: r'audioUrl',
      type: IsarType.string,
    ),
    r'context': PropertySchema(
      id: 1,
      name: r'context',
      type: IsarType.string,
    ),
    r'explanation': PropertySchema(
      id: 2,
      name: r'explanation',
      type: IsarType.string,
    ),
    r'lastUpdated': PropertySchema(
      id: 3,
      name: r'lastUpdated',
      type: IsarType.dateTime,
    ),
    r'word': PropertySchema(
      id: 4,
      name: r'word',
      type: IsarType.string,
    )
  },
  estimateSize: _wordExplanationEstimateSize,
  serialize: _wordExplanationSerialize,
  deserialize: _wordExplanationDeserialize,
  deserializeProp: _wordExplanationDeserializeProp,
  idName: r'id',
  indexes: {
    r'word': IndexSchema(
      id: -2031626334120420267,
      name: r'word',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'word',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _wordExplanationGetId,
  getLinks: _wordExplanationGetLinks,
  attach: _wordExplanationAttach,
  version: '3.1.0+1',
);

int _wordExplanationEstimateSize(
  WordExplanation object,
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
  {
    final value = object.context;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.explanation.length * 3;
  bytesCount += 3 + object.word.length * 3;
  return bytesCount;
}

void _wordExplanationSerialize(
  WordExplanation object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.audioUrl);
  writer.writeString(offsets[1], object.context);
  writer.writeString(offsets[2], object.explanation);
  writer.writeDateTime(offsets[3], object.lastUpdated);
  writer.writeString(offsets[4], object.word);
}

WordExplanation _wordExplanationDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = WordExplanation();
  object.audioUrl = reader.readStringOrNull(offsets[0]);
  object.context = reader.readStringOrNull(offsets[1]);
  object.explanation = reader.readString(offsets[2]);
  object.id = id;
  object.lastUpdated = reader.readDateTime(offsets[3]);
  object.word = reader.readString(offsets[4]);
  return object;
}

P _wordExplanationDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringOrNull(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readDateTime(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _wordExplanationGetId(WordExplanation object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _wordExplanationGetLinks(WordExplanation object) {
  return [];
}

void _wordExplanationAttach(
    IsarCollection<dynamic> col, Id id, WordExplanation object) {
  object.id = id;
}

extension WordExplanationByIndex on IsarCollection<WordExplanation> {
  Future<WordExplanation?> getByWord(String word) {
    return getByIndex(r'word', [word]);
  }

  WordExplanation? getByWordSync(String word) {
    return getByIndexSync(r'word', [word]);
  }

  Future<bool> deleteByWord(String word) {
    return deleteByIndex(r'word', [word]);
  }

  bool deleteByWordSync(String word) {
    return deleteByIndexSync(r'word', [word]);
  }

  Future<List<WordExplanation?>> getAllByWord(List<String> wordValues) {
    final values = wordValues.map((e) => [e]).toList();
    return getAllByIndex(r'word', values);
  }

  List<WordExplanation?> getAllByWordSync(List<String> wordValues) {
    final values = wordValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'word', values);
  }

  Future<int> deleteAllByWord(List<String> wordValues) {
    final values = wordValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'word', values);
  }

  int deleteAllByWordSync(List<String> wordValues) {
    final values = wordValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'word', values);
  }

  Future<Id> putByWord(WordExplanation object) {
    return putByIndex(r'word', object);
  }

  Id putByWordSync(WordExplanation object, {bool saveLinks = true}) {
    return putByIndexSync(r'word', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByWord(List<WordExplanation> objects) {
    return putAllByIndex(r'word', objects);
  }

  List<Id> putAllByWordSync(List<WordExplanation> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'word', objects, saveLinks: saveLinks);
  }
}

extension WordExplanationQueryWhereSort
    on QueryBuilder<WordExplanation, WordExplanation, QWhere> {
  QueryBuilder<WordExplanation, WordExplanation, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension WordExplanationQueryWhere
    on QueryBuilder<WordExplanation, WordExplanation, QWhereClause> {
  QueryBuilder<WordExplanation, WordExplanation, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterWhereClause>
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

  QueryBuilder<WordExplanation, WordExplanation, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterWhereClause> idLessThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterWhereClause> idBetween(
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

  QueryBuilder<WordExplanation, WordExplanation, QAfterWhereClause> wordEqualTo(
      String word) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'word',
        value: [word],
      ));
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterWhereClause>
      wordNotEqualTo(String word) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'word',
              lower: [],
              upper: [word],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'word',
              lower: [word],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'word',
              lower: [word],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'word',
              lower: [],
              upper: [word],
              includeUpper: false,
            ));
      }
    });
  }
}

extension WordExplanationQueryFilter
    on QueryBuilder<WordExplanation, WordExplanation, QFilterCondition> {
  QueryBuilder<WordExplanation, WordExplanation, QAfterFilterCondition>
      audioUrlIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'audioUrl',
      ));
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterFilterCondition>
      audioUrlIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'audioUrl',
      ));
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterFilterCondition>
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

  QueryBuilder<WordExplanation, WordExplanation, QAfterFilterCondition>
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

  QueryBuilder<WordExplanation, WordExplanation, QAfterFilterCondition>
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

  QueryBuilder<WordExplanation, WordExplanation, QAfterFilterCondition>
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

  QueryBuilder<WordExplanation, WordExplanation, QAfterFilterCondition>
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

  QueryBuilder<WordExplanation, WordExplanation, QAfterFilterCondition>
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

  QueryBuilder<WordExplanation, WordExplanation, QAfterFilterCondition>
      audioUrlContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'audioUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterFilterCondition>
      audioUrlMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'audioUrl',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterFilterCondition>
      audioUrlIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'audioUrl',
        value: '',
      ));
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterFilterCondition>
      audioUrlIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'audioUrl',
        value: '',
      ));
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterFilterCondition>
      contextIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'context',
      ));
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterFilterCondition>
      contextIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'context',
      ));
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterFilterCondition>
      contextEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'context',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterFilterCondition>
      contextGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'context',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterFilterCondition>
      contextLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'context',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterFilterCondition>
      contextBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'context',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterFilterCondition>
      contextStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'context',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterFilterCondition>
      contextEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'context',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterFilterCondition>
      contextContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'context',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterFilterCondition>
      contextMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'context',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterFilterCondition>
      contextIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'context',
        value: '',
      ));
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterFilterCondition>
      contextIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'context',
        value: '',
      ));
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterFilterCondition>
      explanationEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'explanation',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterFilterCondition>
      explanationGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'explanation',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterFilterCondition>
      explanationLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'explanation',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterFilterCondition>
      explanationBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'explanation',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterFilterCondition>
      explanationStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'explanation',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterFilterCondition>
      explanationEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'explanation',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterFilterCondition>
      explanationContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'explanation',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterFilterCondition>
      explanationMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'explanation',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterFilterCondition>
      explanationIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'explanation',
        value: '',
      ));
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterFilterCondition>
      explanationIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'explanation',
        value: '',
      ));
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterFilterCondition>
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

  QueryBuilder<WordExplanation, WordExplanation, QAfterFilterCondition>
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

  QueryBuilder<WordExplanation, WordExplanation, QAfterFilterCondition>
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

  QueryBuilder<WordExplanation, WordExplanation, QAfterFilterCondition>
      lastUpdatedEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastUpdated',
        value: value,
      ));
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterFilterCondition>
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

  QueryBuilder<WordExplanation, WordExplanation, QAfterFilterCondition>
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

  QueryBuilder<WordExplanation, WordExplanation, QAfterFilterCondition>
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

  QueryBuilder<WordExplanation, WordExplanation, QAfterFilterCondition>
      wordEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'word',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterFilterCondition>
      wordGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'word',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterFilterCondition>
      wordLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'word',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterFilterCondition>
      wordBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'word',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterFilterCondition>
      wordStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'word',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterFilterCondition>
      wordEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'word',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterFilterCondition>
      wordContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'word',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterFilterCondition>
      wordMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'word',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterFilterCondition>
      wordIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'word',
        value: '',
      ));
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterFilterCondition>
      wordIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'word',
        value: '',
      ));
    });
  }
}

extension WordExplanationQueryObject
    on QueryBuilder<WordExplanation, WordExplanation, QFilterCondition> {}

extension WordExplanationQueryLinks
    on QueryBuilder<WordExplanation, WordExplanation, QFilterCondition> {}

extension WordExplanationQuerySortBy
    on QueryBuilder<WordExplanation, WordExplanation, QSortBy> {
  QueryBuilder<WordExplanation, WordExplanation, QAfterSortBy>
      sortByAudioUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'audioUrl', Sort.asc);
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterSortBy>
      sortByAudioUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'audioUrl', Sort.desc);
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterSortBy> sortByContext() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'context', Sort.asc);
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterSortBy>
      sortByContextDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'context', Sort.desc);
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterSortBy>
      sortByExplanation() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'explanation', Sort.asc);
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterSortBy>
      sortByExplanationDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'explanation', Sort.desc);
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterSortBy>
      sortByLastUpdated() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUpdated', Sort.asc);
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterSortBy>
      sortByLastUpdatedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUpdated', Sort.desc);
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterSortBy> sortByWord() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'word', Sort.asc);
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterSortBy>
      sortByWordDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'word', Sort.desc);
    });
  }
}

extension WordExplanationQuerySortThenBy
    on QueryBuilder<WordExplanation, WordExplanation, QSortThenBy> {
  QueryBuilder<WordExplanation, WordExplanation, QAfterSortBy>
      thenByAudioUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'audioUrl', Sort.asc);
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterSortBy>
      thenByAudioUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'audioUrl', Sort.desc);
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterSortBy> thenByContext() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'context', Sort.asc);
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterSortBy>
      thenByContextDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'context', Sort.desc);
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterSortBy>
      thenByExplanation() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'explanation', Sort.asc);
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterSortBy>
      thenByExplanationDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'explanation', Sort.desc);
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterSortBy>
      thenByLastUpdated() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUpdated', Sort.asc);
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterSortBy>
      thenByLastUpdatedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUpdated', Sort.desc);
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterSortBy> thenByWord() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'word', Sort.asc);
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QAfterSortBy>
      thenByWordDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'word', Sort.desc);
    });
  }
}

extension WordExplanationQueryWhereDistinct
    on QueryBuilder<WordExplanation, WordExplanation, QDistinct> {
  QueryBuilder<WordExplanation, WordExplanation, QDistinct> distinctByAudioUrl(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'audioUrl', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QDistinct> distinctByContext(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'context', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QDistinct>
      distinctByExplanation({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'explanation', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QDistinct>
      distinctByLastUpdated() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastUpdated');
    });
  }

  QueryBuilder<WordExplanation, WordExplanation, QDistinct> distinctByWord(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'word', caseSensitive: caseSensitive);
    });
  }
}

extension WordExplanationQueryProperty
    on QueryBuilder<WordExplanation, WordExplanation, QQueryProperty> {
  QueryBuilder<WordExplanation, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<WordExplanation, String?, QQueryOperations> audioUrlProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'audioUrl');
    });
  }

  QueryBuilder<WordExplanation, String?, QQueryOperations> contextProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'context');
    });
  }

  QueryBuilder<WordExplanation, String, QQueryOperations>
      explanationProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'explanation');
    });
  }

  QueryBuilder<WordExplanation, DateTime, QQueryOperations>
      lastUpdatedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastUpdated');
    });
  }

  QueryBuilder<WordExplanation, String, QQueryOperations> wordProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'word');
    });
  }
}
