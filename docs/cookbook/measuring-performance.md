# 测量性能

性能基线回答四个问题：冷启动多久出首帧、导入一本大书多久、翻章卡不卡、阅读时内存峰值多少。**只用 profile / release 构建测量**，debug 数字没有参考价值。

## 步骤

1. **固定设备矩阵**：至少一台低端 Android（4 GB RAM 或 2019 年前后机型）+ 一台中端 Android；iOS 视需要补一台。每台测量前清空应用数据并冷启动。
2. **冷启动**：`flutter run --profile --trace-startup --trace-startup-file=/tmp/startup-<device>.json -d <device-id>`，从 trace 取首帧时间；或在 DevTools Performance 里录制启动区间。
3. **大书导入**：准备一本约 10 MB 的 EPUB，从书架导入并计时（DevTools Timeline 圈选导入区间，或临时在导入前后打 `Stopwatch` 日志）；同时记录该区间内存峰值。
4. **翻章延迟**：DevTools Performance 连续录制 10 次翻章，取单次帧时间，标出超过一帧预算（16.7 ms）的卡顿。
5. **阅读峰值内存**：DevTools Memory 分别在「导入中」「阅读中」「切换书籍」三个阶段记录 RSS 峰值。
6. **记录**：把中位数填进下面的基线表（同一操作重复 3 次取中位数）。

## 验证

1. 每个指标至少在低端 Android 上有一组数字。
2. 每行记录设备型号、系统版本、构建号与测量日期。
3. 数值可复现：同一设备同一操作重复测量，中位数波动在 ±10% 以内。

## 约束

- 测量前清空应用数据并冷启动，避免缓存与热启动干扰。
- 阅读器首屏受 Readium 出版物缓存与原生视口初始化影响；跨版本比较时必须保持相同缓存状态。
- 基线是回归对照，不是验收阈值；阈值等数据稳定后再定。

## Android arm64 打开图书

1. 连接 arm64 真机并开启 USB 调试，使用 JDK 21 构建。在仓库根目录执行 `flutter drive --profile --target=integration_test/reader_open_performance_test.dart --driver=test_driver/reader_performance_driver.dart -d <device-id>`。性能包使用独立的 `.profile` 应用 ID，原生依赖选择 release 变体；首次安装需允许手机的 USB 安装提示。
2. 测试在临时书库导入 120 章 EPUB，记录一次未命中出版物缓存的首开，再定位到书中并重开 5 次。生成测试书、导入、翻页和退出不计入打开耗时；结束时校验完整 Locator 恢复并删除临时书库。
3. 保存 `build/integration_response_data.json` 后重复命令至少 3 次。`prepareMs` 是文件准备耗时，`nativeOpenMs` 是原生出版物打开耗时；`viewportMs` 和 `readyMs` 均从路由进入开始计时。正文就绪要求原生 ready 和实际位置回执同时到达，不能用视口创建代替。
4. 对照版本使用同一设备、WebView、屏幕方向与构建配置，分别比较首开中位数和重开中位数。采样期间保持应用前台，记录温度；CPU / Perfetto 跟踪另跑，不将带采样开销的记录混入速度对比。

此测试衡量合成 EPUB 的打开链路，不包含导入速度，也不代表图片密集书籍、全部 EPUB 或 TXT 的性能。只清理独立测试包的临时书库；正式应用的数据不参与该流程。

## Dev Note

基线数据尚未采集，需要真机按上述步骤填入；模拟器的兼容性检查不构成性能基线。

| 指标 | 设备 | 构建 | 数值 | 日期 |
|---|---|---|---|---|
| 冷启动到首帧 | 待测 | 待测 | 待测 | 待测 |
| 10 MB EPUB 导入 | 待测 | 待测 | 待测 | 待测 |
| 翻章帧时间（中位 / 最差） | 待测 | 待测 | 待测 | 待测 |
| 阅读峰值内存 | 待测 | 待测 | 待测 | 待测 |
