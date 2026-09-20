import {
  waitForAllResources,
  polyfillCss,
} from './css_polyfill';
import type {
  FrameSlot,
  ReaderState,
  InitConfig,
  ThemeUpdate,
  Direction
} from '../common/types';
import { SynlenApi } from '../api/synlen_api';
import { FlutterBridge } from '../api/flutter_bridge';
import { applyTyp } from '../typ/typ';
import { FrameManager } from './frame_manager';
import { PaginationManager } from './pagination';
import { InteractionManager } from './interaction';
import { ThemeManager } from './theme_manager';

export class Renderer implements SynlenApi {
  private state: ReaderState;

  private frameMgr: FrameManager;
  private paginationMgr: PaginationManager;
  private interactionMgr: InteractionManager;
  private themeMgr: ThemeManager;

  private resizeDebounceTimer: ReturnType<typeof setTimeout> | null;
  private onResize: (ev: UIEvent) => void;
  private currentSize: { width: number; height: number } = { width: 0, height: 0 };

  constructor() {
    this.state = {
      anchors: { prev: [], curr: [], next: [] },
      properties: { prev: [], curr: [], next: [] },
      quadTree: null,
      config: {
        safeWidth: 0,
        safeHeight: 0,
        direction: 0,
        padding: { top: 0, left: 0 },
        theme: {
          zoom: 1.0,
          paginationCss: '',
          surfaceColor: '#FFFFFF',
          onSurfaceColor: '#000000',
          shouldOverrideTextColor: true,
          primaryColor: '#000000',
          primaryContainerColor: '#000000',
          onSurfaceVariantColor: '#000000',
          outlineVariantColor: '#000000',
          surfaceContainerColor: '#000000',
          surfaceContainerHighColor: '#000000',
        },
      },
    };

    this.frameMgr = new FrameManager(this.state);
    this.paginationMgr = new PaginationManager(this.state, this.frameMgr);
    this.interactionMgr = new InteractionManager(this.state, this.frameMgr);
    this.themeMgr = new ThemeManager(this.state, this.frameMgr);

    this.resizeDebounceTimer = null;
    this.onResize = (ev: UIEvent) => {
      const newWidth = window.innerWidth;
      const newHeight = window.innerHeight;
      if (this.currentSize.width !== newWidth || this.currentSize.height !== newHeight) {
        this.currentSize = { width: newWidth, height: newHeight };
        if (this.resizeDebounceTimer) {
          clearTimeout(this.resizeDebounceTimer);
        }
        this.resizeDebounceTimer = setTimeout(() => {
          FlutterBridge.onViewportResize();
        }, 120);
      }
    };
  }

  init(config: InitConfig): void {
    const padding = config.padding || {};

    this.state.config.safeWidth = Math.floor(config.safeWidth ?? 0);
    this.state.config.safeHeight = Math.floor(config.safeHeight ?? 0);
    this.state.config.direction = Number(config.direction) || 0;
    this.state.config.padding = {
      top: Number(padding.top ?? 0),
      left: Number(padding.left ?? 0),
    };
    this.state.config.theme = config.theme;

    this.themeMgr.updateCSSVariables(document, 'skeleton-variable-style');
    this.currentSize = { width: window.innerWidth, height: window.innerHeight };
    window.removeEventListener('resize', this.onResize);
    window.addEventListener('resize', this.onResize, { passive: true });
  }

  loadFrame(token: number, slot: FrameSlot, url: string, anchors?: string[], properties?: string[]): void {
    const iframe = this.frameMgr.getFrame(slot);
    if (!iframe) return;

    this.state.anchors[slot] = anchors || [];
    this.state.properties[slot] = properties || [];
    iframe.onload = null;

    if (iframe.src == null || iframe.src === '' || iframe.src === 'about:blank') {
      iframe.onload = () => { this.onFrameLoad(iframe, token); };
      iframe.src = url;
    } else {
      const currentUrl = new URL(iframe.src);
      const newUrl = new URL(url);
      if (currentUrl.origin === newUrl.origin && currentUrl.pathname === newUrl.pathname
          && iframe.contentDocument?.readyState === 'complete') {
        // 同一文档只重新定位，避免导航事件与手动装载重复发送回执。
        this.onFrameLoad(iframe, token, url);
      } else {
        iframe.onload = () => { this.onFrameLoad(iframe, token); };
        iframe.src = url;
      }
    }
  }

  jumpToPage(token: number, pageIndex: number): void {
    const iframe = this.frameMgr.getFrame('curr');
    if (!iframe || !iframe.contentWindow) return;

    const scrollOffset = this.paginationMgr.calculateScrollOffset(pageIndex);
    this.frameMgr.scrollTo(iframe, scrollOffset);

    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        FlutterBridge.onPageChanged(pageIndex);
        this.paginationMgr.detectActiveAnchor(iframe);
        FlutterBridge.onEventFinished(token);
      });
    });
  }

  jumpToPageFor(token: number, slot: FrameSlot, pageIndex: number): void {
    const iframe = this.frameMgr.getFrame(slot);
    if (!iframe || !iframe.contentWindow) return;

    const scrollOffset = this.paginationMgr.calculateScrollOffset(pageIndex);
    this.frameMgr.scrollTo(iframe, scrollOffset);

    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        if (iframe.id === 'frame-curr') {
          FlutterBridge.onPageChanged(pageIndex);
        }
        this.paginationMgr.detectActiveAnchor(iframe);
        FlutterBridge.onEventFinished(token);
      });
    });
  }

  jumpToLastPageOfFrame(token: number, slot: FrameSlot): void {
    const iframe = this.frameMgr.getFrame(slot);
    if (!iframe || !iframe.contentWindow) return;
    const pageCount = this.paginationMgr.calculatePageCount(iframe);
    this.jumpToPageFor(token, slot, pageCount - 1);
  }

  restoreScrollPosition(token: number, ratio: number): void {
    const iframe = this.frameMgr.getFrame('curr');
    if (!iframe || !iframe.contentWindow) return;
    const pageCount = this.paginationMgr.calculatePageCount(iframe);
    const pageIndex = Math.round(ratio * pageCount);
    this.jumpToPage(token, pageIndex);
  }

  cycleFrames(token: number, direction: Direction): void {
    const res = this.frameMgr.cycleFramesDOMAndState(direction);
    if (!res) {
      FlutterBridge.onEventFinished(token);
      return;
    }

    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        this.paginationMgr.updatePageState('frame-curr');
        this.paginationMgr.updatePageState('frame-prev');
        this.paginationMgr.updatePageState('frame-next');
        this.paginationMgr.detectActiveAnchor(res!.elPrev);
        this.paginationMgr.detectActiveAnchor(res!.elCurr);
        this.paginationMgr.detectActiveAnchor(res!.elNext);
        this.interactionMgr.buildInteractionMap().then(() => {
          FlutterBridge.onEventFinished(token);
        });
      });
    });
  }

  checkTapElementAt(x: number, y: number, requestId: number): void {
    this.interactionMgr.checkTapElementAt(x, y, requestId);
  }
  checkLongPressElementAt(x: number, y: number): void {
    this.interactionMgr.checkLongPressElementAt(x, y);
  }

async updateTheme(token: number, viewWidth: number, viewHeight: number, newTheme: ThemeUpdate): Promise<void> {
  // 比例必须在修改尺寸和 CSS 之前采集；只有当前章节需要恢复阅读位置。
  const currentCount = this.paginationMgr.calculatePageCount(this.frameMgr.getCurrFrame());
  const ratio = currentCount > 0 ? this.paginationMgr.calculateCurrentPageIndex() / currentCount : 0;
  this.themeMgr.updateThemeState(viewWidth, viewHeight, newTheme);
  this.themeMgr.updateCSSVariables(document, 'skeleton-variable-style');
  const frames = Array.from(document.getElementsByTagName('iframe'));
  await Promise.all(frames.map(async iframe => {
    if (!iframe.contentDocument) throw new Error('阅读章节尚未就绪');
    this.themeMgr.updateCSSVariables(iframe.contentDocument, 'injected-variable-style', iframe);
    await this.nextFrame();
    await this.reloadFrame(iframe, ratio);
  }));
  FlutterBridge.onEventFinished(token);
}

private nextFrame(): Promise<void> {
  return new Promise(resolve => requestAnimationFrame(() => resolve()));
}

  waitForRender(token: number): void {
    requestAnimationFrame(function () {
      requestAnimationFrame(function () {
        FlutterBridge.onEventFinished(token);
      });
    });
  }

  private onFrameLoad(iframe: HTMLIFrameElement, token: number, targetUrl = iframe.src): void {
    if (!iframe || !iframe.contentDocument) return;

    const doc = iframe.contentDocument;
    this.themeMgr.injectInitialStyles(doc, iframe);

    waitForAllResources(doc).then(() => {
      if (!iframe.contentWindow) return;
      requestAnimationFrame(() => {
        const originalBgColor = this.themeMgr.getOriginalBackgroundColor(iframe);
        const shouldOverrideColor = this.state.config.theme.shouldOverrideTextColor && originalBgColor == null;
        doc.body.classList.toggle('synlen-override-color', shouldOverrideColor);
        doc.body.classList.toggle(
          'synlen-force-override-font',
          !!(this.state.config.theme.overrideFontFamily && this.state.config.theme.fontFileName)
        );
        doc.body.classList.toggle('synlen-override-font', !!(this.state.config.theme.fontFileName));
        doc.body.classList.toggle('synlen-is-vertical', this.frameMgr.isVertical());

        const properties = this.state.properties[this.frameMgr.getSlotFromElement(iframe)] || [];
        for (const prop of properties) {
          doc.body.classList.toggle('synlen-spine-property-' + prop, true);
        }
        applyTyp(iframe);

        const reflow = doc.body.scrollHeight; void reflow;
        requestAnimationFrame(() => {
          polyfillCss(doc, shouldOverrideColor);

          requestAnimationFrame(() => {
            const reflow = doc.body.scrollHeight; void reflow;
            requestAnimationFrame(() => {
              const reflow = doc.body.scrollHeight; void reflow;
              const pageCount = this.paginationMgr.calculatePageCount(iframe);

              let pageIndex = 0;
              const url = targetUrl;
              if (url && url.includes('#')) {
                const anchor = url.split('#')[1];
                pageIndex = this.paginationMgr.calculatePageIndexOfAnchor(iframe, anchor);
                this.frameMgr.scrollTo(iframe, this.paginationMgr.calculateScrollOffset(pageIndex));
              }

              requestAnimationFrame(() => {
                requestAnimationFrame(() => {
                  this.interactionMgr.buildInteractionMap().then(() => {
                    if (iframe.id === 'frame-curr') {
                      FlutterBridge.onPageCountReady(pageCount);
                      FlutterBridge.onPageChanged(pageIndex);
                    } else if (iframe.id === 'frame-prev') {
                      this.jumpToLastPageOfFrame(-1, 'prev');
                    } else if (iframe.id === 'frame-next') {
                      this.jumpToPageFor(-1, 'next', 0);
                    }
                    this.paginationMgr.detectActiveAnchor(iframe);
                    requestAnimationFrame(() => {
                      FlutterBridge.onEventFinished(token);
                    });
                  });
                });
              });
            });
          });
        });
      });
    });
  }

  private async reloadFrame(iframe: HTMLIFrameElement, ratio: number): Promise<void> {
    const doc = iframe.contentDocument;
    if (!doc || !iframe.contentWindow) throw new Error('阅读章节已关闭');
    await waitForAllResources(doc);
    const overrideColor = this.state.config.theme.shouldOverrideTextColor
      && this.themeMgr.getOriginalBackgroundColor(iframe) == null;
    polyfillCss(doc, overrideColor);
    await this.nextFrame();
    await this.nextFrame();
    const count = this.paginationMgr.calculatePageCount(iframe);
    const index = iframe.id === 'frame-prev' ? Math.max(0, count - 1)
      : iframe.id === 'frame-next' ? 0
      : Math.max(0, Math.min(count - 1, Math.round(ratio * count)));
    this.frameMgr.scrollTo(iframe, this.paginationMgr.calculateScrollOffset(index));
    await this.nextFrame();
    await this.nextFrame();
    await this.interactionMgr.buildInteractionMap();
    if (iframe.id === 'frame-curr') {
      FlutterBridge.onPageCountReady(count);
      FlutterBridge.onPageChanged(index);
    }
    this.paginationMgr.detectActiveAnchor(iframe);
    await this.nextFrame();
  }
}
