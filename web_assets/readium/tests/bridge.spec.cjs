const { test, expect } = require('@playwright/test');
const { buildSync } = require('esbuild');
const path = require('node:path');
const bundle = buildSync({ entryPoints: [path.join(__dirname, '../index.ts')], bundle: true,
  write: false, format: 'iife', target: 'es2015' }).outputFiles[0].text;

async function setup(page, html = '<p>Dr. Rivers called it an un<em id="target">hurried</em> afternoon. Next sentence.</p>', platform = 'android') {
  await page.setViewportSize({ width: 412, height: 711 });
  await page.setContent('<style>body{margin:40px;font:20px/2 serif}p{margin:0}</style>' + html);
  await page.evaluate(platform => {
    window.messages = [];
    window.nativeClicks = 0;
    const port = { postMessage: value => window.messages.push(JSON.parse(value)) };
    if (platform === 'android') window.flutterReadiumText = port;
    else window.webkit = { messageHandlers: { flutterReadiumText: port } };
    document.addEventListener('click', event => { if (!event.defaultPrevented) window.nativeClicks++; });
  }, platform);
  await page.addScriptTag({ content: bundle });
  await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}
async function point(page, selector = '#target') {
  return page.locator(selector).evaluate(element => {
    const range = document.createRange();
    range.setStart(element.firstChild, 1); range.setEnd(element.firstChild, 2);
    const rect = range.getClientRects()[0];
    return { x: rect.left + rect.width / 2, y: rect.top + rect.height / 2 };
  });
}
async function messages(page) { return page.evaluate(() => window.messages); }
async function pointer(page, type, point, extras = {}) {
  return page.evaluate(({ type, point, extras }) => {
    const target = document.elementFromPoint(point.x, point.y) || document.body;
    const event = new PointerEvent(type, { bubbles: true, cancelable: true, pointerId: 7, isPrimary: true,
      pointerType: 'touch', button: 0, clientX: point.x, clientY: point.y, ...extras });
    target.dispatchEvent(event);
  }, { type, point, extras });
}
async function click(page, point) {
  return page.evaluate(point => {
    const event = new MouseEvent('click', { bubbles: true, cancelable: true, detail: 1, clientX: point.x, clientY: point.y });
    (document.elementFromPoint(point.x, point.y) || document.body).dispatchEvent(event);
    return event.defaultPrevented;
  }, point);
}

async function expectedWordMessage(page) {
  return page.evaluate(() => {
    const target = document.querySelector('#target');
    const prefix = target.previousSibling;
    const range = document.createRange();
    range.setStart(prefix, prefix.textContent.lastIndexOf('un'));
    range.setEnd(target.firstChild, target.textContent.length);
    const box = range.getBoundingClientRect();
    return { version: 1, href: 'about:blank', kind: 'word', word: 'unhurried',
      sentence: 'Dr. Rivers called it an unhurried afternoon.',
      wordRect: { x: box.x, y: box.y, width: box.width, height: box.height },
      viewport: { width: innerWidth, height: innerHeight } };
  });
}

for (const platform of ['android', 'ios']) {
  test(`${platform} 点词含跨内联完整词句，且不同时切换控制栏`, async ({ page }) => {
    await setup(page, undefined, platform);
    const target = await point(page);
    await page.mouse.click(target.x, target.y);
    expect(await messages(page)).toEqual([await expectedWordMessage(page)]);
    expect(await page.evaluate(() => window.nativeClicks)).toBe(0);
  });

  test(`${platform} 原生抑制 click 时 pointerup 仍发送完整词句，兼容 click 仅消费`, async ({ page }) => {
    await setup(page, undefined, platform);
    const target = await point(page);
    await pointer(page, 'pointerdown', target);
    expect(await messages(page)).toEqual([]);
    await pointer(page, 'pointerup', target);
    expect(await messages(page)).toEqual([await expectedWordMessage(page)]);
    expect(await click(page, target)).toBe(true);
    expect(await messages(page)).toHaveLength(1);
    expect(await page.evaluate(() => window.nativeClicks)).toBe(0);
  });

  test(`${platform} 无 click 的中心空白短点只发 controls，后续 click 不重复`, async ({ page }) => {
    await setup(page, undefined, platform);
    const blank = { x: 200, y: 400 };
    await pointer(page, 'pointerdown', blank);
    await pointer(page, 'pointerup', blank);
    expect(await messages(page)).toEqual([{ version: 1, href: 'about:blank', kind: 'controls' }]);
    expect(await click(page, blank)).toBe(true);
    expect(await messages(page)).toHaveLength(1);
  });

  test(`${platform} 正文顶底和侧边空白均打开控制栏，24px翻页边缘除外`, async ({ page }) => {
    await setup(page, '<p>One short paragraph.</p>', platform);
    for (const blank of [{x:206,y:10},{x:206,y:700},{x:30,y:300},{x:382,y:300}]) {
      await page.evaluate(() => { window.messages = []; });
      await page.mouse.click(blank.x, blank.y);
      expect(await messages(page)).toEqual([{version:1,href:'about:blank',kind:'controls'}]);
    }
    await page.evaluate(() => { window.messages = []; });
    await page.mouse.click(10, 700);
    await page.mouse.click(402, 700);
    expect(await messages(page)).toEqual([]);
    expect(await page.evaluate(() => window.nativeClicks)).toBe(2);
  });

  test(`${platform} 真实浏览器 pointer 手势在 click 被上游截断时仍完成点词`, async ({ page }) => {
    await setup(page, undefined, platform);
    await page.evaluate(() => {
      window.pointerTrust = [];
      for (const name of ['pointerdown', 'pointerup']) {
        window.addEventListener(name, event => window.pointerTrust.push(event.isTrusted), true);
      }
      window.addEventListener('click', event => event.stopImmediatePropagation(), true);
    });
    const target = await point(page);
    await page.mouse.move(target.x, target.y);
    await page.mouse.down();
    expect(await messages(page)).toEqual([]);
    await page.mouse.up();
    expect(await page.evaluate(() => window.pointerTrust)).toEqual([true, true]);
    expect(await messages(page)).toEqual([await expectedWordMessage(page)]);
  });
}

test('长按发送完整句子，抬手后的 click 不发词或 controls', async ({ page }) => {
  await setup(page);
  const target = await point(page);
  await page.mouse.move(target.x, target.y);
  await page.mouse.down();
  await expect.poll(() => messages(page)).toEqual([{ version: 1, href: 'about:blank', kind: 'sentence', sentence: 'Dr. Rivers called it an unhurried afternoon.' }]);
  await page.mouse.up();
  expect(await messages(page)).toHaveLength(1);
  expect(await page.evaluate(() => window.nativeClicks)).toBe(0);
});

test('中心空白短点仅 controls；长按空白不查句', async ({ page }) => {
  await setup(page);
  await page.mouse.click(200, 400);
  expect(await messages(page)).toEqual([{ version: 1, href: 'about:blank', kind: 'controls' }]);
  await page.mouse.move(200, 400); await page.mouse.down();
  await page.waitForTimeout(650);
  expect(await messages(page)).toHaveLength(1);
  await page.mouse.up();
  expect(await messages(page)).toHaveLength(1);
});

for (const reason of ['movement', 'cancel', 'scroll', 'multitouch', 'visibility']) {
  test(`${reason} 取消长按及迟到的合成 click`, async ({ page }) => {
    await setup(page);
    const target = await point(page);
    await pointer(page, 'pointerdown', target);
    if (reason === 'movement') await pointer(page, 'pointermove', { x: target.x + 11, y: target.y });
    if (reason === 'cancel') await pointer(page, 'pointercancel', target);
    if (reason === 'scroll') await page.evaluate(() => document.dispatchEvent(new Event('scroll')));
    if (reason === 'visibility') await page.evaluate(() => document.dispatchEvent(new Event('visibilitychange')));
    if (reason === 'multitouch') await pointer(page, 'pointerdown', target, { pointerId: 8, isPrimary: false });
    await page.waitForTimeout(650);
    await pointer(page, 'pointerup', target);
    expect(await click(page, target)).toBe(true);
    expect(await messages(page)).toEqual([]);
    if (reason === 'multitouch') await pointer(page, 'pointerup', target, { pointerId: 8, isPrimary: false });
    await page.mouse.click(target.x, target.y);
    expect((await messages(page)).map(message => message.kind)).toEqual(['word']);
  });
}

test('小幅抖动仍可点词', async ({ page }) => {
  await setup(page);
  const target = await point(page);
  await pointer(page, 'pointerdown', target);
  await pointer(page, 'pointermove', { x: target.x + 4, y: target.y });
  await pointer(page, 'pointerup', target);
  expect(await click(page, target)).toBe(true);
  expect((await messages(page)).map(message => message.kind)).toEqual(['word']);
});

for (const x of [10, 402]) {
  test(`边缘 ${x}px 保留原生翻页`, async ({ page }) => {
    await setup(page, '<p style="position:absolute;left:0;right:0" id="target">edge edge edge edge edge edge edge edge</p>');
    await page.mouse.click(x, 60);
    expect(await messages(page)).toEqual([]);
    expect(await page.evaluate(() => window.nativeClicks)).toBe(1);
  });
}

for (const html of [
  '<a id="target" href="#note">footnote</a><aside id="note">Note</aside>',
  '<img id="target" alt="image" src="data:image/svg+xml,%3Csvg xmlns=%22http://www.w3.org/2000/svg%22 width=%22100%22 height=%22100%22/%3E">',
  '<button id="target">action</button>',
  '<input id="target" value="editable">',
  '<svg width="200" height="80"><text id="target" x="0" y="30">drawing</text></svg>',
]) {
  test(`交互元素保留原生行为 ${html.slice(0, 25)}`, async ({ page }) => {
    await setup(page, html);
    const rect = await page.locator('#target').boundingBox();
    await page.mouse.click(rect.x + rect.width / 2, rect.y + rect.height / 2);
    expect(await messages(page)).toEqual([]);
    expect(await page.evaluate(() => window.nativeClicks)).toBe(1);
  });
}

test('禁止正文 selection 和 contextmenu，保留输入框选择', async ({ page }) => {
  await setup(page, '<p id="target">Reading text.</p><input id="input" value="edit me">');
  const result = await page.evaluate(() => {
    const target = document.querySelector('#target');
    const selection = new Event('selectstart', { bubbles: true, cancelable: true }); target.dispatchEvent(selection);
    const menu = new MouseEvent('contextmenu', { bubbles: true, cancelable: true }); target.dispatchEvent(menu);
    const input = new Event('selectstart', { bubbles: true, cancelable: true }); document.querySelector('#input').dispatchEvent(input);
    return { selection: selection.defaultPrevented, menu: menu.defaultPrevented, input: input.defaultPrevented, css: getComputedStyle(target).userSelect };
  });
  expect(result).toEqual({ selection: true, menu: true, input: false, css: 'none' });
});

test('重复注入只有一个监听，dispose取消定时器且移除样式', async ({ page }) => {
  await setup(page);
  await page.addScriptTag({ content: bundle });
  const target = await point(page);
  await page.mouse.click(target.x, target.y);
  expect(await messages(page)).toHaveLength(1);
  expect(await page.locator('style[data-synlen-learning]').count()).toBe(1);
  await pointer(page, 'pointerdown', target);
  await page.evaluate(() => window.synlenReadiumBridge.dispose());
  await page.waitForTimeout(650);
  expect(await messages(page)).toHaveLength(1);
  expect(await page.locator('style[data-synlen-learning]').count()).toBe(0);
});

test('桥未安装时不吞掉原生点击', async ({ page }) => {
  await setup(page);
  await page.evaluate(() => delete window.flutterReadiumText);
  const target = await point(page);
  await page.mouse.click(target.x, target.y);
  expect(await messages(page)).toEqual([]);
  expect(await page.evaluate(() => window.nativeClicks)).toBe(1);
});


test('嵌套书内 frame 的词矩形包含 frame 偏移、边框和缩放', async ({ page }) => {
  await page.setViewportSize({ width: 800, height: 700 });
  await page.setContent(`<iframe style="position:absolute;left:70px;top:90px;width:500px;height:400px;border:4px solid;transform:scale(.8);transform-origin:top left" srcdoc="<p style='font:24px/2 serif'><span id='target'>reading</span> is fun.</p>"></iframe>`);
  const frame = page.frames()[1];
  await frame.waitForSelector('#target');
  await frame.evaluate(() => {
    window.messages = [];
    window.flutterReadiumText = { postMessage: value => window.messages.push(JSON.parse(value)) };
  });
  await frame.addScriptTag({ content: bundle });
  await frame.locator('#target').click();
  const result = await frame.evaluate(() => {
    const range = document.createRange(); range.selectNodeContents(document.querySelector('#target'));
    const box = range.getBoundingClientRect();
    const frame = window.frameElement;
    const host = frame.getBoundingClientRect();
    const sx = host.width / frame.offsetWidth, sy = host.height / frame.offsetHeight;
    return { messages: window.messages, expected: {
      x: host.left + (frame.clientLeft + box.x) * sx,
      y: host.top + (frame.clientTop + box.y) * sy,
      width: box.width * sx, height: box.height * sy } };
  });
  expect(result.messages).toHaveLength(1);
  expect(result.messages[0]).toMatchObject({kind: 'word', word: 'reading', viewport: {width: 800, height: 700}});
  for (const key of ['x', 'y', 'width', 'height']) {
    expect(result.messages[0].wordRect[key]).toBeCloseTo(result.expected[key], 4);
  }
});
