const { test, expect } = require('@playwright/test');
const { buildSync } = require('esbuild');
const fs = require('node:fs');
const path = require('node:path');
const bundle = buildSync({ entryPoints: [path.join(__dirname, '../index.ts')], bundle: true,
  write: false, format: 'iife', target: 'es2015' }).outputFiles[0].text;
const paginationCss = buildSync({ entryPoints: [path.join(__dirname, '../../pagination.css/main.css')], bundle: true,
  write: false }).outputFiles[0].text;
const skeletonCss = fs.readFileSync(path.join(__dirname, '../../skeleton.css'), 'utf8');

async function setup(page) {
  await page.route('http://reader.test/**', route => {
    const chapter = new URL(route.request().url()).pathname;
    const paragraphs = Array.from({ length: 80 }, (_, i) => `<p id="p${i}">${chapter}: Reading keeps a clear record of every chapter. ${'A quiet morning by the sea. '.repeat(12)}</p>`).join('');
    route.fulfill({ contentType: 'text/html', body: `<html><body>${paragraphs}</body></html>` });
  });
  await page.goto('http://reader.test/host');
  await page.setContent(`<style>${skeletonCss}</style><div id="frame-container"><iframe id="frame-prev"></iframe><iframe id="frame-curr"></iframe><iframe id="frame-next"></iframe></div>`);
  await page.evaluate(() => {
    window.events = [];
    window.flutter_inappwebview = { callHandler: (...args) => window.events.push(args) };
  });
  await page.addScriptTag({ content: bundle });
  await page.evaluate(css => {
    window.theme = { zoom: 1, padding: { top: 0, left: 0 }, paginationCss: css,
      shouldOverrideTextColor: true, surfaceColor: '#ffffff', onSurfaceColor: '#000000',
      primaryColor: '#000000', primaryContainerColor: '#dddddd', onSurfaceVariantColor: '#333333',
      outlineVariantColor: '#999999', surfaceContainerColor: '#eeeeee', surfaceContainerHighColor: '#dddddd' };
    window.api.init({ safeWidth: 600, safeHeight: 700, direction: 0, padding: window.theme.padding, theme: { ...window.theme } });
    for (const [i, slot] of ['prev', 'curr', 'next'].entries()) {
      window.api.loadFrame(i + 1, slot, `http://reader.test/chapter${i}`, ['p0', 'p20', 'p40']);
    }
  }, paginationCss);
  await expect.poll(() => page.evaluate(() => window.events.filter(e => e[0] === 'onEventFinished' && e[1] > 0).length)).toBe(3);
}
async function command(page, token, method, args) {
  await page.evaluate(({ token, method, args }) => window.api[method](token, ...args), { token, method, args });
  await expect.poll(() => page.evaluate(t => window.events.some(e => e[0] === 'onEventFinished' && e[1] === t), token)).toBe(true);
}
async function position(page) {
  return page.evaluate(() => {
    const count = window.events.filter(e => e[0] === 'onPageCountReady').at(-1)?.[1];
    const index = window.events.filter(e => e[0] === 'onPageChanged').at(-1)?.[1];
    return { count, index, url: document.querySelector('#frame-curr').src };
  });
}

test('真实三 iframe 跨章并恢复保存的位置', async ({ page }) => {
  await setup(page);
  expect((await position(page)).count).toBeGreaterThan(3);
  await command(page, 10, 'jumpToPage', [2]);
  expect((await position(page)).index).toBe(2);
  await command(page, 11, 'cycleFrames', ['next']);
  expect((await position(page)).url).toContain('/chapter2');
  expect((await position(page)).index).toBe(0);
  await command(page, 12, 'restoreScrollPosition', [0.4]);
  const restored = await position(page);
  expect(restored.index).toBe(Math.round(restored.count * 0.4));
});

test('主题回执只发送一次且在当前章节重新分页之后，位置比例保持', async ({ page }) => {
  await setup(page);
  await command(page, 20, 'restoreScrollPosition', [0.5]);
  const before = await position(page);
  await page.evaluate(() => { window.events = []; window.api.updateTheme(21, 500, 600, { ...window.theme, zoom: 1.4 }); });
  await expect.poll(() => page.evaluate(() => window.events.filter(e => e[0] === 'onEventFinished' && e[1] === 21).length)).toBe(1);
  const after = await position(page);
  expect(after.count).toBeGreaterThan(before.count);
  expect(Math.abs(after.index / after.count - before.index / before.count)).toBeLessThan(1 / after.count + 0.01);
  await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
  const events = await page.evaluate(() => window.events);
  expect(events.filter(e => e[0] === 'onEventFinished' && e[1] === 21)).toHaveLength(1);
  expect(events.findIndex(e => e[0] === 'onPageChanged')).toBeLessThan(events.findIndex(e => e[0] === 'onEventFinished' && e[1] === 21));
});

test('同一章节重新定位只完成一次，不在回执后被重复加载重置', async ({ page }) => {
  await setup(page);
  await command(page, 30, 'loadFrame', ['curr', 'http://reader.test/chapter1#p40', ['p0', 'p20', 'p40']]);
  const target = await position(page);
  expect(target.index).toBeGreaterThan(0);
  await command(page, 31, 'waitForRender', []);
  await command(page, 32, 'waitForRender', []);
  expect((await position(page)).index).toBe(target.index);
  expect(await page.evaluate(() => window.events.filter(e => e[0] === 'onEventFinished' && e[1] === 30).length)).toBe(1);
});
