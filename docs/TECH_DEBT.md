# 技术债清单

> 本文件集中记录代码库的技术债（违规清单、待清理项），是 ADR-0001 增量重构纪律的追踪载体。
> 规则：新代码一律按 `DEVELOPMENT_STANDARDS.md` 书写；旧代码遵循 Boy Scout Rule——路过即修。
> 每清理一条，删除对应条目并注明清理 commit；发现新债时追加，不散落在代码注释里。

建立时间：2026-08-12（架构诊断后首建）；最近校准：2026-09-08。

---

## 1. 分层违规：presentation 直连 data

规范 §1 禁止 `presentation → data`，且禁止 feature 之间互相 import。当前实测 **7 个文件 / 16 处 import** 违规（全部集中在 detail 与 reader 内部）（原 ADR-0001 记录「7 处」过时；2026-08-13 曾为 13 处，已修复 2 处）。

| # | 文件 | 违规性质 |
|---|------|----------|
| 1 | `lib/src/features/detail/presentation/book_detail_helpers.dart` | 引 `library/data/services` |
| 2 | `lib/src/features/detail/presentation/book_detail_screen.dart` | 引 `library/data/repositories` |
| 3 | ~~`lib/src/features/library/presentation/mixins/library_actions_mixin.dart`~~ | ✅ 已修复：`UnifiedImportService` 的 provider 移到 `core/providers/`（该服务被 3 个 feature 消费） |
| 4 | ~~`lib/src/features/library/presentation/widgets/style_bottom_sheet.dart`~~ | ✅ 已修复（issue #7）：`ShelfBookSortBy` 下沉 domain，不再引 data |
| 5 | ~~`lib/src/features/library/presentation/widgets/restore_progress_dialog.dart`~~ | ✅ 已修复：进度事件类型下沉 `library/domain/import_progress.dart`，顺带消除 `data → application` 逆向依赖 |
| 6 | `lib/src/features/reader/presentation/reader_webview.dart` | 引 `reader/data` |
| 7 | `lib/src/features/reader/presentation/reader_renderer.dart` | 引 `reader/data` |
| 8 | `lib/src/features/reader/presentation/image_viewer.dart` | 引 `reader/data` |
| 9 | `lib/src/features/reader/presentation/reader_screen.dart` | 引 `reader/data` + **跨 feature 引 `library/data`**（6 处 import） |
| 10 | `lib/src/features/reader/presentation/widgets/footnot_popup_overlay.dart` | 引 `reader/data` |
| 11 | ~~`lib/src/features/settings/presentation/widgets/clean_cache_tile.dart`~~ | ✅ 已修复：跨 feature 编排移入 `settings/application/cache_cleanup.dart`（ADR-0003 组合面） |
| 12 | ~~`lib/src/features/settings/presentation/widgets/backup_tile.dart`~~ | ✅ 已修复：导出用例移入 `settings/application/backup_export.dart`（ADR-0003） |
| 13 | ~~`lib/src/features/reader/domain/epub_theme.dart`~~ | ✅ 已修复（issue #6）：`colorToHex` 下沉 domain，domain→data 清零，顺带消除 epub_theme↔reader_scripts 循环 import |
| 14 | ~~`lib/src/features/settings/presentation/widgets/settings_ai_service_section.dart`~~ | ✅ 已修复：连通性检查移入 `settings/application/deep_seek_connectivity.dart`（ADR-0003） |

修复方向：reader 的 `data`（book_session / epub_webview_handler / reader_scripts / epub_stream_service）要么下沉到 `core/`，要么在 `application` 层提供编排接口；`detail` 业务归属 library，按 ADR-0003 的结论并入 library 后再修其内部 `presentation → data`。

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

- `reader/presentation`：**4852 行 / 22 文件**（7 个 mixin + `reader_screen.dart` 689 行）。
- `reader/application`：**2 文件 / 232 行**（`reader_settings_notifier.dart` 146 行，通篇 SharedPreferences 的 get/set 透传；`reading_progress_controller.dart` 86 行，已具备可注入的落库 seam）。

这是规范 §3「深模块 = 小接口大实现」的反例（浅模块），也印证 ADR-0001「reader 层逻辑集中在 UI」的判断。reader 已有单测安全网（见 §6），可开始增量重构（见 ADR-0001）。

---

## 5. 超 400 行源文件（规范 §2 要求拆分）

以下为**非生成文件**中超 400 行的（l10n 生成物与 `.g.dart` 不计）：

| 文件 | 行数 |
|------|------|
| `library/data/parsers/epub_zip_parser.dart` | 880 |
| `reader/presentation/reader_screen.dart` | 689 |
| `core/file_handling/unified_import_service.dart` | 618 |
| `library/data/services/epub_import_service.dart` | 568 |
| `reader/presentation/reader_renderer.dart` | 550 |
| `core/theme/color_schemes.dart` | 545 |
| `reader/presentation/reader_webview.dart` | 544 |
| `library/data/services/import_backup_service.dart` | 518 |
| `reader/presentation/control_panel.dart` | 477 |
| `library/presentation/library_screen.dart` | 454 |
| `library/presentation/mixins/library_actions_mixin.dart` | 423 |
| `library/application/bookshelf_notifier.dart` | 423 |
| `detail/presentation/book_detail_screen.dart` | 403 |

---

## 6. 测试覆盖缺口（reader 已补两批，2026-08-13）

- 2026-09-08 更新：**35 个测试文件 / 157 个自有源文件（约 22%）**，**246 个用例**全绿（另有 2 个条件跳过：真实 DeepSeek 接口验收）。
- ✅ reader 首批 27 用例（issue #5）：`ReaderSettings` / `EpubTheme` / `ReaderSettingsNotifier` / `EpubWebViewHandler`。
- ✅ reader 第二批 12 用例：`BookSession`（spine 过滤、TOC 查找映射、URL/索引解析、激活目录解析、进度防抖落库、初始位置）。
- ✅ TXT 支持批次（2026-08-26）：TXT 解码/章节切分/内容供给/DB v1→v2 迁移，新增 4 个测试文件 45 用例。
- ✅ TXT 支持批次随修的预存在缺陷（2026-08-26，均已修复并带回归测试）：
  - `LibraryNotifier` 为 autoDispose，导入流是 async*（方法体推迟到对话框订阅才执行），调用方只 `read` 无监听导致 provider 先被销毁，导入必然中断 → 改 `@Riverpod(keepAlive: true)`；
  - TXT 章节 XHTML 缺 `xmlns`，按 `application/xhtml+xml` 解析时元素无 HTML 语义，分页引擎注入样式失败、段落展平 → 补命名空间；
  - `saveBook`/`saveManifest` 对新书（id=0）显式写主键 rowid 0，第二次导入的 upsert 覆盖第一本书整行（书架上永远只剩最后一本）→ id=0 时主键缺席走自增；
  - 导入失败回滚调 `_deleteFile(绝对路径)`，而该方法把入参当相对路径再拼 `documentsPath`，拼出的路径不存在导致回滚从未真正删除书籍文件，且删除未 await 存在竞态 → `_deleteFile` 兼容相对/绝对路径，回滚处改为等待删除完成（2026-08-29）。
- ✅ 恢复开发批次（2026-09-05/06）：学习请求生命周期与取消、备份恢复往返（库内 SQLite）、恢复对话框 widget test、学习弹窗 widget test、音频清退与学习缓存清理测试。
- ⏳ reader 的 6 个 mixin 是 part 文件（依赖 `reader_screen.dart`），单测需先拆分或改 widget test；settings / detail 仍零测试；无端到端测试。

---

## 7. 文档债（✅ 已清理，2026-08-24）

- ✅ `CHANGELOG.md` 漂移（重复 `[v0.2.3]`、`[Unreleased]` 位置、与 ADR-0002 矛盾的迁移表述）：经核对已在早期修正（单一版本号、`[Unreleased]` 归位、迁移表述与 ADR-0002 一致），本清单未及时销账；2026-08-24 进一步移除历史条目的英文重复段落，全文件为中文。
- ✅ `README.md` 与 `README_zh-CN.md` 内容重复：2026-08-24 统一为单一中文 `README.md`，删除 `README_zh-CN.md`；同批删除过时的英文 `.github/prompts/AGENT_INSTRUCTIONS.md`（内容与规范 §8.1、ADR-0002 冲突）。

---

## 8. `Epub` 命名与实际多格式职责不符（2026-08-26 新增）

TXT 支持落地后，以下以 `Epub` 命名的组件实际已同时处理 EPUB 与 TXT（经 `BookFormat` 分支）：

| 组件 | 实际职责 |
|------|----------|
| `EpubImportService` / `epub_import_workers.dart` | 导入编排，内部按格式分发到 EPUB/TXT 解析 |
| `EpubWebViewHandler` 与 `epub://` 虚拟域 | 阅读内容供给，TXT 章节也经此域返回 XHTML |
| 原生侧 `pickEpubFiles` / `isEpubFile`（Kotlin/Swift） | 文件/文件夹选择，已接受 `.txt` |

修复方向：后续路过时统一改为格式中立命名（如 `BookImportService`、`BookWebViewHandler`、`book://` 域）。虚拟域改名牵连 WebView handler、URL 拦截规则与 JS 侧资源引用，需独立 ticket 评估，不在本次范围内。

---

## 9. 「打开方式 / 分享进入」intent-filter 已声明但无处理代码（2026-08-29 新增）

`AndroidManifest.xml` 已为 TXT 新增（EPUB 更早就有）`ACTION_VIEW` / `ACTION_SEND` 的 intent-filter，iOS `Info.plist` 也注册了文档类型，因此系统层面 Synlen 会出现在「打开方式」列表中；但 Dart 与原生两侧都没有接收 intent 并转入导入流程的代码，点进来什么也不会发生。对 EPUB 而言是预存在缺口，TXT 放大其暴露面。

修复方向：接入 intent 接收（如 `receive_sharing_intent` / `app_links`），把 content URI 交给既有 `importPipelineStream`；需真机验证 SAF 权限与时序，走独立 ticket。

---

## 10. 注释语言与规范 §8.1 不符（2026-09-08 新增）

规范 §8.1 要求注释与文档字符串一律中文，但实测 `lib/src` 的 1646 行注释中 **1071 行（65.1%）为纯英文**，集中在 ADR-0001 之前写就的旧模块：

| 文件 | 英文注释 / 总注释行 |
|------|------|
| `core/file_handling/unified_import_service.dart` | 92 / 124 |
| `core/theme/app_theme_settings.dart` | 63 / 70 |
| `library/data/parsers/epub_zip_parser.dart` | 63 / 63 |
| `core/file_handling/import_cache_manager.dart` | 51 / 68 |
| `library/data/services/import_backup_service.dart` | 50 / 82 |
| `library/data/services/epub_import_service.dart` | 37 / 54 |

修复方向：随 Boy Scout Rule 路过即译，不做一次性批量翻译（翻译不改行为却淹没 diff）；`lib/src/rust/**` 与 `frb_generated*` 是生成物，不计入。

---

## 优先修复顺序（建议）

> 2026-09-08 校准：§4/§5/§6 的数字已按当前代码重测；原列表中「reader 补测试」「learning 硬编码中文」「style_bottom_sheet」均已销账。

1. **P1**：增量修 `presentation → data` 违规（§1 表中 11 个文件，reader 侧与跨 feature 引用为主）。
2. **P1**：reader 分层重构（§4），按 ADR-0001 增量推进。
3. **P2**：引入 `custom_lint` 拦截 `debugPrint`（§2 的可选加固）。
4. **P2**：`Epub` 命名多格式化（§8）、intent 接收（§9）。
5. **P3**：注释语言按路过即译推进（§10）。
