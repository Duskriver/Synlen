# 新增一个 feature 模块

在 `lib/src/features/` 下加一个模块时走这套步骤。分层方向与模块边界见 [architecture.md](../architecture.md)，接口形状按 [design.md](../design.md) 的深模块标准判断，命名用 [glossary.md](../glossary.md) 的规范词。

## 步骤

1. 先确认这确实是一个新 feature：只有一个 feature 用的能力留在它内部，被 ≥2 个 feature 使用才下沉 `lib/src/core/`。
2. 建目录骨架，只建用得上的层：

   ```text
   lib/src/features/<feature>/
     domain/        ← 实体、枚举、异常、纯逻辑
     data/          ← Repository、Service、Parser
     application/   ← Controller、Coordinator、装配入口
     presentation/  ← Widget、Screen
   ```

3. `domain`：放实体、值对象、枚举与 `XxxException`（`toString() => message`）。纯 Dart，不 import Riverpod，不碰 data 与 presentation。
4. `data`：实现与暴露分文件——`xxx_repository.dart` / `xxx_service.dart` 写实现，`xxx_repository_provider.dart` / `xxx_service_provider.dart` 暴露；依赖从 `ref.watch` 注入，不在内部 `new`。范例是 `lib/src/features/library/data/services/book_import_service.dart` 与同目录的 `book_import_service_provider.dart`。
5. `application`：用 `@riverpod class XxxController extends _$XxxController` 或函数式 provider。`build()` 只做初始化与订阅，异步加载放私有方法；`build()` 里创建的资源（音频协调器、流订阅、控制器）必须在 `ref.onDispose` 里成对释放。跨 feature 只调对方 `application` 的入口，例如宿主经 `lib/src/features/learning/application/learning_entry.dart` 使用学习能力。
6. `presentation`：只 `ref.watch` provider，不构造 repository 或 service。`AsyncValue` 三态齐全，禁止裸 `.value`，写法参考 `lib/src/features/library/presentation/library_screen.dart` 里的 `bookshelfState.when(...)`。
7. 错误落点：错误码枚举放 `domain`（参考 `lib/src/features/learning/domain/learning_exception.dart`）；`application` 捕获异常后转成状态字段，presentation 只渲染状态。用户可读文案在展示层映射，参考 `lib/src/features/learning/presentation/widgets/learning_detail_dialog_view.dart` 的 `resolveLearningErrorText`；内部细节只进 `appLogger`（`lib/src/core/services/app_logger.dart`）。
8. l10n：新增的用户可见文案走 ARB，流程见 [adding-an-l10n-string](adding-an-l10n-string.md)。
9. 入口：页面在 `lib/src/app_router.dart` 注册 `GoRoute`；跨 feature 复用的 provider 放 `lib/src/core/providers/`。
10. 测试：与源码镜像同目录，`lib/src/features/<feature>/<layer>/xxx.dart` 对应 `test/features/<feature>/<layer>/xxx_test.dart`。`domain` 写纯单元测试，`application` 在 seam 处注入 fake，`data` 的 Drift 仓库用真实临时库；按 [testing.md](../testing.md) 选覆盖改动的最小证据。
11. codegen：模型或 provider 注解变更后跑 `dart run build_runner build --delete-conflicting-outputs`；`.g.dart` 提交入库、不手改。
12. 文档同步：在 `docs/subsystems/{module}.md` 新增一页（类型、语义、边界、已知限制），并在 [architecture.md](../architecture.md) 的模块表加一行；非平凡改动同时写一篇 [Agent Note](../../.agents/notes/README.md)。

## 验证

1. `flutter analyze` 零 error 零 warning。
2. `dart run build_runner build --delete-conflicting-outputs` 无冲突，再跑 `flutter analyze`，`git status` 里没有未提交的 `.g.dart` 漂移。
3. `flutter test test/features/<feature>` 全绿。
4. `dart run tool/doc_gates.dart` 通过。
5. `flutter run -d <device-id>` 打开新页面，加载 / 空 / 错误三态都渲染出来。

## 约束

- 只有一种实现的接口不建 seam，等出现第二种真实实现（测试 fake 也算）再抽。
- 新 feature 不得 import 其他 feature 的 `data` 或 `presentation`；确实需要跨 feature 时先改 [architecture.md](../architecture.md) 的跨 feature 依赖表。

## Dev Note

None.
