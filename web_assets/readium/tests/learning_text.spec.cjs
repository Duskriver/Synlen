const { test, expect } = require('@playwright/test');
const { buildSync } = require('esbuild');
const path = require('node:path');
const bundle = buildSync({ entryPoints: [path.join(__dirname, '../learning_text.ts')], bundle: true,
  write: false, format: 'iife', globalName: 'LearningText', target: 'es2015' }).outputFiles[0].text;

const fixtures = [
  ['跨内联斜体', '<p>I <em id="target">really</em> love this book.</p>', 'really', 'really', 'I really love this book.'],
  ['词内跨节点', '<p><span id="target">read</span><b>ing</b> is fun.</p>', 'read', 'reading', 'reading is fun.'],
  ['弯引号缩写', '<p id="target">I don’t know.</p>', 'don', 'don’t', 'I don’t know.'],
  ['直引号缩写', '<p id="target">I can\'t go.</p>', 'can', "can't", "I can't go."],
  ['连字符', '<p id="target">A well-known author.</p>', 'known', 'well-known', 'A well-known author.'],
  ['软连字符', '<p id="target">Read the dic\u00adtionary.</p>', 'tionary', 'dictionary', 'Read the dictionary.'],
  ['小数', '<p id="target">It costs 3.14 dollars. Next sentence.</p>', 'dollars', 'dollars', 'It costs 3.14 dollars.'],
  ['称谓与姓名首字母', '<p id="target">Dr. J. R. R. Tolkien wrote this. Next.</p>', 'wrote', 'wrote', 'Dr. J. R. R. Tolkien wrote this.'],
  ['缩写后跟数字', '<p id="target">Use a value, e.g. 3.14 dollars. Next.</p>', 'dollars', 'dollars', 'Use a value, e.g. 3.14 dollars.'],
  ['短语缩写', '<p id="target">Try fruit, e.g. apples. Then leave.</p>', 'apples', 'apples', 'Try fruit, e.g. apples.'],
  ['缩略国名', '<p id="target">The U.S. Army arrived. Next.</p>', 'Army', 'Army', 'The U.S. Army arrived.'],
  ['句尾缩略国名', '<p id="target">He lives in the U.S. She visits.</p>', 'visits', 'visits', 'She visits.'],
  ['完整引文与引述语', '<p id="target">“Go!” she said. Then she left.</p>', 'said', 'said', '“Go!” she said.'],
  ['引号收尾', '<p id="target">He said, “Hello!” Next sentence.</p>', 'Hello', 'Hello', 'He said, “Hello!”'],
  ['省略号', '<p id="target">Wait... What happened?</p>', 'happened', 'happened', 'What happened?'],
  ['括号与问号', '<p id="target">Is it true (really)? Yes.</p>', 'really', 'really', 'Is it true (really)?'],
  ['相邻段落', '<p>Earlier.</p><p id="target">A new paragraph.</p><p>Later.</p>', 'new', 'new', 'A new paragraph.'],
  ['行内换行', '<p>We<br><span id="target">keep</span> reading.</p>', 'keep', 'keep', 'We keep reading.'],
  ['嵌套块边界', '<div>Before<div>Nested.</div><span id="target">After</span> it.</div>', 'After', 'After', 'After it.'],
  ['隐藏文字', '<p>Read <span style="display:none">unseen</span><b id="target">this</b><script>ignored</script> book.</p>', 'this', 'this', 'Read this book.'],
  ['重音字符', '<p id="target">Meet at the café.</p>', 'café', 'café', 'Meet at the café.'],
];
for (const [name, html, search, word, sentence] of fixtures) {
  test(name, async ({ page }) => {
    await page.setContent(html);
    await page.addScriptTag({ content: bundle });
    const result = await page.evaluate(({ search }) => {
      const node = document.querySelector('#target').firstChild;
      const caret = document.createRange();
      caret.setStart(node, node.textContent.indexOf(search) + 1);
      caret.collapse(true);
      return LearningText.extractLearningText(caret);
    }, { search });
    expect(result).toEqual({ word, sentence });
  });
}

test('同一段落所有词都得到各自完整句子', async ({ page }) => {
  await page.setContent('<p id="target">First sentence. Second sentence! Third sentence?</p>');
  await page.addScriptTag({ content: bundle });
  const result = await page.evaluate(() => {
    const node = document.querySelector('#target').firstChild;
    return ['First', 'Second', 'Third'].map(word => {
      const caret = document.createRange(); caret.setStart(node, node.textContent.indexOf(word) + 2);
      return LearningText.extractLearningText(caret).sentence;
    });
  });
  expect(result).toEqual(['First sentence.', 'Second sentence!', 'Third sentence?']);
});

test('换行后点击词尾字符仍命中整个词，行间空白不命中', async ({ page }) => {
  await page.setContent('<p style="width:110px;font:24px/3 monospace">hello <em id="target">reading</em> now.</p>');
  await page.addScriptTag({ content: bundle });
  const result = await page.evaluate(() => {
    const node = document.querySelector('#target').firstChild;
    const glyph = document.createRange(); glyph.setStart(node, 6); glyph.setEnd(node, 7);
    const rect = glyph.getBoundingClientRect();
    const caret = document.createRange(); caret.setStart(node, 7); caret.collapse(true);
    return [LearningText.extractLearningText(caret, { x: rect.right - 1, y: rect.top + rect.height / 2 }),
      LearningText.extractLearningText(caret, { x: rect.right - 1, y: rect.bottom + 8 })];
  });
  expect(result).toEqual([{ word: 'reading', sentence: 'hello reading now.' }, null]);
});
