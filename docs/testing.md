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
| reader Web 资源 | `npm run typecheck` + `npm test --prefix web_assets/controller.js` → `dart run tool/build_web_assets.dart`（见[操作手册](cookbook/changing-reader-web-assets.md)） |

测试文件过滤不等于覆盖率豁免：新增源文件必须有对应测试。全量本地演练只在用户明确要求、排查 CI 失败或变更横跨全仓库时执行；**推送与合并前全量 `flutter test` 必须全绿**。

## 命名与位置

`xxx_test.dart` 与源码镜像同目录（`lib/src/features/reader/application/book_session.dart` → `test/features/reader/application/book_session_test.dart`）。mock 产物 `.mocks.dart` 不手改。

断言要有语义：测行为与边界，而不是"对象存在 / 不抛异常"。

## 现状

- 40 个测试文件 / 246 个用例，另有 2 个条件跳过（真实 DeepSeek 接口验收）。查当前数字：

  ```sh
  find test -name '*_test.dart' | wc -l; grep -rho 'test(' test --include='*.dart' | wc -l
  ```

- `reader/presentation` 的 7 个 mixin 是 `part` 文件（依赖 `reader_screen.dart`），单测需先拆分或改 widget test；这部分覆盖缺口记在 [reader 子系统](subsystems/reader.md#已知限制与待办)。
- 无端到端测试；实机触摸坐标、长按时序、WebView 版本与分页体验仍靠人工验收。

## Dev Note

None.
