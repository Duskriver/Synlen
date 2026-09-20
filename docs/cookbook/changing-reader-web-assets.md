# 修改阅读器 Web 资源

目标是更新 Readium 文档中的学习手势、词句提取与可见文本采样，并让生成的 Flutter asset 与源码一致。排版、分页与定位恢复属于 Readium；Web 脚本只读取可见短文本供标准 Locator 使用，行为契约见 [reader](../subsystems/reader.md#边界与不变量)。

## 前置

Node 22 与 Dart 环境见 [development.md](../development.md)。Playwright 浏览器二进制单独下载，首次安装需要网络。

## 步骤

1. 在仓库根目录安装锁定的工具链和浏览器：

   ```sh
   npm ci --prefix web_assets/readium
   npm exec --prefix web_assets/readium -- playwright install chromium webkit
   ```

2. 按职责修改 `web_assets/readium/bridge.ts` 的手势处理、`web_assets/readium/learning_text.ts` 的词句提取或 `web_assets/readium/visible_locator.ts` 的可见文本采样。词句语料、手势与定位边界分别加入 `web_assets/readium/tests/` 下的对应回归。
3. 运行类型检查与两个浏览器项目：

   ```sh
   npm run typecheck --prefix web_assets/readium
   npm test --prefix web_assets/readium
   ```

4. 从 `web_assets/readium/index.ts` 生成独立 Web asset：

   ```sh
   dart run tool/build_readium_assets.dart
   ```

   生成物 `assets/reader/readium_learning.js` 与源一起提交，不手改。构建脚本仅依赖 Dart 标准库与 npm 锁定的本地 esbuild。
5. 在 Android / iOS 打开 EPUB 与 TXT，验证点词附带整句、长按句子、中心空白控制栏、边缘翻页、链接和图片；滑动或多指不得误触学习，切章后的旧消息不得作用于新页面。修改可见文本采样时，对照字号变化与重开前后的截图及 Locator，确认原段落仍可见、同字号页码一致。

## 验证

1. `npm ci` 接受 `package.json` 与 `package-lock.json`，`git diff --exit-code -- web_assets/readium/package-lock.json` 无漂移。
2. TypeScript 与 Playwright 全部通过；断言实际词句内容、消息次数与默认事件是否被消费。
3. 重跑构建后，`git diff --exit-code -- assets/reader/readium_learning.js` 通过，证明生成物与已提交源码一致。
4. CI 与发布入口执行相同的锁文件、类型、浏览器和生成物检查；原生侧验收不能用桌面浏览器结果替代。

## Dev Note

None.
