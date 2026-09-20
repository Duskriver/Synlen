/// 单词释义的增量快照；null 表示对应部分尚未到达。
class WordDefinition {
  final WordSummary? summary;
  final String? explanation;
  final List<WordSynonym>? synonyms;
  final String? formation;

  const WordDefinition({
    this.summary,
    this.explanation,
    this.synonyms,
    this.formation,
  });

  bool get isComplete =>
      summary != null &&
      explanation != null &&
      synonyms != null &&
      formation != null;
}

class WordSummary {
  final String lemma;

  /// 被点击词形的音标，与原词朗读对应；无可靠音标时为 null。
  final String? phonetic;
  final String partOfSpeech;
  final String definitionEn;
  final String definitionZh;

  const WordSummary({
    required this.lemma,
    required this.phonetic,
    required this.partOfSpeech,
    required this.definitionEn,
    required this.definitionZh,
  });
}

class WordSynonym {
  final String word;
  final String meaning;
  final String distinction;

  const WordSynonym({
    required this.word,
    required this.meaning,
    required this.distinction,
  });
}
