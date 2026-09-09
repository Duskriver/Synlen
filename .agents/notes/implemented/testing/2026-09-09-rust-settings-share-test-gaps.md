# Agent Note: Rust EPUB 后端、字体导入与分享进入的测试缺口

Status: implemented

## Problem

评审指出三处测试缺口，均属"已有行为无证据"：

- `rust/src/api/epub.rs` 无任何 `#[test]`：中央目录解析、按条目读取、`load_epub` 幂等、50 MiB zip-bomb 守卫、字体混淆接线全靠 CI 的 `cargo test` 编译证明，用例数为 0。（`font_obfuscation.rs` 的纯函数测试由字体混淆改动线补上，不在本次范围。）
- `FontManagerNotifier`（settings/application）无测试：选择器取消、重名去重、单条失败继续、缓存清理与原生资源释放、删除字体这些分支没有回归网。
- 分享进入（`global_share_handler.dart`）无端到端测试：`pendingRouteFileProvider` → 导入管道 → 进度对话框 → 清空缓存 → 刷新书架的接线没有验证。

## Decision

- **Rust**：在 `rust/src/api/epub.rs` 内嵌 `#[cfg(test)] mod tests`，自带 stored 方法的 ZIP 构造器（手写本地头 / 中央目录 / EOCD + CRC32），不引入写 ZIP 的依赖。覆盖：路径归一化、媒体扩展名判定、未加载与文件不存在错误、读取幂等与 close 后失效、伪造声明大小触发 50 MiB 守卫、encryption.xml + OPF + 字体条目经 `load_epub` 派生还原参数后读出原文。临时 EPUB 路径唯一并在析构时删除，避免测试间共用全局 `EPUB_CACHE`。
- **字体导入**：手写 fake 继承 `UnifiedImportService`，只覆写 `pickFontFiles` / `processFontFile` / `cleanCache` / `releaseIosAccess` 四个入口（基类构造器无副作用）。`AppStorage.initForTesting` 指向临时目录，用 `container.listen` 保持 autoDispose provider 存活。覆盖取消、成功导入、重名、单条失败继续、删除。
- **分享进入**：widget 测试用子类 fake 替换 `LibraryNotifier`（记录传入路径并立刻以成功结束）与 `BookshelfNotifier`（记录刷新次数），只保留真实 `GlobalShareHandler` 与 `ProgressDialog`。断言：待处理路径交给导入管道、状态被消费、对话框出现、关闭后 `clearAllCache` 被调用且书架刷新一次。

## Alternatives considered

**加 `zip` crate 作 dev-dependency 构造测试 EPUB** —— 放弃：本次改动本身在回应供应链评审，手写 stored ZIP 约 90 行即可覆盖读取路径。

**用 mockito 生成 `UnifiedImportService` mock** —— 放弃：构造器无 I/O，手写 fake 更直观，也避免为两个文件触发 build_runner。

**分享测试只覆盖 `_ShareImportProgressDialog`** —— 放弃：私有类不可从测试导入，且真正的缺口在 provider → 导入 → 刷新的接线，而非对话框计数。

**分享测试跑真实导入链路（内存 Drift 库 + 真实 `BookImportService`）** —— 放弃：`testWidgets` 的 fake-async 不推进真实文件与数据库 I/O，`pumpAndSettle` 又会被不确定进度动画卡死；用子类 fake 替换两个 notifier 后，测的正是 handler 的接线（路径转发、状态消费、清缓存、刷新），真实导入本身已由 library 侧测试覆盖。

**用 `pumpAndSettle` 推进 widget 测试** —— 放弃：导入期间进度条是不确定动画，永不静止。

## Consequences

- `cargo test` 从 14 个用例增至 22 个，新增覆盖 `api/epub.rs` 的读取与守卫路径。
- 手写 ZIP 构造器只支持 stored 方法；将来需要 deflate 用例时需扩展。
- 分享测试不跑真实导入，只证明 handler 的转发与收尾接线；真实导入链路由 library 侧测试覆盖。
- 字体导入 fake 覆写的是 `UnifiedImportService` 的公开入口；若这些方法改名或改签名，测试会编译失败而非静默失真。
