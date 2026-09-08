import 'dart:async';

/// 音量键翻页：拦截开关与事件分发。
///
/// 是否启用由宿主决定（设置项、抽屉开合、前后台状态），控制器只负责
/// "启用时订阅一次事件流、禁用时放开系统拦截"；事件到动作的映射交给回调，
/// 便于脱离平台服务单测。
class VolumeKeyPageTurnController {
  VolumeKeyPageTurnController({
    required Stream<String> events,
    required void Function() enableInterception,
    required void Function() disableInterception,
    required void Function() onPreviousPage,
    required void Function() onNextPage,
    required bool Function() isEnabled,
  }) : _events = events,
       _enableInterception = enableInterception,
       _disableInterception = disableInterception,
       _onPreviousPage = onPreviousPage,
       _onNextPage = onNextPage,
       _isEnabled = isEnabled;

  final Stream<String> _events;
  final void Function() _enableInterception;
  final void Function() _disableInterception;
  final void Function() _onPreviousPage;
  final void Function() _onNextPage;
  final bool Function() _isEnabled;

  StreamSubscription<String>? _subscription;

  /// 按 [enabled] 同步拦截状态；首次启用时订阅事件流。
  ///
  /// 订阅只建立一次，因此事件到达时仍要用 [_isEnabled] 复核——禁用期间
  /// 已在途的事件不应翻页。
  void sync({required bool enabled}) {
    if (!enabled) {
      _disableInterception();
      return;
    }
    _enableInterception();
    _subscription ??= _events.listen(_handleEvent);
  }

  void _handleEvent(String event) {
    if (!_isEnabled()) return;
    if (event == 'up') {
      _onPreviousPage();
    } else if (event == 'down') {
      _onNextPage();
    }
  }

  /// 取消订阅并放开系统拦截。
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _disableInterception();
  }
}
