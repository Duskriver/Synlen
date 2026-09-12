# Agent Note: 从未传入的 widget/函数参数删除

Status: implemented

## Problem

一批参数从未被传入非默认值，对应的非默认分支是死代码：

- `BookCover.enableBorder` / `cacheHeight`（`lib/src/core/widgets/book_cover.dart`）：6 个生产调用点（`lib/src/features/reader/presentation/toc_drawer.dart:328`、`lib/src/features/reader/presentation/reader_webview.dart:279`、`lib/src/features/library/presentation/book_detail_view_body.dart:53`、`lib/src/features/library/presentation/book_detail_edit_body.dart:53`、`lib/src/features/library/presentation/book_grid_item.dart:210,236`）无一传入，`enableBorder` 的 false 分支与 `cacheHeight` 的非默认分支是死代码。
- `ToastBubble.useBlur` / `iconOverride`（`lib/src/core/widgets/toast_bubble.dart`）：唯一构造点 `lib/src/core/services/toast_service.dart:164` 不传；非 blur 分支死代码；`_iconForType` 永不返回 null，`icon != null` 恒真。
- `consumeLearningContentStream` 的 `throttle` 参数（`lib/src/features/learning/application/learning_controller_support.dart`）：两个调用点（`lib/src/features/learning/application/word_learning_controller.dart:195`、`lib/src/features/learning/application/sentence_learning_controller.dart:172`）均用默认值；这两个 controller 已并入 `learning_controller.dart`（见 [词/句学习 controller 与 repository 合并](2026-09-12-word-sentence-learning-merge.md)），现唯一调用点在 `lib/src/features/learning/application/learning_controller.dart`。
- `FlutterSoundLearningAudioPlayer.logLevel`（`lib/src/features/learning/application/learning_audio_player.dart`）：两个构造点（`lib/src/features/learning/application/learning_audio_coordinator.dart:35`、`lib/src/features/learning/application/learning_controller_support.dart:13` 的工厂 tear-off）均不传。

## Decision

删除这些参数与随之死掉的代码分支；`throttle` 降为文件内私有常量 `_kThrottle`，`logLevel` 内联 `Level.error`。`BookCover.globalCacheHeight` 不再有外部使用方，同步降为私有 `_cacheHeight`。

## Alternatives considered

**保留作为样式开关** —— 落败：无调用方的开关是投机泛化；需要时从 git 历史恢复成本低。

**主动找场景用上它们** —— 落败：没有真实需求驱动，为用而用只会扩大测试与维护面。

## Consequences

rg 确认各参数在 `lib/` 内无非默认传入，删除后 `flutter analyze` 零 error 零 warning，相关 widget 与 learning 测试通过。参数真被需要时从 git 历史恢复成本低。

## Dev Note

None.
