import type { ReaderState, ThemeUpdate } from '../common/types';
import { FrameManager } from './frame_manager';

export class ThemeManager {
  constructor(
    private state: ReaderState,
    private frameMgr: FrameManager
  ) { }

  updateThemeState(viewWidth: number, viewHeight: number, newTheme: ThemeUpdate): void {
    this.state.config.safeWidth = Math.floor(viewWidth);
    this.state.config.safeHeight = Math.floor(viewHeight);
    this.state.config.padding = {
      top: newTheme.padding.top,
      left: newTheme.padding.left,
    };
    this.state.config.theme.zoom = newTheme.zoom;
    this.state.config.theme.shouldOverrideTextColor = newTheme.shouldOverrideTextColor;
    this.state.config.theme.fontFileName = newTheme.fontFileName || null;
    this.state.config.theme.overrideFontFamily = newTheme.overrideFontFamily || false;
    this.state.config.theme.primaryColor = newTheme.overridePrimaryColor || newTheme.primaryColor;
    this.state.config.theme.primaryContainerColor = newTheme.primaryContainerColor;
    this.state.config.theme.surfaceColor = newTheme.surfaceColor;
    this.state.config.theme.onSurfaceColor = newTheme.onSurfaceColor;
    this.state.config.theme.onSurfaceVariantColor = newTheme.onSurfaceVariantColor;
    this.state.config.theme.outlineVariantColor = newTheme.outlineVariantColor;
    this.state.config.theme.surfaceContainerColor = newTheme.surfaceContainerColor;
    this.state.config.theme.surfaceContainerHighColor = newTheme.surfaceContainerHighColor;
  }

  getOriginalBackgroundColor(iframe: HTMLIFrameElement): string | null {
    if (!iframe || !iframe.contentDocument || !iframe.contentWindow) return null;
    try {
      const window = iframe.contentWindow!;
      const body = iframe.contentDocument.body;
      if (!body) {
        console.warn('Iframe body is null, possibly not fully loaded or not an HTML document.');
        return null;
      }
      const bgColor = window.getComputedStyle(body).backgroundColor;
      if (bgColor && bgColor !== 'rgba(0, 0, 0, 0)' && bgColor !== 'transparent') {
        return bgColor;
      }
    } catch (e) {
      console.warn('Failed to get original background color from iframe:', e);
      return null;
    }
    return null;
  }

  generateVariableStyle(): string {
    const cfg = this.state.config;
    const t = cfg.theme;
    const isV = this.frameMgr.isVertical();

    const fontFaceBlock = t.fontFileName
      ? `@font-face { font-family: 'SynlenCustomFont'; src: url('book://localhost/fonts/${t.fontFileName}'); }`
      : '';
    const fontFamilyItem = t.fontFileName ? `--synlen-font-family: 'SynlenCustomFont';` : '';

    return fontFaceBlock + ' :root {'
      + `--synlen-zoom: ${t.zoom};`
      + `--synlen-safe-width: ${cfg.safeWidth}px;`
      + `--synlen-safe-height: ${cfg.safeHeight}px;`
      + `--synlen-padding-top: ${cfg.padding.top}px;`
      + `--synlen-padding-left: ${cfg.padding.left}px;`
      + `--synlen-reader-overflow-x: ${isV ? 'hidden' : 'auto'};`
      + `--synlen-reader-overflow-y: ${isV ? 'auto' : 'hidden'};`
      + `--synlen-surface-color: ${t.surfaceColor};`
      + `--synlen-on-surface-color: ${t.onSurfaceColor};`
      + `--synlen-primary-color: ${t.primaryColor};`
      + `--synlen-primary-container-color: ${t.primaryContainerColor};`
      + `--synlen-on-surface-variant-color: ${t.onSurfaceVariantColor};`
      + `--synlen-outline-variant-color: ${t.outlineVariantColor};`
      + `--synlen-surface-container-color: ${t.surfaceContainerColor};`
      + `--synlen-surface-container-high-color: ${t.surfaceContainerHighColor};`
      + fontFamilyItem
      + '}';
  }

  updateCSSVariables(
    doc: Document,
    styleId: string = 'injected-variable-style',
    iframe: HTMLIFrameElement | null = null
  ): void {
    const root = doc.documentElement;
    const body = doc.body;
    const cfg = this.state.config;
    const t = cfg.theme;
    const isV = this.frameMgr.isVertical();

    root.style.setProperty('--synlen-zoom', String(t.zoom));
    root.style.setProperty('--synlen-safe-width', cfg.safeWidth + 'px');
    root.style.setProperty('--synlen-safe-height', cfg.safeHeight + 'px');
    root.style.setProperty('--synlen-padding-top', cfg.padding.top + 'px');
    root.style.setProperty('--synlen-padding-left', cfg.padding.left + 'px');
    root.style.setProperty('--synlen-reader-overflow-x', isV ? 'hidden' : 'auto');
    root.style.setProperty('--synlen-reader-overflow-y', isV ? 'auto' : 'hidden');
    root.style.setProperty('--synlen-surface-color', t.surfaceColor);
    root.style.setProperty('--synlen-on-surface-color', t.onSurfaceColor);
    root.style.setProperty('--synlen-primary-color', t.primaryColor);
    root.style.setProperty('--synlen-primary-container', t.primaryContainerColor);
    root.style.setProperty('--synlen-on-surface-variant', t.onSurfaceVariantColor);
    root.style.setProperty('--synlen-outline-variant', t.outlineVariantColor);
    root.style.setProperty('--synlen-surface-container', t.surfaceContainerColor);
    root.style.setProperty('--synlen-surface-container-high', t.surfaceContainerHighColor);

    const overrideColor = iframe != null
      ? t.shouldOverrideTextColor && this.getOriginalBackgroundColor(iframe) == null
      : t.shouldOverrideTextColor;

    body.classList.toggle('synlen-override-color', overrideColor);
    body.classList.toggle('synlen-force-override-font', !!(t.overrideFontFamily && t.fontFileName));
    body.classList.toggle('synlen-override-font', !!(t.fontFileName));

    const existingStyle = doc.getElementById(styleId);
    if (existingStyle) {
      existingStyle.innerHTML = this.generateVariableStyle();
    }
  }

  injectInitialStyles(doc: Document, iframe: HTMLIFrameElement): void {
    const existingVariableStyle = doc.getElementById('injected-variable-style');
    if (existingVariableStyle) {
      existingVariableStyle.innerHTML = this.generateVariableStyle();
      this.updateCSSVariables(doc, 'injected-variable-style', iframe);
    } else {
      const variableStyle = doc.createElement('style');
      variableStyle.id = 'injected-variable-style';
      variableStyle.innerHTML = this.generateVariableStyle();
      doc.head.appendChild(variableStyle);
    }

    const existingPaginationStyle = doc.getElementById('injected-pagination-style');
    if (existingPaginationStyle) {
      existingPaginationStyle.innerHTML = this.state.config.theme.paginationCss;
    } else {
      const style = doc.createElement('style');
      style.id = 'injected-pagination-style';
      style.innerHTML = this.state.config.theme.paginationCss;
      doc.head.appendChild(style);
    }
  }
}
