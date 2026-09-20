const { test, expect } = require('@playwright/test');
const { buildSync } = require('esbuild');
const path = require('node:path');
const bundle = buildSync({ entryPoints: [path.join(__dirname, '../index.ts')], bundle: true,
  write: false, format: 'iife', target: 'es2015' }).outputFiles[0].text;

async function setup(page, html, selector = '#passage') {
  await page.setViewportSize({ width: 412, height: 300 });
  await page.setContent(`<style>html{height:100%;overflow:hidden}body{height:100%;margin:0;column-width:412px;column-gap:0;column-fill:auto;font:20px/1.8 serif}p{margin:0}</style>${html}`);
  await page.evaluate(selector => {
    if (selector) window.readium = { findFirstVisibleLocator: () => ({locations:{cssSelector:selector}}) };
  }, selector);
  await page.addScriptTag({content:bundle});
  await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}
async function locator(page) { return page.evaluate(() => window.synlenReadiumBridge.getVisibleLocator()); }

// 用 SDK TextQuoteAnchor 的原始 textContent 契约解析返回值，断言唯一匹配而非猜测比例。
async function quoteRange(page, saved, scroll = false) {
  return page.evaluate(({saved,scroll}) => {
    const root=document.querySelector(saved.locations.cssSelector);
    const {before,highlight,after}=saved.text;
    const needle=before+highlight+after;
    const text=root.textContent;
    const prefix=text.indexOf(needle);
    if(prefix<0 || text.indexOf(needle,prefix+1)>=0) throw Error('Locator quote must match exactly once');
    const start=prefix+before.length,end=start+highlight.length;
    const walker=document.createTreeWalker(root,NodeFilter.SHOW_TEXT);
    const range=document.createRange();let count=0;
    for(let node=walker.nextNode();node;node=walker.nextNode()) {
      if(start>=count && start<count+node.length) range.setStart(node,start-count);
      if(end>count && end<=count+node.length) {range.setEnd(node,end-count);break;}
      count+=node.length;
    }
    if(scroll){
      const x=range.getBoundingClientRect().left+window.scrollX;
      document.scrollingElement.scrollLeft=Math.floor(x/window.innerWidth)*window.innerWidth;
    }
    return {text:range.toString(),rects:Array.from(range.getClientRects()).map(r=>({left:r.left,right:r.right,top:r.top,bottom:r.bottom})),x:window.scrollX};
  }, {saved,scroll});
}
function expectVisible(result) {
  expect(result.rects.length).toBeGreaterThan(0);
  for(const rect of result.rects){
    expect(rect.left).toBeGreaterThanOrEqual(-.5); expect(rect.right).toBeLessThanOrEqual(412.5);
    expect(rect.top).toBeGreaterThanOrEqual(-.5); expect(rect.bottom).toBeLessThanOrEqual(300.5);
  }
}
const longParagraph=Array.from({length:260},(_,i)=>`word${String(i).padStart(3,'0')} ordinary reading context`).join(' ');

test('隐藏、ruby注音、SVG与脚本不成为锚点，context保留SDK原始文本语义',async({page})=>{
  await setup(page,'<p id="passage"><span hidden>hidden-prefix</span><svg><text>svg-hidden</text></svg><ruby><rt>ruby-hint</rt></ruby><script type="text/plain">script-text</script>Visibleword  keeps\n  original spacing.</p>');
  const saved=await locator(page);
  expect(saved.text.highlight).toBe('Visibleword');
  expect(saved.text.before.length).toBeLessThanOrEqual(64);
  expect(saved.text.after.length).toBeLessThanOrEqual(64);
  expect((await quoteRange(page,saved)).text).toBe('Visibleword');
  expectVisible(await quoteRange(page,saved));
});

test('上下文64边界不截断emoji代理对，原始锚点偏移不变',async({page})=>{
  await setup(page,`<p id="passage"><span hidden>😀${'b'.repeat(63)}</span>Visibleword<span hidden>${'a'.repeat(63)}😀</span></p>`);
  const saved=await locator(page);
  expect(saved.text).toEqual({before:'b'.repeat(63),highlight:'Visibleword',after:'a'.repeat(63)});
  expect((await quoteRange(page,saved)).text).toBe('Visibleword');
  expectVisible(await quoteRange(page,saved));
});

test('无SDK候选时返回真实文本父元素选择器，跳过完全透明文字',async({page})=>{
  await setup(page,'<p style="opacity:0">Invisibleword</p><p id="actual">Fallbackword is visible.</p>',null);
  const saved=await locator(page);
  expect(saved.text.highlight).toBe('Fallbackword');
  expect(await page.evaluate(s=>document.querySelector(s)===document.querySelector('#actual'),saved.locations.cssSelector)).toBe(true);
  expectVisible(await quoteRange(page,saved));
});

test('跨栏整段只取当前列内短锚点，重复恢复不退回段首',async({page})=>{
  await setup(page,`<p id="passage">${longParagraph}</p>`);
  await page.evaluate(()=>{document.scrollingElement.scrollLeft=4*innerWidth;});
  const saved=await locator(page);
  expect(saved.text.highlight).not.toBe('word000');
  expect(saved.text.highlight.length).toBeLessThanOrEqual(48);
  expectVisible(await quoteRange(page,saved));
  for(let i=0;i<3;i++){
    await page.evaluate(()=>{document.scrollingElement.scrollLeft=0;});
    expectVisible(await quoteRange(page,saved,true));
    expect((await locator(page)).text).toEqual(saved.text);
    expect(await page.evaluate(()=>scrollX)).toBe(4*412);
  }
});

test('字号重排后短锚点仍可见，同章粗比例不参与恢复',async({page})=>{
  await setup(page,`<p id="passage">${longParagraph}</p>`);
  await page.evaluate(()=>{document.scrollingElement.scrollLeft=4*innerWidth;});
  const saved=await locator(page);
  await page.evaluate(()=>{document.body.style.fontSize='30px';document.scrollingElement.scrollLeft=0;});
  expectVisible(await quoteRange(page,saved,true));
  expect((await quoteRange(page,saved)).text).toBe(saved.text.highlight);
});

test('SDK候选不可见或选择器失效时从正文寻找实际可见文字',async({page})=>{
  await setup(page,'<p id="absent" hidden>Wrongword</p><p id="actual">Actualword is shown.</p>','#absent');
  expect((await locator(page)).text.highlight).toBe('Actualword');
  await page.evaluate(()=>{window.readium.findFirstVisibleLocator=()=>({locations:{cssSelector:'['}});});
  expect((await locator(page)).text.highlight).toBe('Actualword');
});

test('空白页没有文字锚点，查询不改变滚动或正文',async({page})=>{
  await setup(page,'<p id="passage">   </p>');
  const before=await page.evaluate(()=>({html:document.body.innerHTML,x:scrollX,y:scrollY}));
  expect(await locator(page)).toBe(null);
  expect(await page.evaluate(()=>({html:document.body.innerHTML,x:scrollX,y:scrollY}))).toEqual(before);
});

test('有限上下文仍完全重复时不返回会跳到别处的文字锚点',async({page})=>{
  await setup(page,`<p id="passage">${'Repeated words are repeated. '.repeat(120)}</p>`);
  await page.evaluate(()=>{document.scrollingElement.scrollLeft=4*innerWidth;});
  expect(await locator(page)).toBe(null);
});
