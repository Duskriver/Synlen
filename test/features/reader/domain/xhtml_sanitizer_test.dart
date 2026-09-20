import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/features/reader/domain/xhtml_sanitizer.dart';

void main() {
  group('sanitizeBookXhtml <script> 剥离', () {
    test('成对标签连同内容一起剥离', () {
      expect(
        sanitizeBookXhtml('<p>a</p><script>alert(1)</script><p>b</p>'),
        '<p>a</p><p>b</p>',
      );
    });

    test('自闭合 script 标签剥离', () {
      expect(
        sanitizeBookXhtml('<p>a</p><script src="evil.js"/><p>b</p>'),
        '<p>a</p><p>b</p>',
      );
      expect(sanitizeBookXhtml('<script src="evil.js" /><p>b</p>'), '<p>b</p>');
    });

    test('带属性的 script 标签剥离', () {
      expect(
        sanitizeBookXhtml(
          '<script type="text/javascript" src="x.js">alert(1)</script>',
        ),
        '',
      );
    });

    test('大小写混杂的 script 标签剥离', () {
      expect(sanitizeBookXhtml('<ScRiPt>alert(1)</sCrIpT>'), '');
      expect(sanitizeBookXhtml('<SCRIPT SRC="x.js"></SCRIPT>'), '');
    });

    test('script 属性值含 > 时引号感知', () {
      expect(
        sanitizeBookXhtml('<script data-x="a>b">alert(1)</script><p>ok</p>'),
        '<p>ok</p>',
      );
    });

    test('SVG 内的 script 剥离', () {
      expect(
        sanitizeBookXhtml(
          '<svg xmlns="http://www.w3.org/2000/svg">'
          '<script>alert(1)</script><rect width="1"/></svg>',
        ),
        '<svg xmlns="http://www.w3.org/2000/svg"><rect width="1"/></svg>',
      );
    });

    test('带命名空间前缀的 script 剥离', () {
      expect(
        sanitizeBookXhtml(
          '<svg:script xmlns:svg="urn:x">alert(1)</svg:script>',
        ),
        '',
      );
    });

    test('带前缀的 script 闭合后保留 SVG 元素与正文', () {
      const before =
          '<html xmlns="http://www.w3.org/1999/xhtml"><body>'
          '<svg:svg xmlns:svg="http://www.w3.org/2000/svg">';
      const after =
          '<svg:rect width="10" height="10"/></svg:svg>'
          '<p>正文应保留</p></body></html>';
      expect(
        sanitizeBookXhtml('$before<svg:script>void 0</svg:script>$after'),
        '$before$after',
      );
    });

    test('带前缀的 script 按完整标签名闭合且支持大小写混杂', () {
      expect(
        sanitizeBookXhtml(
          '<SVG:ScRiPt>"</script>"; void 0</svg:sCrIpT><p>正文</p>',
        ),
        '<p>正文</p>',
      );
    });

    test('未闭合的 script 丢弃到文末', () {
      expect(sanitizeBookXhtml('<p>a</p><script>alert(1)'), '<p>a</p>');
    });
  });

  group('sanitizeBookXhtml on* 属性剥离', () {
    test('双引号、单引号、无引号的 on* 属性都剥离', () {
      expect(
        sanitizeBookXhtml(
          '<body onload="a()" onclick=\'b()\' onerror=c()><p>x</p></body>',
        ),
        '<body><p>x</p></body>',
      );
    });

    test('大小写混杂的 On* 属性剥离', () {
      expect(
        sanitizeBookXhtml('<img src="a.png" OnLoad="a()">'),
        '<img src="a.png">',
      );
    });

    test('保留非 on* 属性且逐字节不变', () {
      const input = '<a  href="ch1.xhtml"  class=\'x\' id = "top">t</a>';
      expect(sanitizeBookXhtml(input), input);
    });

    test('属性值里出现的 onload 文本不误伤', () {
      const input = '<p title="onload=evil()">x</p>';
      expect(sanitizeBookXhtml(input), input);
    });

    test('紧邻自闭合斜杠的无引号 on* 属性剥离后保住斜杠', () {
      expect(sanitizeBookXhtml('<img onerror=alert(1)/>'), '<img/>');
    });

    test('无引号普通属性值里的 / 不误判为自闭合', () {
      const input = '<a href=/path/to>x</a>';
      expect(sanitizeBookXhtml(input), input);
    });

    test('SVG 根元素上的 onload 剥离', () {
      expect(
        sanitizeBookXhtml('<svg onload="alert(1)"><rect/></svg>'),
        '<svg><rect/></svg>',
      );
    });
  });

  group('sanitizeBookXhtml 保留区', () {
    test('转义的 &lt;script&gt; 正文原样保留', () {
      const input = '<p>&lt;script&gt;alert(1)&lt;/script&gt;</p>';
      expect(sanitizeBookXhtml(input), input);
    });

    test('注释里的 <script> 原样保留', () {
      const input = '<!-- <script>alert(1)</script> --><p>x</p>';
      expect(sanitizeBookXhtml(input), input);
    });

    test('CDATA 里的 <script> 原样保留', () {
      const input = '<style><![CDATA[a <script> b]]></style>';
      expect(sanitizeBookXhtml(input), input);
    });

    test('style 元素内容里的 <script> 文本原样保留', () {
      const input = '<style>.x::before { content: "<script>"; }</style>';
      expect(sanitizeBookXhtml(input), input);
    });

    test('其他标签属性值里的 <script> 文本原样保留', () {
      const input = '<p title="<script>">x</p>';
      expect(sanitizeBookXhtml(input), input);
    });

    test('DOCTYPE 与 XML 声明原样保留', () {
      const input =
          '<?xml version="1.0"?><!DOCTYPE html><html><body>x</body></html>';
      expect(sanitizeBookXhtml(input), input);
    });

    test('文本中孤立的 < 原样保留', () {
      const input = '<p>1 < 2</p>';
      expect(sanitizeBookXhtml(input), input);
    });

    test('无脚本内容时输出与输入逐字节一致', () {
      const input =
          '<html xmlns="http://www.w3.org/1999/xhtml"><head>'
          '<meta charset="utf-8"/></head><body><h2>标题</h2>'
          '<p>正文 &amp; 符号</p><img src="a.png" alt="图"/></body></html>';
      expect(sanitizeBookXhtml(input), input);
    });
  });

  group('needsScriptStripping', () {
    test('XHTML/HTML/XML/SVG 需要剥离', () {
      for (final mime in [
        'text/html',
        'application/xhtml+xml',
        'application/xml',
        'text/xml',
        'image/svg+xml',
      ]) {
        expect(needsScriptStripping(mime), isTrue, reason: mime);
      }
    });

    test('图片、字体、CSS、JS 等二进制或纯文本资源不剥离', () {
      for (final mime in [
        'text/css',
        'image/png',
        'image/jpeg',
        'font/woff2',
        'application/javascript',
        'application/octet-stream',
      ]) {
        expect(needsScriptStripping(mime), isFalse, reason: mime);
      }
    });
  });
}
