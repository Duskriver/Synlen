import 'package:dio/dio.dart';
import 'package:synlen/src/features/learning/domain/learning_cancellation.dart';

/// 将查询取消连接到单个 HTTP 请求，释放时解除监听并关闭响应流。
class LearningHttpRequest {
  LearningHttpRequest(LearningCancellation? cancellation) {
    _unregister = cancellation?.onCancel(cancelToken.cancel);
  }

  final cancelToken = CancelToken();
  void Function()? _unregister;

  Stream<T> bind<T>(Stream<T> stream) async* {
    try {
      yield* stream;
    } finally {
      dispose();
    }
  }

  void dispose() {
    _unregister?.call();
    _unregister = null;
    cancelToken.cancel();
  }
}
