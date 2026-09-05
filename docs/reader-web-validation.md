# 阅读器 Web 资源验证

阅读器 TypeScript/CSS 源位于 `web_assets/`，Flutter 加载的生成物为 `lib/src/web/web_assets.dart`。修改源后必须重新生成并提交生成物。

## 安装与运行

在仓库根目录执行：

```sh
npm ci --prefix web_assets/controller.js
npm exec --prefix web_assets/controller.js -- playwright install chromium webkit
npm run typecheck --prefix web_assets/controller.js
npm test --prefix web_assets/controller.js
dart run tool/build_web_assets.dart
```

构建脚本使用 `controller.js/package-lock.json` 锁定的本地 esbuild；不会在构建时下载其他版本。重复生成应得到相同文件。浏览器二进制由 Playwright 单独安装，首次安装需要网络。

## 学习文本提取

`renderer/learning_text.ts` 在点击位置所在的语义块中建立文本与 DOM 偏移映射。内联标签保持连续；相邻块保持边界；隐藏内容与脚本不参与上下文。点击坐标需命中真实字符矩形，浏览器 caret 吸附到附近文字不足以触发学习。

英文取词覆盖直/弯撇号、连字符、软连字符和常见重音字母。断句采用标点与常见缩写规则，覆盖小数、姓名首字母、称谓、引文及引述语。缩写也可能位于句尾，规则不能消除所有英文歧义；发现新语料应先加入浏览器回归测试再调整规则。

`tests/learning_text.spec.cjs` 在 Chromium 与 WebKit 中运行真实 DOM、Range 和 iframe 验证，并检查 Flutter bridge 收到的单词与整句内容。它不替代 Android/iOS 实机的触摸坐标转换、长按时序、WebView 版本及分页体验验收。
