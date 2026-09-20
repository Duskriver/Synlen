import 'dart:convert';

/// 原生桥接的有界消息；校验失败不会进入学习或导航用例。
class ReadiumInteraction {
  const ReadiumInteraction({required this.kind, this.word, this.sentence});
  final String kind;
  final String? word;
  final String? sentence;

  static ReadiumInteraction? parse(
    String payload, {
    required String sessionId,
    required String currentHref,
  }) {
    if (payload.length > 65536) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(payload);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic> ||
        decoded['version'] != 1 ||
        decoded['sessionId'] != sessionId ||
        decoded['resourceHref'] is! String ||
        resourcePath(currentHref).isEmpty ||
        resourcePath(decoded['resourceHref'] as String) !=
            resourcePath(currentHref)) {
      return null;
    }
    final kind = decoded['kind'];
    if (kind == 'controls') return const ReadiumInteraction(kind: 'controls');
    final sentence = decoded['sentence'];
    if (sentence is! String ||
        sentence.trim().isEmpty ||
        sentence.length > 16000) {
      return null;
    }
    if (kind == 'sentence') {
      return ReadiumInteraction(kind: 'sentence', sentence: sentence);
    }
    final word = decoded['word'];
    if (kind != 'word' ||
        word is! String ||
        word.trim().isEmpty ||
        word.length > 512) {
      return null;
    }
    return ReadiumInteraction(kind: 'word', word: word, sentence: sentence);
  }
}

/// Readium 的相对资源路径与百分号编码统一后比较，不把临时资源域名写入进度。
String resourcePath(String href) {
  final uri = Uri.tryParse(href);
  if (uri == null || uri.hasScheme || uri.hasAuthority) return '';
  try {
    return uri.pathSegments
        .where((part) => part.isNotEmpty && part != '.')
        .join('/');
  } on FormatException {
    return '';
  }
}
