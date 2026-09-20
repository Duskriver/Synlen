# Agent Note: 性能测量方法先行，基线待真机

Status: implemented

## Problem

评审指出运行时只有设计判断、没有实测基线：启动串行 await、全局 Headless WebView 预热不释放、三 iframe 阅读器、TXT 全文本驻留这些取舍，无法判断是否真的达标；也没有设备矩阵与测量方法，回归只能靠感觉。

## Decision

- 落库[测量性能](../../../../docs/cookbook/measuring-performance.md)手册：固定四个指标（冷启动到首帧、10 MB EPUB 导入、翻章帧时间、阅读峰值内存）、设备矩阵（至少低端 + 中端 Android）、工具（`--trace-startup`、DevTools Performance / Memory）与记录格式（中位数 + 设备/构建/日期）。
- 只测 profile / release 构建；测前清空应用数据并冷启动，跨版本比较保持相同的出版物缓存与初始化状态。
- 基线数值本身**不伪造**：手册的 Dev Note 留空表，标注"待真机采集"，采集后再填。

## Alternatives considered

**先在 CI 里加性能冒烟测试** —— 放弃：CI 是共享 runner，噪声大于信号；基线必须在目标设备上采。

**改 `main.dart` 加启动耗时日志直接出数** —— 放弃：临时日志会随采集结束腐烂，且 debug 构建的数字不可比；`--trace-startup` 已能给出首帧时间。

**定死验收阈值** —— 放弃：没有历史数据时阈值只能拍脑袋；先有基线，再谈阈值。

## Consequences

- 采集一次即可填入手册的 Dev Note，之后每次大改（reader 引擎、导入链路、Rust 解压）按同一方法复测对照。
- 本 issue 的"识别一个可立即优化的点"要等第一轮数据；在此之前不做性能优化。
