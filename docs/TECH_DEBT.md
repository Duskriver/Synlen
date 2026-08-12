# 技术债清单

> 本文件集中记录代码库的技术债（违规清单、待清理项），是 ADR-0001 增量重构纪律的追踪载体。
> 规则：新代码一律按 `DEVELOPMENT_STANDARDS.md` 书写；旧代码遵循 Boy Scout Rule——路过即修。
> 每清理一条，删除对应条目并注明清理 commit；发现新债时追加，不散落在代码注释里。

建立时间：2026-08-12（架构诊断后首建）。

---

## 1. 分层违规：presentation 直连 data

规范 §1 禁止 `presentation → data`，且禁止 feature 之间互相 import。当前实测 **12 个文件**违规（原 ADR-0001 记录的「7 处」已过时）。

| # | 文件 | 违规性质 |
|---|------|----------|
| 1 | `lib/src/features/detail/presentation/book_detail_helpers.dart` | 引 `library/data/services` |
| 2 | `lib/src/features/detail/presentation/book_detail_screen.dart` | 引 `library/data/repositories` |
| 3 | `lib/src/features/library/presentation/mixins/library_actions_mixin.dart` | 引 `library/data/services` |
| 4 | `lib/src/features/library/presentation/widgets/style_bottom_sheet.dart` | **绕过 provider 直接引 `data/shelf_book_repository.dart`（最深违规）** |
| 5 | `lib/src/features/library/presentation/widgets/restore_progress_dialog.dart` | 引 `library/data/services` |
| 6 | `lib/src/features/reader/presentation/reader_webview.dart` | 引 `reader/data` |
| 7 | `lib/src/features/reader/presentation/reader_renderer.dart` | 引 `reader/data` |
| 8 | `lib/src/features/reader/presentation/image_viewer.dart` | 引 `reader/data` |
| 9 | `lib/src/features/reader/presentation/reader_screen.dart` | 引 `reader/data` + **跨 feature 引 `library/data`**（6 处 import） |
| 10 | `lib/src/features/reader/presentation/widgets/footnot_popup_overlay.dart` | 引 `reader/data` |
| 11 | `lib/src/features/settings/presentation/widgets/clean_cache_tile.dart` | **跨 feature 引 `library/data/services`** |
| 12 | `lib/src/features/settings/presentation/widgets/backup_tile.dart` | **跨 feature 引 `library/data/services`** |

修复方向：reader 的 `data`（book_session / epub_webview_handler / reader_scripts / epub_stream_service）要么下沉到 `core/`，要么在 `application` 层提供编排接口；settings/detail 跨 feature 依赖改为经 `library/application` 暴露的 provider。

---

## 2. 日志规范（✅ 已清理，2026-08-12）

规范 §8 要求「日志用 `logger` 包，禁止 `print` / `debugPrint`」。

- ✅ 54 处 `debugPrint` 已全部迁移到全局共享实例 `appLogger`（新增 `lib/src/core/services/app_logger.dart`，issue #1）。
- ✅ 被注释的 `print` 残留（`deep_seek_service.dart`）已删除；3 处失效的 `// ignore: avoid_print` 注释已移除。
- ✅ `avoid_print` lint 已在 `analysis_options.yaml` 启用，拦截未来新增的 `print`。
- ⚠️ 残余缺口（可选加固）：`avoid_print` 不覆盖 `debugPrint`；若要 CI 拦截 `debugPrint`，需引入 `custom_lint` 自定义规则。

---

## 3. UI 硬编码中文字符串（违反 l10n + 错误处理分离）

规范 §5 与 §8.1 要求：用户可读消息走 l10n，与内部细节分离。原始实测 **84 行**硬编码中文。

- ✅ `learning/presentation`（11 行）与 `settings/presentation`（1 行）已迁入 ARB（2026-08-13，issue #3）：词义/句子分析弹窗、详情视图、阿里云 DashScope 服务名。
- ⏳ 剩余 72 行 → issue #4（需设计决策）：
  - `learning/domain`（51 行）：`aliyun_tts_voice.dart` 音色中文名与描述——建议 enum 保留默认文案，设置页 switch 映射 l10n 键。
  - `learning/data`（15 行）：`LearningException` 用户可见消息——建议错误码 enum + 展示层映射（规范 §5「内部细节与用户文案分离」）。
  - `learning/application`（5 行）：StateError / FileSystemException 中文消息——同上。
  - `library/data`（1 行）：待排查。

---

## 4. reader 模块分层失衡

- `reader/presentation`：**4788 行 / 22 文件**（7 个 mixin + `reader_screen.dart` 661 行）。
- `reader/application`：**1 文件 / 147 行**（`reader_settings_notifier.dart`，通篇 SharedPreferences 的 get/set 透传）。

这是规范 §3「深模块 = 小接口大实现」的反例（浅模块），也印证 ADR-0001「reader 层逻辑集中在 UI」的判断。修复需先补 reader 测试安全网（当前 reader 零测试）。

---

## 5. 超 400 行源文件（规范 §2 要求拆分）

以下为**非生成文件**中超 400 行的（l10n 生成物与 `.g.dart` 不计）：

| 文件 | 行数 |
|------|------|
| `library/data/parsers/epub_zip_parser.dart` | 880 |
| `reader/presentation/reader_screen.dart` | 661 |
| `reader/presentation/reader_renderer.dart` | 551 |
| `reader/presentation/reader_webview.dart` | 545 |
| `core/theme/color_schemes.dart` | 545 |
| `core/file_handling/unified_import_service.dart` | 493 |
| `library/data/services/import_backup_service.dart` | 491 |
| `library/data/services/epub_import_service.dart` | 479 |
| `reader/presentation/control_panel.dart` | 478 |
| `library/presentation/library_screen.dart` | 461 |
| `library/application/bookshelf_notifier.dart` | 445 |
| `detail/presentation/book_detail_screen.dart` | 403 |

---

## 6. 测试覆盖缺口

- 5 个测试文件 / 149 个源文件（约 3%）。
- 测试集中在 `epub_parser` / `epub_import` / `learning`；**reader 全模块、library/settings/detail 零测试**。
- 无任何 widget test。

优先为 reader 的 mixin / 状态机补单元测试（复用 `epub_parser_test.dart` 的注入范式）。

---

## 7. 文档债（见 ADR-0002 与 CHANGELOG 漂移）

- `CHANGELOG.md` 存在两个 `[v0.2.3]`、`[Unreleased]` 位置错误，且仍写「首次启动自动迁移旧数据 / 新增 `isar_migration_test`」，与 ADR-0002 的「无需迁移、删除 legacy 目录与该测试」相矛盾（该目录与测试实际已删除）。
- `README.md` 与 `README_zh-CN.md` 内容重复，需同步维护。

---

## 优先修复顺序（建议）

1. **P0**：日志方案落定——引入 `custom_lint` 拦截 `debugPrint`，或全量迁 `logger`。
2. **P1**：reader 补测试安全网 → 再谈 reader 分层重构。
3. **P1**：learning 模块硬编码中文迁 l10n。
4. **P2**：增量修 `presentation → data` 违规（优先 `style_bottom_sheet.dart` 绕过 provider 的深违规）。
5. **P2**：CHANGELOG 修复与 README 去重。
