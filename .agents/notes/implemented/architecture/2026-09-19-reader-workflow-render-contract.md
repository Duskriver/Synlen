# Agent Note: 阅读会话拥有时序，渲染接口返回完成结果

Status: implemented

## Problem

目录跳转、内部链接与翻页各自维护目录刷新和进度保存；主题 mixin 跨异步调用配对导航忙态。新增入口需要了解多个对象的调用顺序，退出页面时还要处理迟到结果。导航接口暴露 WebView token，主题更新对三个 iframe 重复发送同一个回执，使等待方无法据此判断整个排版是否完成。

## Decision

`ReaderWorkflow` 组合 `BookSession`、`ReaderNavigator` 与 `ReadingProgressController`，拥有导航、主题队列、进度采集和关闭。书目加载与视口初始化分开；导航与排版期间不采集位置，保留上一份有效进度。连续主题请求只保留最后一份待应用参数，正在执行的排版完成后再处理下一份；关闭立即停止采集和通知，并返回最终保存结果。

`ReaderViewport.prepareChapters` 接受章节窗口并等待全部完成。token 只存在于 `WebViewBridge` 与 JavaScript 通信内部。桥接器先订阅回执再执行脚本；未挂载、脚本执行失败、超时与卸载都会使 Future 失败，迟到 token 不影响新命令。主题刷新在修改尺寸之前采集位置比例，全部 iframe 完成后只发送一次回执。

桥接挂载按原生视口 ID 判定生命周期。Headless WebView 转为可见时插件会创建新的 Dart 控制器并再次通知创建，但底层视口 ID 保持不变；这次交接只替换执行器，保留在途请求。实际更换视口或卸载才取消请求，否则正文已经显示时仍会误报排版失败。

`ReaderWebEvent` 是独立的纯 Dart 解码入口，检查事件名称、参数数量、类型和有限坐标。展示层注册函数只分发已验证事件。图片、脚注与 Flutter 主题解析仍属于 presentation；目录高亮与页码显示订阅导航状态，业务进度无需各入口触发。

## Alternatives considered

**继续把页面切成 part 文件**：可以减少单文件长度，但调用顺序与生命周期仍由页面承担，无法用 fake 视口验证完整阅读流程。

**把现有导航器、进度控制器全部合并**：二者分别拥有位置与持久化规则，测试面已经清晰；阅读会话只组合它们，不复制其状态。

**只在 Dart 聚合主题回执**：同一个 token 无法区分三个 iframe 是否全部完成；完成语义由 JavaScript 操作实现拥有，Dart 只等待一个结果。

**每次控制器创建回调都取消请求**：Dart 控制器与原生视口并非一一对应，会把 Headless 转场中的正常交接误判为关闭。完全取消生命周期检查又会接纳真正旧视口的迟到结果，因此按原生 ID 区分。

## Consequences

- 页面通过会话发起导航，通过状态订阅更新展示；关闭后的异步结果不修改阅读状态。
- 渲染失败在 application 转成错误状态，用户消息经 l10n 映射，内部异常只入日志。
- 单元测试控制预载和主题的完成时机，覆盖重入、关闭、错误恢复和进度采集；桥接测试覆盖同步与乱序回执、超时、同视口交接和真正更换视口。
- Chromium 与 WebKit 测试执行真实三 iframe 渲染，验证翻章、比例恢复与主题单次完成回执。设备冒烟入口为 `integration_test/reader_smoke_test.dart`，从书架推入阅读页，经过转场并断言无错误日志，不需要 AI 密钥。

## Related

本决策部分扩展[导航状态机](2026-09-09-reader-navigation-state-machine.md)与 [WebView 展示文件拆分](2026-09-09-reader-webview-part-files.md)：二者继续分别拥有位置规则和展示层私有状态，其拆分理由仍然有效。
