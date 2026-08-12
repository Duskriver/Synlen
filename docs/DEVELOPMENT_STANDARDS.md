# Synlen 开发规范

> 本文档是项目**唯一**的开发规范来源，人类与 AI 协作时共同遵守。
> 配套文档：`CONTEXT.md`（领域统一语言）、`docs/adr/`（架构决策记录）。

## 1. 架构总览

Feature-first + 分层架构。每个功能模块（feature）内部按四层组织，依赖**单向**流动：

```
presentation → application → domain
      ↓              ↓
      └──── data ←──┘   (data 实现 application 定义的接口，读取 domain 模型)
```

```
┌────────────────────────────────────────────────┐
│ features/                                       │
│   library/  reader/  learning/  settings/       │
│     presentation/  ←  Widgets、Screens          │
│     application/   ← Controllers、Coordinators  │
│     domain/        ← 实体、枚举、异常、纯逻辑     │
│     data/          ← Repositories、Services     │
├────────────────────────────────────────────────┤
│ core/  ← 跨模块共享：database、theme、router、   │
│           storage、services、providers、widgets  │
├────────────────────────────────────────────────┤
│ rust/  ← 性能敏感逻辑（FFI，经 core 暴露）       │
└────────────────────────────────────────────────┘
```

**规则：**

- **依赖方向**：`presentation → application → domain`；`data → domain`；`data` 可以被 `application` 依赖。**禁止** `presentation → data`（现状存在的分层违规见 `docs/TECH_DEBT.md` 清单，逐步修复）。**禁止** `domain → application/data/presentation`。
- **feature 之间**不互相 import。跨 feature 的共享能力必须下沉到 `core/`。
- **core 是共享工具箱**，不是杂物间：放进去的东西必须被 ≥2 个 feature 使用，否则留在所属 feature。

## 2. 分层职责

### domain（纯模型层）

- 实体（`ShelfBook`、`BookManifest`）、值对象、枚举（`AudioFormat`、`ReaderLinkHandling`）、领域异常（`LearningException`）。
- **纯 Dart 逻辑**：不 import Riverpod、不触碰 data/presentation。UI 类型（如 `Color`）仅在无法避免时允许（参考 `ReaderSettings` 引入 `AppThemeSettings` 的做法），优先使用纯类型。
- 命名：名词。文件即类型名（`shelf_book.dart`）。

### application（用例编排层）

- `@riverpod class XxxController extends _$XxxController` 或函数式 provider。
- 职责：编排 repository/service 调用、持有页面状态、错误转换（异常 → 用户可读状态）。
- **资源清理**：`build()` 中创建的资源（音频协调器、流订阅）必须在 `ref.onDispose` 中释放（参考 `SentenceLearningController`）。
- 命名：动词 + Controller/Coordinator/Notifier（`word_learning_controller.dart`）。

### data（数据访问层）

- Repository：Isar 存取（`ShelfBookRepository`）。
- Service：文件解析（`EpubZipParser`）、导入/导出（`epub_import_service.dart`）、备份、存储清理。
- **通过 provider 暴露**：`xxx_repository_provider.dart` / `xxx_service_provider.dart`，依赖从 `ref.watch(...)` 注入，**不在内部 `new` 自己的依赖**。
- 命名：`xxx_repository.dart` / `xxx_service.dart` / `xxx_parser.dart`。

### presentation（展示层）

- Widgets、Screens。只消费 provider（`ref.watch`），不直接构造 repository/service。
- 一个 Screen 一个文件；拆出的 widget 放 `presentation/widgets/`。
- 命名：`xxx_screen.dart` / `xxx_widget.dart`。文件超过 ~400 行必须拆。

## 3. 模块设计原则（深模块）

统一使用以下术语（不用 component / service / API / boundary 等替代词）：

| 术语 | 含义 |
|---|---|
| **Module** | 有接口和实现的东西：函数、类、包、跨层切片 |
| **Interface** | 调用者需要知道的全部：签名 + 不变量 + 错误模式 + 约束 |
| **Implementation** | 模块内部实现 |
| **Depth** | 接口的杠杆：每学 1 单位接口能获得的 behavior 量 |
| **Seam** | 可以在不改动内部的情况下替换行为的位置 |
| **Adapter** | 在 seam 上满足接口的具体实现 |
| **Leverage / Locality** | 深模块带给调用者/维护者的收益 |

**深模块** = 小接口 + 大实现（好）；**浅模块** = 大接口 + 薄实现（避免，例如只做转发的 getter/setter 外壳）。

设计接口时反复自问：

- 能减少方法数吗？能简化参数吗？能藏更多复杂度进内部吗？
- **删除测试**：删掉这个模块，复杂度会消失（说明是空转的浅模块）还是会散落到 N 个调用点（说明它在挣工资）？
- **seam 纪律**：只有一种实现的接口 = 假 seam，不建；有了两种真实实现才算数（测试 fake 也算一种）。
- **接口即测试面**：调用者和测试跨同一个 seam。如果想越过接口去测，模块形状可能错了。

可测试性三原则：

1. **接受依赖，不创建依赖** —— 依赖通过构造参数 / provider 注入。
2. **返回结果，不产生副作用** —— 纯函数优先，返回新对象而非原地修改。
3. **小接口面积** —— 方法越少、参数越简单，测试越少。

## 4. Riverpod 约定

- 依赖一律通过 `ref.watch` / `ref.read` 获取（参考 `shelf_book_repository_provider.dart` 的 `when(data/loading/error)` 三态处理模式）。
- `AsyncValue` 必须处理全部三态，禁止裸 `.value` 假设。
- `@riverpod class` 的 `build()` 只做初始化与订阅，异步加载放私有方法。
- 生成文件（`.g.dart`）**提交入库**、不手改，由 `build_runner` 维护。
- Provider 文件与实现文件分离：`shelf_book_repository.dart`（实现）+ `shelf_book_repository_provider.dart`（暴露）。

## 5. 错误处理

- 领域错误定义在 domain：`class XxxException implements Exception { final String message; }`，`toString() => message`。
- **捕获点**在 application 层：catch 后转为状态字段（`contentError`、`audioError`），UI 只渲染状态。
- 用户可读消息与内部细节分离（参考 `formatLearningError`）；内部细节记日志，不上屏。
- 禁止在 presentation 里 try/catch 业务异常并吞掉。

## 6. 领域语言与决策记录

### 统一语言（CONTEXT.md）

- 仓库根目录的 `CONTEXT.md` 是领域词汇表：**写作新代码前先查术语**；发现模糊/冲突术语立即更新它。
- 一个概念只有一个规范词，别称列入 `_Avoid_`。
- 代码命名必须使用规范词（类名、文件名、字段名）。

### 架构决策记录（ADR）

- 满足**全部三个条件**才写 ADR：① 难逆转；② 无上下文会困惑；③ 真实权衡的结果。
- 存放 `docs/adr/NNNN-slug.md`，序号递增。格式见 `0001`。
- 技术选型若带锁定效应（数据库、FFI 方案、播放引擎）必须记录；普通库不记。

## 7. 测试要求

- **测试是硬性要求**：新增/修改核心逻辑（domain、application、parser、import）必须带测试；纯 UI 改动可豁免但鼓励补 widget test。
- 分层策略：
  - domain → 纯单元测试（无 mock）
  - application → 注入 fake repository/audio（seam 处替换），测状态机与编排
  - data → 测 parser/import（已有 `epub_parser_test.dart` 为范例），Isar 仓库用真实临时库
- 命名：`xxx_test.dart` 与源码同目录；mock 产物 `.mocks.dart` 不手改。
- 依赖注入使测试不需要真实网络/文件系统/平台通道。

## 8. 代码风格与工具

### 语言约定（重要）

- **代码注释与文档字符串一律用中文**（含 `///` doc comment、`//` 行内注释、`/* */` 块注释）。
- **Markdown 文档一律用中文**（README、docs/、CONTEXT.md、ADR、issue 描述）。
- 以下必须保持英文（工具链/语法要求）：类名、变量名、文件名、枚举值、package 名、git 提交 type、命令行、issue 标签。
- 例外：注释中引用标识符/命令时使用原文，例如 `/// 通过 [ShelfBookRepository] 读取书目`。

### 工具

- **`flutter analyze` 必须零 error、零 warning** 才能提交。
- 提交前跑 `dart format` 与 `flutter test`。
- 日志用 `logger` 包，**禁止 `print` / `debugPrint`**（现状 55 处待清理）。
- 文案一律走 `l10n`（`app_localizations_zh.dart` / `app_localizations_en.dart`），禁止 UI 硬编码字符串。
- 自用 lint 规则逐步在 `analysis_options.yaml` 增加（如 `avoid_print`、`prefer_single_quotes`），改动需评审。
- codegen 命令：`dart run build_runner build --delete-conflicting-outputs`。

## 9. 提交与协作

- 提交信息格式：`type(scope): 描述`，type ∈ {feat, fix, refactor, chore, docs, test, perf, merge}。描述中文，简洁说明"为什么"而非"改了什么"。
- 提交粒度：一个逻辑改动一个 commit；**禁止把重构与功能混在一个 commit**。
- 提交前必须通过：`flutter analyze` + `flutter test` + `dart format`。
- 分支：`main` 保持可发布；功能在 `feat/xxx` 分支开发。

## 10. 增量重构纪律（架构决策 0001）

- **不搞 big-bang 重构**。新代码一律按本规范书写；旧代码遵循 **Boy Scout Rule**——路过即修，每次提交顺手清理所触及的文件。
- 重构与功能分离：同一文件的重构改动单独 commit（先重构、后功能，或分两次提交）。
- 技术债以清单形式记录（违规清单、TODO 集中到 `docs/TECH_DEBT.md`，不散落在代码注释里）。
- 某个区域成为新功能地基时（如 reader 支持多格式），才允许安排一轮专项重构；专项重构必须先补测试再动手。
