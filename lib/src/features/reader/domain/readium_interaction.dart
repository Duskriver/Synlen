import 'dart:convert';

/// 原生阅读视口中的逻辑坐标；全局坐标转换归展示层。
typedef ReadiumWordRect = ({double x, double y, double width, double height});

/// 原生桥接的有界消息；校验失败不会进入学习或导航用例。
class ReadiumInteraction {
  const ReadiumInteraction({
    required this.kind,
    this.word,
    this.sentence,
    this.anchorRect,
  });
  final String kind;
  final String? word;
  final String? sentence;
  final ReadiumWordRect? anchorRect;

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
    final rect = decoded['anchorRect'];
    if (rect is! Map<String, dynamic>) return null;
    final x = rect['x'];
    final y = rect['y'];
    final width = rect['width'];
    final height = rect['height'];
    if (x is! num ||
        y is! num ||
        width is! num ||
        height is! num ||
        ![
          x,
          y,
          width,
          height,
          x + width,
          y + height,
        ].every((n) => n.isFinite) ||
        width <= 0 ||
        height <= 0) {
      return null;
    }
    return ReadiumInteraction(
      kind: 'word',
      word: word,
      sentence: sentence,
      anchorRect: (
        x: x.toDouble(),
        y: y.toDouble(),
        width: width.toDouble(),
        height: height.toDouble(),
      ),
    );
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
