# 修改阅读器 Web 资源

改完能看到阅读器行为按预期变化，且生成物与源一致。阅读器 TypeScript/CSS 源在 `web_assets/`，Flutter 加载的是生成物 `lib/src/web/web_assets.dart`；只改源不重新生成，改动不会生效。

## 前置

Node 22（见 [development.md](../development.md) 的环境小节）。浏览器二进制由 Playwright 单独下载，首次安装需要网络。

## 步骤

1. 安装工具链，在仓库根目录执行：

   ```sh
   npm ci --prefix web_assets/controller.js
   npm exec --prefix web_assets/controller.js -- playwright install chromium webkit
   ```

   `npm ci` 装的是 `web_assets/controller.js/package-lock.json` 锁定的 esbuild、typescript 与 Playwright。

2. 改源：入口是 `web_assets/controller.js/index.ts`，渲染、分页、交互与学习文本提取在 `web_assets/controller.js/renderer/`；分页样式在 `web_assets/pagination.css/main.css` 及其 `_` 前缀分片；骨架样式在 `web_assets/skeleton.css`。
3. 改 `web_assets/controller.js/renderer/learning_text.ts` 时守住这些规则：
   - 在点击位置所在的语义块建立文本与 DOM 偏移映射；内联标签保持连续，相邻块保持边界。
   - 隐藏内容（`hidden`、`display: none`、`visibility: hidden|collapse`）与 `SCRIPT`、`STYLE`、`NOSCRIPT`、`TEMPLATE`、`RT`、`RP`、`SVG`、`MATH` 不参与上下文。
   - 点击坐标必须命中真实字符矩形（`Range.getClientRects()`）；浏览器 caret 吸附到附近文字不足以触发学习。
   - 英文取词覆盖直 / 弯撇号、连字符、软连字符与常见重音字母。
   - 断句用标点与缩写规则，覆盖小数、姓名首字母、称谓（`Mr`、`Dr` 等）、`e.g.` / `i.e.`、引文与引述语；缩写也可能位于句尾，规则不能消除所有英文歧义。
   - 新语料先加进 `web_assets/controller.js/tests/learning_text.spec.cjs` 的 fixture，再改规则。
4. 类型检查：`npm run typecheck --prefix web_assets/controller.js`。
5. 浏览器回归：`npm test --prefix web_assets/controller.js`。Playwright 按 `web_assets/controller.js/playwright.config.cjs` 的 projects 在 chromium 与 webkit 各跑一遍真实 DOM、Range 与 iframe，并检查 Flutter bridge 收到的单词与整句内容。
6. 重新生成并提交：

   ```sh
   dart run tool/build_web_assets.dart
   ```

   脚本调用 `web_assets/controller.js/node_modules/.bin/esbuild`，重复生成应得到相同内容；生成物 `lib/src/web/web_assets.dart` 与源一起提交。

## 验证

1. `npm run typecheck --prefix web_assets/controller.js` 无报错。
2. `npm test --prefix web_assets/controller.js` 在 chromium 与 webkit 两个 project 全绿。
3. `dart run tool/build_web_assets.dart` 输出包含 `web assets generated`。
4. `git diff --exit-code lib/src/web/web_assets.dart` 通过：生成物与源一致且已提交。
5. `flutter analyze` 零 error 零 warning。
6. 实机验收：`flutter run -d <device-id>` 打开一本 EPUB，点词、长按句子、翻页、切换主题都正常。

## 约束

- 浏览器回归测试不替代 Android/iOS 实机的触摸坐标转换、长按时序、WebView 版本与分页体验验收。
- 缩写歧义无法完全消除；发现新语料先补 `learning_text.spec.cjs` 的用例再调规则。
- CI 只跑 typecheck 与生成物漂移检查，`npm test` 由本地执行。

## Dev Note

None.
