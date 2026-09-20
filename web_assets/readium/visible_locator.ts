export interface VisibleLocator {
  locations: { cssSelector: string };
  text: { before: string; highlight: string; after: string };
}

interface LocatorWindow extends Window {
  readium?: { findFirstVisibleLocator?(): { locations?: { cssSelector?: string } } | null };
}

const ignored = 'script,style,noscript,template,rt,rp,svg,math,audio,video,canvas,iframe,object,embed,input,textarea,select,button,[contenteditable]:not([contenteditable="false"])';

function contextSlice(text: string, start: number, end: number): string {
  // 缩短边界以保留完整代理对；锚点本身仍使用原始 UTF-16 偏移。
  if (/[\uDC00-\uDFFF]/.test(text[start] || '') && /[\uD800-\uDBFF]/.test(text[start - 1] || '')) start++;
  if (/[\uD800-\uDBFF]/.test(text[end - 1] || '') && /[\uDC00-\uDFFF]/.test(text[end] || '')) end--;
  return text.slice(start, end);
}

/** 在 SDK 给出的可见块内细化文字锚点；不改变分页或滚动位置。 */
export function getVisibleLocator(window: LocatorWindow): VisibleLocator | null {
  const document = window.document;
  if (!document.body || document.visibilityState === 'hidden') return null;
  let preferred: Element | null = null;
  let preferredSelector: string | undefined;
  try {
    preferredSelector = window.readium?.findFirstVisibleLocator?.()?.locations?.cssSelector;
    if (preferredSelector) preferred = document.querySelector(preferredSelector);
  } catch { /* SDK 尚未就绪或书籍选择器无效时扫描正文。 */ }

  function hidden(element: Element): boolean {
    for (let parent: Element | null = element; parent; parent = parent.parentElement) {
      const style = window.getComputedStyle(parent);
      if (parent.matches(ignored) || parent.hasAttribute('hidden') ||
          style.display === 'none' || style.visibility === 'hidden' ||
          style.visibility === 'collapse' || Number(style.opacity) === 0) return true;
    }
    return false;
  }
  function intersects(rect: DOMRect): boolean {
    return rect.width > 0 && rect.height > 0 && rect.right > 0 && rect.bottom > 0 &&
      rect.left < window.innerWidth && rect.top < window.innerHeight;
  }
  function contained(rect: DOMRect): boolean {
    return intersects(rect) && rect.left >= -0.5 && rect.top >= -0.5 &&
      rect.right <= window.innerWidth + 0.5 && rect.bottom <= window.innerHeight + 0.5;
  }
  function range(node: Text, start: number, end: number): Range {
    const result = document.createRange();
    result.setStart(node, start);
    result.setEnd(node, end);
    return result;
  }
  function visible(node: Text, start: number, end: number): boolean {
    const rects = Array.from(range(node, start, end).getClientRects()).filter(rect => rect.width > 0 && rect.height > 0);
    return rects.length > 0 && rects.every(contained);
  }
  function firstCharacter(node: Text, start: number, end: number): number | null {
    if (start >= end || !Array.from(range(node, start, end).getClientRects()).some(intersects)) return null;
    if (end - start <= 2) {
      for (let index = start; index < end; index++) {
        // Range 使用 UTF-16 偏移，避免将代理对截成两个锚点。
        if (index > 0 && /[\uDC00-\uDFFF]/.test(node.data[index])) continue;
        const size = node.data.codePointAt(index)! > 0xffff ? 2 : 1;
        if (/\S/.test(node.data.slice(index, index + size)) && visible(node, index, index + size)) return index;
      }
      return null;
    }
    const middle = start + Math.floor((end - start) / 2);
    return firstCharacter(node, start, middle) ?? firstCharacter(node, middle, end);
  }
  function selector(element: Element): string {
    const steps: string[] = [];
    for (let current: Element | null = element; current; current = current.parentElement) {
      if (!current.parentElement) return [':root', ...steps].join(' > ');
      steps.unshift(`:nth-child(${Array.from(current.parentElement.children).indexOf(current) + 1})`);
    }
    return ':root';
  }
  function find(root: Element, cssSelector: string): VisibleLocator | null {
    const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
    for (let current = walker.nextNode(); current; current = walker.nextNode()) {
      const node = current as Text;
      if (!node.parentElement || !/\S/.test(node.data) || hidden(node.parentElement)) continue;
      const start = firstCharacter(node, 0, node.length);
      if (start === null) continue;
      let end = start;
      while (end < node.length && end - start < 48 && !/\s/.test(node.data[end])) {
        const size = node.data.codePointAt(end)! > 0xffff ? 2 : 1;
        if (end + size - start > 48 || !visible(node, start, end + size)) break;
        end += size;
      }
      if (end === start) continue;
      // TextQuoteAnchor 搜索原始 textContent；不能采用学习文本的隐藏节点过滤或空白规整。
      const anchorRoot = node.parentElement;
      const anchorSelector = anchorRoot === root ? cssSelector : selector(anchorRoot);
      const prefix = document.createRange();
      prefix.selectNodeContents(anchorRoot);
      prefix.setEnd(node, start);
      const offset = prefix.toString().length;
      const text = anchorRoot.textContent || '';
      const before = contextSlice(text, Math.max(0, offset - 64), offset);
      const highlight = node.data.slice(start, end);
      const after = contextSlice(text, offset + end - start, Math.min(text.length, offset + end - start + 64));
      const quote = before + highlight + after;
      // 有限上下文仍重复时，宁可交回 SDK 的位置回退，也不保存会跳到另一处的假精确锚点。
      if (text.indexOf(quote) !== text.lastIndexOf(quote)) continue;
      return {
        locations: { cssSelector: anchorSelector },
        text: { before, highlight, after },
      };
    }
    return null;
  }
  if (preferred && preferredSelector) {
    const locator = find(preferred, preferredSelector);
    if (locator) return locator;
  }
  // 无 SDK 候选时以正文为搜索根；返回稳定结构选择器，避免给书籍增补 id。
  return find(document.body, selector(document.body));
}
