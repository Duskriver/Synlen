/// WebView 事件在进入阅读流程前完成结构校验；损坏或未知消息返回 null。
sealed class ReaderWebEvent {
  const ReaderWebEvent();

  static const handlers = [
    'onPageCountReady',
    'onPageChanged',
    'onScrollAnchors',
    'onTap',
    'onFootnoteTap',
    'onLinkTap',
    'onWordTap',
    'onSentenceSelected',
    'onImageLongPress',
    'onViewportResize',
    'onEventFinished',
  ];

  static ReaderWebEvent? decode(String name, List<dynamic> args) {
    switch ((name, args)) {
      case ('onPageCountReady', [int count]) when count >= 0:
        return ReaderPageCount(count);
      case ('onPageChanged', [int index]) when index >= 0:
        return ReaderPageChanged(index);
      case ('onScrollAnchors', [List<dynamic> anchors])
          when anchors.every((value) => value is String):
        return ReaderAnchors(anchors.cast<String>());
      case ('onTap', [num x, num y]) when x.isFinite && y.isFinite:
        return ReaderTap(x.toDouble(), y.toDouble());
      case ('onLinkTap', [String url, num x, num y])
          when x.isFinite && y.isFinite:
        return ReaderLink(url, x.toDouble(), y.toDouble());
      case (
            'onWordTap',
            [
              String word,
              String context,
              num x,
              num y,
              num w,
              num h,
              int requestId,
            ],
          )
          when _validRect(x, y, w, h) && w > 0 && h > 0 && requestId > 0:
        return ReaderWord(word, context, _rect(x, y, w, h), requestId);
      case ('onSentenceSelected', [String sentence]):
        return ReaderSentence(sentence);
      case ('onViewportResize', []):
        return const ReaderResize();
      case ('onEventFinished', [int token]):
        return ReaderEventFinished(token);
      case ('onImageLongPress', [String url, num x, num y, num w, num h])
          when _validRect(x, y, w, h):
        return ReaderImage(url, _rect(x, y, w, h));
      case (
            'onFootnoteTap',
            [String html, num x, num y, num w, num h, String base],
          )
          when _validRect(x, y, w, h):
        return ReaderFootnote(html, _rect(x, y, w, h), base);
      default:
        return null;
    }
  }

  static bool _validRect(num x, num y, num w, num h) =>
      [x, y, w, h].every((value) => value.isFinite) && w >= 0 && h >= 0;
  static WebRect _rect(num x, num y, num w, num h) => (
    x: x.toDouble(),
    y: y.toDouble(),
    width: w.toDouble(),
    height: h.toDouble(),
  );
}

typedef WebRect = ({double x, double y, double width, double height});

final class ReaderPageCount extends ReaderWebEvent {
  const ReaderPageCount(this.count);
  final int count;
}

final class ReaderPageChanged extends ReaderWebEvent {
  const ReaderPageChanged(this.index);
  final int index;
}

final class ReaderAnchors extends ReaderWebEvent {
  const ReaderAnchors(this.anchors);
  final List<String> anchors;
}

final class ReaderTap extends ReaderWebEvent {
  const ReaderTap(this.x, this.y);
  final double x;
  final double y;
}

final class ReaderLink extends ReaderWebEvent {
  const ReaderLink(this.url, this.x, this.y);
  final String url;
  final double x;
  final double y;
}

final class ReaderWord extends ReaderWebEvent {
  const ReaderWord(this.word, this.context, this.rect, this.requestId);
  final String word;
  final String context;
  final WebRect rect;
  final int requestId;
}

final class ReaderSentence extends ReaderWebEvent {
  const ReaderSentence(this.sentence);
  final String sentence;
}

final class ReaderResize extends ReaderWebEvent {
  const ReaderResize();
}

final class ReaderEventFinished extends ReaderWebEvent {
  const ReaderEventFinished(this.token);
  final int token;
}

final class ReaderImage extends ReaderWebEvent {
  const ReaderImage(this.url, this.rect);
  final String url;
  final WebRect rect;
}

final class ReaderFootnote extends ReaderWebEvent {
  const ReaderFootnote(this.html, this.rect, this.baseUrl);
  final String html;
  final WebRect rect;
  final String baseUrl;
}
