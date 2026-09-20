import { extractLearningText } from './learning_text';
import { getVisibleLocator, VisibleLocator } from './visible_locator';

interface Point { x: number; y: number }
interface Gesture extends Point { pointerId: number; cancelled: boolean; sentenceSent: boolean; tapSent: boolean }
export type LearningMessage =
  | { version: 1; href: string; kind: 'word'; word: string; sentence: string }
  | { version: 1; href: string; kind: 'sentence'; sentence: string }
  | { version: 1; href: string; kind: 'controls' };
type Payload =
  | { kind: 'word'; word: string; sentence: string }
  | { kind: 'sentence'; sentence: string }
  | { kind: 'controls' };
interface MessagePort { postMessage(message: string): void }
interface BridgeWindow extends Window {
  flutterReadiumText?: MessagePort;
  webkit?: { messageHandlers?: { flutterReadiumText?: MessagePort } };
  synlenReadiumBridge?: { dispose(): void; getVisibleLocator(): VisibleLocator | null };
}
interface CaretDocument {
  caretPositionFromPoint?(x: number, y: number): { offsetNode: Node; offset: number } | null;
  caretRangeFromPoint?(x: number, y: number): Range | null;
}

const excluded = 'a, img, image, svg, math, button, input, textarea, select, option, label, summary, audio, video, iframe, object, embed, [contenteditable]:not([contenteditable="false"]), [role="button"], [role="link"]';
const editable = 'input, textarea, [contenteditable]:not([contenteditable="false"])';
const edgeWidth = 24;
const movementLimit = 10;
const holdDelay = 550;

/** 学习脚本只处理当前文档手势；原生桥补入可信的 sessionId 与 resourceHref。 */
export function installLearningBridge(window: BridgeWindow): { dispose(): void; getVisibleLocator(): VisibleLocator | null } {
  window.synlenReadiumBridge?.dispose();
  const document = window.document;
  const listeners: Array<() => void> = [];
  const pointers = new Set<number>();
  let gesture: Gesture | null = null;
  let completed: Gesture | null = null;
  let completedAt = 0;
  let timer: number | undefined;
  let disposed = false;

  const style = document.createElement('style');
  style.dataset.synlenLearning = 'true';
  style.textContent = 'html,body,body *{-webkit-user-select:none!important;user-select:none!important;-webkit-touch-callout:none!important}input,textarea,[contenteditable]:not([contenteditable="false"]){-webkit-user-select:text!important;user-select:text!important}';
  (document.head || document.documentElement).appendChild(style);

  function on<K extends keyof DocumentEventMap>(name: K, listener: (event: DocumentEventMap[K]) => void): void {
    document.addEventListener(name, listener, true);
    listeners.push(() => document.removeEventListener(name, listener, true));
  }
  function stopTimer(): void {
    if (timer !== undefined) window.clearTimeout(timer);
    timer = undefined;
  }
  function cancel(): void {
    stopTimer();
    if (gesture) gesture.cancelled = true;
  }
  function abandon(): void {
    cancel();
    if (gesture) {
      completed = gesture;
      completedAt = Date.now();
    }
    gesture = null;
    pointers.clear();
  }
  function element(target: EventTarget | null): Element | null {
    const node = target as Node | null;
    return node?.nodeType === 1 ? node as Element : node?.parentElement || null;
  }
  function eligible(event: MouseEvent): boolean {
    return event.clientX > edgeWidth && event.clientX < window.innerWidth - edgeWidth &&
      !element(event.target)?.closest(excluded);
  }
  function consume(event: Event): void {
    event.preventDefault();
    event.stopImmediatePropagation();
  }
  function emit(payload: Payload): boolean {
    if (disposed || document.visibilityState === 'hidden') return false;
    const port = window.flutterReadiumText || window.webkit?.messageHandlers?.flutterReadiumText;
    if (!port) return false;
    // href 仅用于诊断；会话身份与书内资源路径必须由原生层覆盖，不能信任书籍脚本。
    port.postMessage(JSON.stringify({ version: 1, href: document.URL, ...payload } satisfies LearningMessage));
    return true;
  }
  function extract(point: Point) {
    const doc = document as CaretDocument;
    let range = doc.caretRangeFromPoint?.(point.x, point.y) || null;
    if (!range) {
      const caret = doc.caretPositionFromPoint?.(point.x, point.y);
      if (caret) {
        range = document.createRange();
        range.setStart(caret.offsetNode, caret.offset);
        range.collapse(true);
      }
    }
    return range ? extractLearningText(range, point) : null;
  }

  on('pointerdown', event => {
    pointers.add(event.pointerId);
    if (pointers.size > 1 || !event.isPrimary || event.button !== 0) {
      cancel();
      return;
    }
    stopTimer();
    completed = null;
    gesture = null;
    if (!eligible(event)) return;
    gesture = { pointerId: event.pointerId, x: event.clientX, y: event.clientY, cancelled: false, sentenceSent: false, tapSent: false };
    const current = gesture;
    timer = window.setTimeout(() => {
      timer = undefined;
      if (gesture !== current || current.cancelled || pointers.size !== 1) return;
      const text = extract(current);
      if (text?.sentence) {
        document.getSelection()?.removeAllRanges();
        current.sentenceSent = emit({ kind: 'sentence', sentence: text.sentence });
      } else current.cancelled = true;
    }, holdDelay);
  });
  on('pointermove', event => {
    if (gesture && event.pointerId === gesture.pointerId &&
        Math.hypot(event.clientX - gesture.x, event.clientY - gesture.y) > movementLimit) cancel();
  });
  on('pointerup', event => {
    pointers.delete(event.pointerId);
    if (gesture?.pointerId !== event.pointerId) return;
    if (Math.hypot(event.clientX - gesture.x, event.clientY - gesture.y) > movementLimit) cancel();
    stopTimer();
    // 原生阅读器可能抑制兼容 click；短点在抬手时完成，随后 click 只去重。
    if (!gesture.cancelled && !gesture.sentenceSent && eligible(event)) {
      const text = extract({ x: event.clientX, y: event.clientY });
      gesture.tapSent = emit(text?.word
        ? { kind: 'word', word: text.word, sentence: text.sentence }
        : { kind: 'controls' });
    }
    if (gesture.tapSent || gesture.sentenceSent) consume(event);
    completed = gesture;
    completedAt = Date.now();
    gesture = null;
  });
  on('pointercancel', event => {
    pointers.delete(event.pointerId);
    cancel();
    if (gesture?.pointerId === event.pointerId) {
      completed = gesture;
      completedAt = Date.now();
      gesture = null;
    }
  });
  on('scroll', cancel);
  on('visibilitychange', abandon);
  on('click', event => {
    const last = completed;
    completed = null;
    if (!last || Date.now() - completedAt > 1000 || event.detail === 0) return;
    if (last.cancelled || last.sentenceSent || last.tapSent) consume(event);
  });
  on('selectstart', event => {
    if (!element(event.target)?.closest(editable)) consume(event);
  });
  on('selectionchange', () => {
    const selection = document.getSelection();
    if (selection?.rangeCount && !element(selection.anchorNode)?.closest(editable)) selection.removeAllRanges();
  });
  on('contextmenu', event => {
    if (!element(event.target)?.closest(excluded)) consume(event);
  });
  window.addEventListener('blur', abandon);
  window.addEventListener('pagehide', abandon);
  window.addEventListener('resize', abandon);
  const bridge = {
    getVisibleLocator(): VisibleLocator | null {
      return disposed ? null : getVisibleLocator(window);
    },
    dispose(): void {
      disposed = true;
      stopTimer();
      for (const remove of listeners) remove();
      window.removeEventListener('blur', abandon);
      window.removeEventListener('pagehide', abandon);
      window.removeEventListener('resize', abandon);
      style.remove();
      pointers.clear();
      gesture = completed = null;
      if (window.synlenReadiumBridge === bridge) delete window.synlenReadiumBridge;
    },
  };
  window.synlenReadiumBridge = bridge;
  return bridge;
}
