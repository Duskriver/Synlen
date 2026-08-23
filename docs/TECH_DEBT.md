# 技术债清单

> 本文件集中记录代码库的技术债（违规清单、待清理项），是 ADR-0001 增量重构纪律的追踪载体。
> 规则：新代码一律按 `DEVELOPMENT_STANDARDS.md` 书写；旧代码遵循 Boy Scout Rule——路过即修。
> 每清理一条，删除对应条目并注明清理 commit；发现新债时追加，不散落在代码注释里。

建立时间：2026-08-12（架构诊断后首建）。

---

## 1. 分层违规：presentation 直连 data

规范 §1 禁止 `presentation → data`，且禁止 feature 之间互相 import。当前实测 **11 处**违规（原 ADR-0001 记录「7 处」过时；2026-08-13 曾为 13 处，已修复 2 处）。

| # | 文件 | 违规性质 |
|---|------|----------|
| 1 | `lib/src/features/detail/presentation/book_detail_helpers.dart` | 引 `library/data/services` |
| 2 | `lib/src/features/detail/presentation/book_detail_screen.dart` | 引 `library/data/repositories` |
| 3 | `lib/src/features/library/presentation/mixins/library_actions_mixin.dart` | 引 `library/data/services` |
| 4 | ~~`lib/src/features/library/presentation/widgets/style_bottom_sheet.dart`~~ | ✅ 已修复（issue #7）：`ShelfBookSortBy` 下沉 domain，不再引 data |
| 5 | `lib/src/features/library/presentation/widgets/restore_progress_dialog.dart` | 引 `library/data/services` |
| 6 | `lib/src/features/reader/presentation/reader_webview.dart` | 引 `reader/data` |
| 7 | `lib/src/features/reader/presentation/reader_renderer.dart` | 引 `reader/data` |
| 8 | `lib/src/features/reader/presentation/image_viewer.dart` | 引 `reader/data` |
| 9 | `lib/src/features/reader/presentation/reader_screen.dart` | 引 `reader/data` + **跨 feature 引 `library/data`**（6 处 import） |
| 10 | `lib/src/features/reader/presentation/widgets/footnot_popup_overlay.dart` | 引 `reader/data` |
| 11 | `lib/src/features/settings/presentation/widgets/clean_cache_tile.dart` | **跨 feature 引 `library/data/services`** |
| 12 | `lib/src/features/settings/presentation/widgets/backup_tile.dart` | **跨 feature 引 `library/data/services`** |
| 13 | ~~`lib/src/features/reader/domain/epub_theme.dart`~~ | ✅ 已修复（issue #6）：`colorToHex` 下沉 domain，domain→data 清零，顺带消除 epub_theme↔reader_scripts 循环 import |

修复方向：reader 的 `data`（book_session / epub_webview_handler / reader_scripts / epub_stream_service）要么下沉到 `core/`，要么在 `application` 层提供编排接口；settings/detail 跨 feature 依赖改为经 `library/application` 暴露的 provider。

---

## 2. 日志规范（✅ 已清理，2026-08-12）

规范 §8 要求「日志用 `logger` 包，禁止 `print` / `debugPrint`」。

- ✅ 54 处 `debugPrint` 已全部迁移到全局共享实例 `appLogger`（新增 `lib/src/core/services/app_logger.dart`，issue #1）。
- ✅ 被注释的 `print` 残留（`deep_seek_service.dart`）已删除；3 处失效的 `// ignore: avoid_print` 注释已移除。
- ✅ `avoid_print` lint 已在 `analysis_options.yaml` 启用，拦截未来新增的 `print`。
- ⚠️ 残余缺口（可选加固）：`avoid_print` 不覆盖 `debugPrint`；若要 CI 拦截 `debugPrint`，需引入 `custom_lint` 自定义规则。

---

## 3. UI 硬编码中文字符串（✅ 已清理，2026-08-13）

规范 §5 与 §8.1 要求：用户可读消息走 l10n，与内部细节分离。原始实测 **84 行**硬编码中文。

- ✅ `learning/presentation`（11 行）与 `settings/presentation`（1 行）已迁入 ARB（issue #3）。
- ✅ 异常消息与状态错误（data 15 行 + application 5 行）已错误码化（issue #4）：`LearningErrorCode` enum + 展示层 `resolveLearningErrorText` 统一映射为 l10n 文案；`LearningException.details` 仅入日志，不上屏（规范 §5）。
- ✅ `library/data`（1 行）：备份分享标题改为调用方传入 l10n 文案。
- ✅ 已决策保留（数据性文案，非 UI 文案）：
  - `aliyun_tts_voice.dart`（51 行）：47 个音色的名称与描述是产品目录数据（人名、方言地名、人设描述），非界面文案；全部迁 ARB 需 94 键，成本远大于收益。
  - `deep_seek_service.dart`（6 行 LLM prompt）：发给 AI 的提示词，机器消费，非 UI 文案。

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

## 6. 测试覆盖缺口（reader 已补两批，2026-08-13）

- **10 个测试文件 / 149 个源文件**（约 7%），**84 个用例**全绿。
- ✅ reader 首批 27 用例（issue #5）：`ReaderSettings` / `EpubTheme` / `ReaderSettingsNotifier` / `EpubWebViewHandler`。
- ✅ reader 第二批 12 用例：`BookSession`（spine 过滤、TOC 查找映射、URL/索引解析、激活目录解析、进度防抖落库、初始位置）。
- ⏳ 仍无 widget test；reader 的 6 个 mixin 是 part 文件（依赖 `reader_screen.dart`），单测需先拆分或改 widget test；library / settings / detail 仍零测试。

---

## 7. 文档债（✅ 已清理，2026-08-24）

- ✅ `CHANGELOG.md` 漂移（重复 `[v0.2.3]`、`[Unreleased]` 位置、与 ADR-0002 矛盾的迁移表述）：经核对已在早期修正（单一版本号、`[Unreleased]` 归位、迁移表述与 ADR-0002 一致），本清单未及时销账；2026-08-24 进一步移除历史条目的英文重复段落，全文件为中文。
- ✅ `README.md` 与 `README_zh-CN.md` 内容重复：2026-08-24 统一为单一中文 `README.md`，删除 `README_zh-CN.md`；同批删除过时的英文 `.github/prompts/AGENT_INSTRUCTIONS.md`（内容与规范 §8.1、ADR-0002 冲突）。

---

## 优先修复顺序（建议）

1. **P0**：日志方案落定——引入 `custom_lint` 拦截 `debugPrint`，或全量迁 `logger`。
2. **P1**：reader 补测试安全网 → 再谈 reader 分层重构。
3. **P1**：learning 模块硬编码中文迁 l10n。
4. **P2**：增量修 `presentation → data` 违规（优先 `style_bottom_sheet.dart` 绕过 provider 的深违规）。
