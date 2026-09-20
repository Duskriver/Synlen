import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// 由阅读会话持有，关闭等待在途创建和原生拆除，不依赖组件的晚到回调。
class ReaderPlatformViewLifecycle {
  ReaderPlatformViewLifecycle({
    required this.viewType,
    required this.creationParams,
    required this.onAllocated,
    required this.beforeDispose,
  });

  final String viewType;
  final Map<String, dynamic> creationParams;
  final ValueChanged<int> onAllocated;
  final Future<void> Function() beforeDispose;

  AndroidViewController? androidController;
  UiKitViewController? uiKitController;
  Future<void>? _creation;
  Future<void>? _disposal;
  bool _closed = false;
  bool _readerDetached = false;
  bool _platformDisposed = false;
  bool _controllerDisposeAttempted = false;
  TargetPlatform? _platform;
  int? _viewId;
  bool get hasStarted => _creation != null;
  bool get closed => _closed;

  Future<void> create(TargetPlatform platform, Size size) {
    if (_closed) return Future.value();
    return _creation ??= _create(platform, size);
  }

  Future<void> _create(TargetPlatform platform, Size size) async {
    final id = platformViewsRegistry.getNextPlatformViewId();
    _platform = platform;
    _viewId = id;
    // 通道先于原生创建接线，初始化失败也能回传给所属会话。
    onAllocated(id);
    if (platform == TargetPlatform.android) {
      final controller = PlatformViewsService.initSurfaceAndroidView(
        id: id,
        viewType: viewType,
        layoutDirection: TextDirection.ltr,
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
      );
      androidController = controller;
      await controller.create(size: size, position: Offset.zero);
    } else {
      uiKitController = await PlatformViewsService.initUiKitView(
        id: id,
        viewType: viewType,
        layoutDirection: TextDirection.ltr,
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
      );
    }
  }

  Future<void> dispose() {
    _closed = true;
    return _disposal ??= _disposeWithRetry();
  }

  Future<void> _disposeWithRetry() async {
    // State.dispose 只调用一次；瞬时通道失败在内部重试，持续失败不发虚假 ACK。
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await _dispose();
        return;
      } on Object {
        if (attempt == 1) {
          _disposal = null;
          rethrow;
        }
      }
    }
  }

  Future<void> _dispose() async {
    final creation = _creation;
    if (creation == null) return;
    try {
      await creation;
    } on Object {
      // 创建错误由视口报告；仍须清理已经分配的通道及可能部分创建的视图。
    }
    if (!_readerDetached) {
      await beforeDispose();
      _readerDetached = true;
    }
    if (_platformDisposed) return;
    try {
      final android = androidController;
      final uiKit = uiKitController;
      if (!_controllerDisposeAttempted && (android != null || uiKit != null)) {
        _controllerDisposeAttempted = true;
        if (android != null) {
          await android.dispose();
        } else {
          await uiKit!.dispose();
        }
      } else {
        // Android controller 在回包之前就进入 disposed，失败重试须直接请求引擎。
        await SystemChannels.platform_views.invokeMethod<void>(
          'dispose',
          _platform == TargetPlatform.android
              ? {'id': _viewId, 'hybrid': android?.requiresViewComposition ?? false}
              : _viewId,
        );
      }
    } on PlatformException catch (error) {
      // iOS 明确确认该 id 不存在时，创建失败或重复拆除均已无资源可释放。
      if (_platform != TargetPlatform.iOS || error.code != 'unknown_view') rethrow;
    }
    _platformDisposed = true;
  }
}

/// 保留 Flutter 平台视图的绘制与手势分发，生命周期由所属会话管理。
class ReaderPlatformView extends StatefulWidget {
  const ReaderPlatformView({
    required this.lifecycle,
    required this.platform,
    required this.onError,
    super.key,
  });

  final ReaderPlatformViewLifecycle lifecycle;
  final TargetPlatform platform;
  final void Function(Object, StackTrace) onError;

  @override
  State<ReaderPlatformView> createState() => _ReaderPlatformViewState();
}

class _ReaderPlatformViewState extends State<ReaderPlatformView> {
  bool _ready = false;

  void _create(Size size) {
    final lifecycle = widget.lifecycle;
    if (lifecycle.hasStarted || lifecycle.closed || size.isEmpty) return;
    unawaited(
      lifecycle
          .create(widget.platform, size)
          .then(
            (_) {
              if (mounted && !lifecycle.closed) setState(() => _ready = true);
            },
            onError: (Object error, StackTrace stack) {
              if (mounted && !lifecycle.closed) widget.onError(error, stack);
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _create(constraints.biggest);
      if (!_ready) return const SizedBox.expand();
      final android = widget.lifecycle.androidController;
      if (android != null) {
        return AndroidViewSurface(
          controller: android,
          gestureRecognizers: const {},
          hitTestBehavior: PlatformViewHitTestBehavior.opaque,
        );
      }
      return _ReaderUiKitSurface(controller: widget.lifecycle.uiKitController!);
    },
  );
}

class _ReaderUiKitSurface extends LeafRenderObjectWidget {
  const _ReaderUiKitSurface({required this.controller});

  final UiKitViewController controller;

  @override
  RenderUiKitView createRenderObject(BuildContext context) => RenderUiKitView(
    viewController: controller,
    hitTestBehavior: PlatformViewHitTestBehavior.opaque,
    gestureRecognizers: const {},
  );

  @override
  void updateRenderObject(BuildContext context, RenderUiKitView renderObject) {
    renderObject.viewController = controller;
  }
}
