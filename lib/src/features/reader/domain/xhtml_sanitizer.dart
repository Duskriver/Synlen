/// 书内 XHTML 净化：剥离 `<script>` 元素与 `on*` 内联事件属性。
///
/// 书籍内容经 `book://` 虚拟域供进 WebView，书内脚本必须不可执行。
/// 骨架 iframe 的 `sandbox="allow-same-origin"` 是第一道防线，
/// 这里在供给层再剥离，不依赖 WebView 对 sandbox 的强制力。
///
/// 选型：不做完整 HTML/XML 解析往返——EPUB 的 XHTML 常含 HTML 具名实体
/// （`&nbsp;` 等），严格 XML 解析直接失败，重序列化还会改动与脚本无关的
/// 内容。这里用标签级扫描：注释、CDATA、DOCTYPE、处理指令原样保留，只在
/// 真实标签上工作；未被剥离的部分逐字节保持原样。
library;

/// 剥离 [source] 中的 `<script>` 元素（含 SVG 内的、带命名空间前缀的）
/// 与所有元素上的 `on*` 内联事件属性。无脚本内容时返回与输入相同的字符串。
String sanitizeBookXhtml(String source) {
  final out = StringBuffer();
  var i = 0;
  while (i < source.length) {
    final lt = source.indexOf('<', i);
    if (lt < 0) {
      out.write(source.substring(i));
      break;
    }
    out.write(source.substring(i, lt));

    if (source.startsWith('<!--', lt)) {
      i = _copyThrough(source, lt, '-->', out);
    } else if (source.startsWith('<![CDATA[', lt)) {
      i = _copyThrough(source, lt, ']]>', out);
    } else if (source.startsWith('<!', lt) || source.startsWith('<?', lt)) {
      // DOCTYPE、声明与处理指令：原样保留到 '>'
      i = _copyThrough(source, lt, '>', out);
    } else if (source.startsWith('</', lt)) {
      // 闭合标签无属性，原样保留
      i = _copyThrough(source, lt, '>', out);
    } else if (lt + 1 < source.length &&
        _isNameStart(source.codeUnitAt(lt + 1))) {
      i = _emitSanitizedTag(source, lt, out);
    } else {
      // 文本中的孤立 '<'（如 "a < b"）
      out.write('<');
      i = lt + 1;
    }
  }
  return out.toString();
}

/// 判断 [mimeType] 对应的书内容供给是否需要脚本剥离。
bool needsScriptStripping(String mimeType) {
  return mimeType == 'text/html' ||
      mimeType == 'application/xhtml+xml' ||
      mimeType == 'application/xml' ||
      mimeType == 'text/xml' ||
      mimeType == 'image/svg+xml';
}

/// 从 [start] 起原样拷贝到 [terminator] 之后，返回下一个待处理下标。
/// 找不到终结符时拷贝到文末。
int _copyThrough(
  String source,
  int start,
  String terminator,
  StringBuffer out,
) {
  final end = source.indexOf(terminator, start);
  if (end < 0) {
    out.write(source.substring(start));
    return source.length;
  }
  final after = end + terminator.length;
  out.write(source.substring(start, after));
  return after;
}

/// 处理 [lt] 处的开标签：`<script>` 整个丢弃，其余标签剥离 `on*` 属性后
/// 原样输出。返回标签之后的下标。
int _emitSanitizedTag(String source, int lt, StringBuffer out) {
  var i = lt + 1;
  final nameStart = i;
  while (i < source.length && _isNameChar(source.codeUnitAt(i))) {
    i++;
  }
  final localName = _localName(source.substring(nameStart, i));
  if (localName == 'script') {
    return _skipScriptElement(source, i);
  }

  // segStart 之后的内容尚未写出；丢弃属性时先写 [segStart, wsStart)，
  // 再把 segStart 推到属性之后，保证保留部分逐字节不变。
  var segStart = lt;
  while (i < source.length) {
    final wsStart = i;
    while (i < source.length && _isWhitespace(source.codeUnitAt(i))) {
      i++;
    }
    if (i >= source.length) break;
    final ch = source[i];
    if (ch == '>') {
      i++;
      out.write(source.substring(segStart, i));
      // style 是 raw text 元素：CSS 文本里出现的 "<script>" 不是标签
      if (localName == 'style') {
        return _copyRawTextElement(source, i, 'style', out);
      }
      return i;
    }
    if (ch == '/') {
      i++;
      if (i < source.length && source[i] == '>') {
        i++;
        out.write(source.substring(segStart, i));
        return i;
      }
      continue;
    }

    final attrStart = i;
    while (i < source.length && _isAttrNameChar(source.codeUnitAt(i))) {
      i++;
    }
    final attrName = source.substring(attrStart, i);
    while (i < source.length && _isWhitespace(source.codeUnitAt(i))) {
      i++;
    }
    if (i < source.length && source[i] == '=') {
      i++;
      while (i < source.length && _isWhitespace(source.codeUnitAt(i))) {
        i++;
      }
      if (i < source.length && (source[i] == '"' || source[i] == "'")) {
        final quote = source[i];
        i++;
        while (i < source.length && source[i] != quote) {
          i++;
        }
        if (i < source.length) i++;
      } else {
        // 无引号值止于空白或 '>'；紧邻 '>' 的 '/' 留给自闭合结尾，
        // 否则 XHTML 按 XML 解析时会因丢掉自闭合斜杠而 malformed
        while (i < source.length &&
            !_isWhitespace(source.codeUnitAt(i)) &&
            source[i] != '>' &&
            !(source[i] == '/' &&
                i + 1 < source.length &&
                source[i + 1] == '>')) {
          i++;
        }
      }
    }
    if (_isEventHandlerAttribute(attrName)) {
      out.write(source.substring(segStart, wsStart));
      segStart = i;
    }
  }

  // EOF 兜底：标签未闭合，剩余内容原样输出
  out.write(source.substring(segStart));
  return source.length;
}

/// 丢弃 `<script` 开标签的剩余部分（[i] 位于标签名之后）及其内容，
/// 直到配对的 `</script>`；自闭合或未闭合时直接返回。
int _skipScriptElement(String source, int i) {
  var selfClosing = false;
  var tagClosed = false;
  while (i < source.length) {
    final ch = source[i];
    if (ch == '"' || ch == "'") {
      i++;
      while (i < source.length && source[i] != ch) {
        i++;
      }
      if (i < source.length) i++;
      continue;
    }
    if (ch == '>') {
      var j = i - 1;
      while (j >= 0 && _isWhitespace(source.codeUnitAt(j))) {
        j--;
      }
      selfClosing = j >= 0 && source[j] == '/';
      i++;
      tagClosed = true;
      break;
    }
    i++;
  }
  if (!tagClosed || selfClosing) return i;

  // 与浏览器一致：脚本内容在第一个 </script 处结束
  final close = _indexOfClosingTag(source, i, 'script');
  if (close < 0) return source.length;
  final gt = source.indexOf('>', close);
  return gt < 0 ? source.length : gt + 1;
}

/// raw text 元素（`style`）的内容原样拷贝到配对的闭合标签之后。
int _copyRawTextElement(
  String source,
  int i,
  String localName,
  StringBuffer out,
) {
  final close = _indexOfClosingTag(source, i, localName);
  if (close < 0) {
    out.write(source.substring(i));
    return source.length;
  }
  final gt = source.indexOf('>', close);
  final after = gt < 0 ? source.length : gt + 1;
  out.write(source.substring(i, after));
  return after;
}

/// 从 [from] 起查找 `</$localName`（大小写不敏感）。
int _indexOfClosingTag(String source, int from, String localName) {
  final needle = '</$localName';
  final lastStart = source.length - needle.length;
  for (var i = from; i <= lastStart; i++) {
    var matched = true;
    for (var j = 0; j < needle.length; j++) {
      if (_lower(source.codeUnitAt(i + j)) != needle.codeUnitAt(j)) {
        matched = false;
        break;
      }
    }
    if (matched) return i;
  }
  return -1;
}

/// 标签名取本地名（去命名空间前缀）并转小写：`<svg:script>` 同样剥离。
String _localName(String name) {
  final colon = name.lastIndexOf(':');
  final local = colon < 0 ? name : name.substring(colon + 1);
  return local.toLowerCase();
}

/// HTML 的 on* 内联事件属性均以 "on" 开头，标准 HTML/SVG 中没有其他
/// 以 "on" 开头的合法属性。
bool _isEventHandlerAttribute(String attrName) {
  return attrName.length >= 2 &&
      _lower(attrName.codeUnitAt(0)) == 0x6F && // o
      _lower(attrName.codeUnitAt(1)) == 0x6E; // n
}

int _lower(int codeUnit) {
  return codeUnit >= 0x41 && codeUnit <= 0x5A ? codeUnit + 0x20 : codeUnit;
}

bool _isWhitespace(int codeUnit) {
  return codeUnit == 0x20 ||
      codeUnit == 0x09 ||
      codeUnit == 0x0A ||
      codeUnit == 0x0D ||
      codeUnit == 0x0C;
}

bool _isNameStart(int codeUnit) {
  return (codeUnit >= 0x41 && codeUnit <= 0x5A) ||
      (codeUnit >= 0x61 && codeUnit <= 0x7A);
}

bool _isNameChar(int codeUnit) {
  return _isNameStart(codeUnit) ||
      (codeUnit >= 0x30 && codeUnit <= 0x39) ||
      codeUnit == 0x3A || // :
      codeUnit == 0x2D || // -
      codeUnit == 0x5F || // _
      codeUnit == 0x2E; // .
}

bool _isAttrNameChar(int codeUnit) {
  return !_isWhitespace(codeUnit) &&
      codeUnit != 0x3D && // =
      codeUnit != 0x3E && // >
      codeUnit != 0x2F; // /
}
