# Agent Note: Android 正文完成排版后及时上报位置

Status: implemented

## Problem

Android Readium Navigator 对所有位置通知统一等待 100ms。当前章节已经完成 WebView 视觉状态确认并恢复 Locator 时，宿主仍要等待防抖结束才能解除加载状态；邻章完成预加载还会取消并重新安排当前页的位置通知。

## Decision

可重排 EPUB 只在当前 WebView 完成页面加载时立即计算实际位置；计算仍要求页面已加载且 Navigator 已结束恢复。邻章的完成事件保留公开页面回调，但不改变当前页就绪状态或位置调度。滚动、普通翻页和固定版式保留原有 100ms 防抖，任务仍归属视图生命周期。

Android 性能包采用独立应用 ID，并为原生依赖选择 release 变体，允许 adb 采集 CPU 与系统跟踪。基准通过真实文件准备、Readium 视口和完整 Locator 回执记录首开与重开耗时，使用临时书库，不修改正式版数据。步骤由[性能手册](../../../../docs/cookbook/measuring-performance.md#android-arm64-打开图书)维护。

## Alternatives considered

**全局缩短或删除防抖**：滚动和翻页仍会产生中间位置，提前保存可能损坏恢复位置。只有页面完成回调提供已经排版并完成定位的条件。

**创建视口后便结束加载**：视口存在不代表正文可见或已到保存的位置，无法作为打开完成的判据。

## Consequences

运行时修改只位于 Android Navigator；iOS 与出版物校验、净化和磁盘缓存的契约不变。消除的是页面完成后的等待，不保证任意书籍的解析和排版都在固定时间内完成。

## Testing

真实 Navigator 的 Robolectric 测试覆盖当前页立即通知、邻章完成不额外通知、不提前确认未完成的当前页、滚动通知合并、邻章不重启滚动防抖，以及销毁后取消回执。Android 设备基准同时核对重开时的完整 Locator 与实际章内位置。

同一真机的阅读验收覆盖 TXT / EPUB、跨章、字号重排、退出后恢复、快速关闭重开，以及真实短点、长按、拖动翻页和取消触摸；取消后章节与物理页保持不变。发布 APK 仅包含 arm64-v8a，8 个 ELF 加载段与 APK ZIP 条目通过 16 KB 对齐检查。

2026-09-20，型号 2510DRK44C、Android 17、arm64-v8a、WebView 150.0.7871.181，Flutter profile / 原生 release 配置下各测 3 轮。测试 EPUB 有 120 章、每章 100 段，压缩包 125174 字节；首开使用新的临时出版物缓存，重开恢复到中间章节。下表不含 CPU 或 Perfetto 采样开销，也不含导入。

| 指标 | 原版本 | 优化后 | 降幅 |
|---|---|---|---|
| 首开中位数，3 次 | 857.9ms | 767.5ms | 10.5% |
| 重开中位数，15 次 | 407.8ms | 294.0ms | 27.9% |

这些结果只代表该设备与合成 EPUB；不同书籍、首次安装初始化和系统负载会改变耗时，不能外推到全部藏书。

## Related

本决策补充 [Readium 引擎决策](../architecture/2026-09-20-readium-reader-engine.md) 的 Android 就绪时序。已有[重开成本修复](2026-09-20-readium-reopen-cost.md)处理文件校验复用与目录解析，继续独立生效；没有完全被取代的活跃笔记。
