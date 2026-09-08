# Agent Note: 音量键翻页的订阅与分发下沉 application

Status: implemented

## Problem

`reader_screen.dart` 的 `setupVolumeControl` 直接操作 `VolumeControlService` 的静态成员：判断启用条件、开关拦截、惰性订阅事件流、在事件回调里再读一次设置项。这段逻辑只能在真机上验证，屏幕每增加一个影响启用的条件（抽屉开合、前后台）都要改 State。

## Decision

`VolumeKeyPageTurnController`（reader/application）持有事件流与四个回调：`sync(enabled:)` 按宿主算出的条件开关拦截并只订阅一次；事件到达时用 `isEnabled` 复核（禁用期间在途的事件不翻页）；`dispose` 取消订阅并放开拦截。屏幕只负责把设置项、抽屉状态与生命周期组合成 `enabled`。

## Alternatives considered

**留在屏幕 State 里，只把事件流抽成参数** —— 放弃：启用条件与订阅生命周期仍散在 State，测试要构造整个屏幕。

**让控制器直接读 `readerSettingsProvider`** —— 放弃：application 层不该知道 Riverpod 之外的宿主状态（抽屉是否打开）；启用条件属于宿主。

**把 `VolumeControlService` 改成实例并注入** —— 放弃：它是平台通道的静态封装，本批次只搬订阅与分发，不动平台层。

## Consequences

- 音量键翻页的订阅、复核与释放有单元测试覆盖（`volume_key_page_turn_test.dart`，含"禁用期间在途事件不翻页"）。
- `reader_screen.dart` 少一个订阅字段与一段回调闭包；启用条件仍由宿主组合。
- 行为不变：启用条件、`up`/`down` 映射与禁用时放开拦截的时机逐字保留。
