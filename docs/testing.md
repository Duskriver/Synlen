# 测试

测试是硬性要求：**domain、application、parser、import 的改动必须带测试**；纯 UI 改动可豁免，但鼓励补 widget test。本文件管测试分层与最小证据，提交门禁见 [development.md](development.md)。

## 分层

| 层 | 测法 | 例子 |
|---|---|---|
| `domain` | 纯单元测试，无 mock | `reader_settings_test.dart`、`epub_theme_test.dart` |
| `application` | 在 seam 处注入 fake repository / audio，测状态机与编排 | `book_session_test.dart`、`learning_controller_lifecycle_test.dart` |
| `data` | parser、import、备份往返；Drift 仓库用真实临时库（内存 SQLite） | `epub_parser_test.dart`、`import_backup_service_test.dart` |

依赖注入的目的就是让测试**不需要**真实网络、文件系统与平台通道。需要真实外部服务的验收测试必须自我跳过（无密钥时），例如 DeepSeek 接口验收。

## 最小证据

按变更类型选覆盖改动的最小集合，而不是习惯性跑全量：

| 变更 | 最小证据 |
|---|---|
| `lib/` 行为改动 | `flutter analyze` + 对应路径的测试（`flutter test test/<对应路径>_test.dart`） |
| 仅注释 / 文档 | 无测试；动了 `.dart` 跑 `dart format`；跑 `dart run tool/doc_gates.dart` |
| 模型 / provider 注解 | `dart run build_runner build --delete-conflicting-outputs` → analyze + 相关测试 |
| l10n ARB | `flutter gen-l10n`（或 `flutter pub get`）重新生成 localizations + 受影响页面的测试 |
| `pubspec.yaml` / `analysis_options.yaml` / `build.yaml` / `l10n.yaml` | `flutter analyze` + **全量** `flutter test` |
| `rust/` 或 FFI 绑定 | `cargo test`（在 `rust/` 内）→ 绑定重新生成 → analyze + 冒烟测试 |
| Android 原生库构建或 APK 校验 | 重建 APK → `bash tool/verify_android_page_alignment.sh <apk>`（需 `ANDROID_HOME`）+ `flutter test test/tool/release_test.dart`；在设备上覆盖安装并启动 |
| reader Web 资源 | `npm run typecheck` + `npm test --prefix web_assets/controller.js` → `dart run tool/build_web_assets.dart`（见[操作手册](cookbook/changing-reader-web-assets.md)） |

测试文件过滤不等于覆盖率豁免：新增源文件必须有对应测试。全量本地演练只在用户明确要求、排查 CI 失败或变更横跨全仓库时执行；**推送与合并前全量 `flutter test` 必须全绿**。

## 命名与位置

`xxx_test.dart` 与源码镜像同目录（`lib/src/features/reader/application/book_session.dart` → `test/features/reader/application/book_session_test.dart`）。mock 产物 `.mocks.dart` 不手改。

断言要有语义：测行为与边界，而不是"对象存在 / 不抛异常"。

## 现状

- 当前用例数以 `flutter test` 输出为准，测试文件可用以下命令统计：

  ```sh
  find test -name '*_test.dart' | wc -l
  flutter test                                     # 末行 +N ~M 即用例数与跳过数
  ```

  用例数只认 `flutter test` 的输出：用 `grep 'test('` 数会漏掉循环生成的用例。

- `integration_test/learning_e2e_test.dart` 验证学习链路：真机或模拟器上以真实 WebView 渲染 TXT 书籍，点词与长按句子走真实 DeepSeek 接口，未设密钥时跳过。

  ```sh
  flutter test integration_test/learning_e2e_test.dart -d <device> --dart-define=SYNLEN_DEEPSEEK_KEY=<key>
  ```

- `integration_test/reader_smoke_test.dart` 无需密钥，在 Android / iOS 设备验证真实 TXT 导入、WebView 翻页与跨章、主题重新分页、退出保存和重开恢复：`flutter test integration_test/reader_smoke_test.dart -d <device>`。
- `integration_test/word_popover_smoke_test.dart` 无需密钥，真实导入 TXT / EPUB 并驱动 WebView 点词，在学习仓储与播放器注入替身，验证词卡渐进内容、外部关闭不翻页、重排与旋转关闭，以及退出取消请求：`flutter test integration_test/word_popover_smoke_test.dart -d <device>`。
- 浏览器测试在 Chromium 与 WebKit 执行真实三 iframe，覆盖跨章、位置恢复与主题回执；实机触摸坐标、长按时序和不同 WebView 版本的体验仍需人工验收。

## Dev Note

None.
