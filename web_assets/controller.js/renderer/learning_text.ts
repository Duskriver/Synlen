interface TextSpan { node: Text; start: number; end: number }
interface Bounds { start: number; end: number }
interface Point { x: number; y: number }
export interface LearningWordRect { x: number; y: number; width: number; height: number }

export interface LearningText {
  word: string | null;
  sentence: string;
  wordRect: LearningWordRect | null;
}

const letters = 'A-Za-zÀ-ÖØ-öø-ÿ';
const wordPattern = new RegExp(`[${letters}]+(?:['’\\-‐‑\\u00ad][${letters}]+)*`, 'g');
const blockTags = /^(BODY|P|DIV|LI|DT|DD|H[1-6]|TD|TH|PRE|BLOCKQUOTE|FIGCAPTION|SECTION|ARTICLE)$/;
const ignoredTags = /^(SCRIPT|STYLE|NOSCRIPT|TEMPLATE|RT|RP|SVG|MATH)$/;
const closers = /["'”’»\)\]\}]/;

function isBlock(element: Element): boolean {
  if (blockTags.test(element.tagName.toUpperCase())) return true;
  const display = element.ownerDocument.defaultView?.getComputedStyle(element).display;
  return !!display && /^(block|list-item|table-cell|flex|grid|flow-root)$/.test(display);
}

function hidden(element: Element): boolean {
  const style = element.ownerDocument.defaultView?.getComputedStyle(element);
  return element.hasAttribute('hidden') || style?.display === 'none' ||
    style?.visibility === 'hidden' || style?.visibility === 'collapse';
}

/** 在当前语义块建立文本与 DOM 偏移映射，不把内联标签当作句子边界。 */
function blockText(node: Text): { text: string; spans: TextSpan[] } | null {
  let root = node.parentElement;
  while (root && !isBlock(root)) root = root.parentElement;
  if (!root) return null;
  for (let parent: Element | null = node.parentElement; parent; parent = parent.parentElement) {
    if (hidden(parent) || ignoredTags.test(parent.tagName.toUpperCase())) return null;
  }
  let text = '';
  const spans: TextSpan[] = [];
  const visit = (current: Node): void => {
    if (current.nodeType === 3) {
      const value = current.textContent || '';
      spans.push({ node: current as Text, start: text.length, end: text.length + value.length });
      text += value;
      return;
    }
    if (current.nodeType !== 1) return;
    const element = current as Element;
    if (ignoredTags.test(element.tagName.toUpperCase()) || hidden(element)) return;
    if (element.tagName.toUpperCase() === 'BR') { text += '\n'; return; }
    const boundary = element !== root && isBlock(element);
    if (boundary) text += '\u2029';
    for (const child of Array.from(element.childNodes)) visit(child);
    if (boundary) text += '\u2029';
  };
  visit(root);
  return { text, spans };
}

function domRange(spans: TextSpan[], bounds: Bounds): Range | null {
  const first = spans.find(span => bounds.start >= span.start && bounds.start < span.end);
  const last = spans.find(span => bounds.end > span.start && bounds.end <= span.end);
  if (!first || !last) return null;
  const range = first.node.ownerDocument.createRange();
  range.setStart(first.node, bounds.start - first.start);
  range.setEnd(last.node, bounds.end - last.start);
  return range;
}

function containsPoint(range: Range | null, point: Point): boolean {
  return !!range && Array.from(range.getClientRects()).some(rect =>
    rect.width > 0 && rect.height > 0 && point.x >= rect.left && point.x <= rect.right &&
    point.y >= rect.top && point.y <= rect.bottom);
}

/** 只合并当前视口中可见的词片段，避免跨栏或换行的 Range 包围页外内容。 */
function visibleWordRect(range: Range | null): LearningWordRect | null {
  if (!range) return null;
  const doc = range.startContainer.ownerDocument!;
  const view = doc.defaultView;
  if (!view) return null;
  let left = 0, top = 0, right = view.innerWidth, bottom = view.innerHeight;
  let element = range.commonAncestorContainer.nodeType === 1
    ? range.commonAncestorContainer as Element : range.commonAncestorContainer.parentElement;
  for (; element; element = element.parentElement) {
    const style = view.getComputedStyle(element);
    const bounds = element.getBoundingClientRect();
    if (/^(auto|scroll|hidden|clip)$/.test(style.overflowX)) {
      left = Math.max(left, bounds.left); right = Math.min(right, bounds.right);
    }
    if (/^(auto|scroll|hidden|clip)$/.test(style.overflowY)) {
      top = Math.max(top, bounds.top); bottom = Math.min(bottom, bounds.bottom);
    }
  }
  const fragments = Array.from(range.getClientRects()).map(rect => ({
    left: Math.max(left, rect.left), top: Math.max(top, rect.top),
    right: Math.min(right, rect.right), bottom: Math.min(bottom, rect.bottom),
  })).filter(rect => rect.right > rect.left && rect.bottom > rect.top);
  if (!fragments.length) return null;
  const x = Math.min(...fragments.map(rect => rect.left));
  const y = Math.min(...fragments.map(rect => rect.top));
  return { x, y, width: Math.max(...fragments.map(rect => rect.right)) - x,
    height: Math.max(...fragments.map(rect => rect.bottom)) - y };
}

function sentenceBounds(text: string, offset: number): Bounds {
  let start = 0;
  for (let i = 0; i < text.length; i++) {
    const char = text[i];
    if (char === '\u2029') {
      if (offset <= i) return { start, end: i };
      start = i + 1;
      continue;
    }
    if (!/[.!?]/.test(char)) continue;
    let end = i + 1;
    while (end < text.length && /[.!?]/.test(text[end])) end++;
    const punctuationEnd = end;
    while (end < text.length && closers.test(text[end])) end++;
    if (end < text.length && !/\s/.test(text[end])) continue;
    const following = text.slice(end).match(/^\s*([A-Za-z]+)/)?.[1] || '';
    if (char === '.' && punctuationEnd === i + 1 && /\S/.test(text.slice(end))) {
      const prefix = text.slice(start, i);
      const token = prefix.match(/([A-Za-z.]+)$/)?.[1] || '';
      if (/^(Mr|Mrs|Ms|Dr|Prof|Sr|Jr|St|Mt|Gen|Rev|vs)$/i.test(token)) continue;
      if (/^[A-Z]$/.test(token)) continue;
      if (/^(e\.g|i\.e)$/i.test(token)) continue;
      if (/^(?:[A-Za-z]\.)+[A-Za-z]$/.test(token) && !/^(He|She|It|They|We|This|That|The|A|An|I)$/.test(following)) continue;
      if (/^(etc|approx|cf|fig|vol|no)$/i.test(token) && /^[a-z]/.test(following)) continue;
    }
    // 引文后的小写字母通常是同一句的引述语，例如 “Go!” she said.
    if (end > punctuationEnd && /^[a-z]/.test(following)) continue;
    if (offset < end) return { start, end };
    start = end;
    i = end - 1;
  }
  return { start, end: text.length };
}

/** 可选坐标用于排除浏览器把空白点击吸附到附近文字的情况。 */
export function extractLearningText(caret: Range, point?: Point): LearningText | null {
  if (caret.startContainer.nodeType !== 3) return null;
  const mapped = blockText(caret.startContainer as Text);
  if (!mapped) return null;
  const span = mapped.spans.find(item => item.node === caret.startContainer);
  if (!span) return null;
  const offset = span.start + caret.startOffset;
  let target = offset;
  if (point) {
    const character = [offset, offset - 1].find(index => index >= 0 && index < mapped.text.length &&
      !/\s/.test(mapped.text[index]) && containsPoint(domRange(mapped.spans, { start: index, end: index + 1 }), point));
    if (character === undefined) return null;
    target = character;
  }
  const bounds = sentenceBounds(mapped.text, target);
  const sentence = mapped.text.slice(bounds.start, bounds.end).replace(/\u00ad/g, '').replace(/\s+/g, ' ').trim();
  if (!sentence) return null;
  wordPattern.lastIndex = 0;
  let match: RegExpExecArray | null;
  let word: string | null = null;
  let wordRect: LearningWordRect | null = null;
  while ((match = wordPattern.exec(mapped.text))) {
    const end = match.index + match[0].length;
    if (target >= match.index && (target < end || (!point && target === end))) {
      word = match[0].replace(/\u00ad/g, '');
      wordRect = visibleWordRect(domRange(mapped.spans, { start: match.index, end }));
      break;
    }
  }
  return { word, sentence, wordRect };
}
