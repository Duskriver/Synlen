/// 学习查询：点词释义与长句分析共用的请求参数，也是 Riverpod family 的键。
///
/// [target] 是缓存与音频键使用的文本主体（单词或整句）；词侧额外携带上下文，
/// 用于释义缓存键与提示词。
sealed class LearningQuery {
  const LearningQuery();

  String get target;
}

/// 点词查询：[word] 为单词，[context] 为单词所在句子。
class WordLearningQuery extends LearningQuery {
  final String word;
  final String context;

  const WordLearningQuery({required this.word, required this.context});

  @override
  String get target => word;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is WordLearningQuery &&
            runtimeType == other.runtimeType &&
            word == other.word &&
            context == other.context;
  }

  @override
  int get hashCode => Object.hash(word, context);
}

/// 长句查询：[sentence] 为待分析的整句。
class SentenceLearningQuery extends LearningQuery {
  final String sentence;

  const SentenceLearningQuery({required this.sentence});

  @override
  String get target => sentence;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SentenceLearningQuery &&
            runtimeType == other.runtimeType &&
            sentence == other.sentence;
  }

  @override
  int get hashCode => sentence.hashCode;
}
