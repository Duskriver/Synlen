import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 仅显式设备测试启用的回环协调器，原生输入由 XCTest 执行。
class NativeTouchDriver {
  static const enabled = bool.fromEnvironment('SYNLEN_NATIVE_GESTURE_PROBE');
  HttpServer? _server;
  Map<String, Object>? _pending;
  int _nextId = 0;
  int _completed = 0;
  bool _finished = false;
  bool _acknowledged = false;

  Future<void> start() async {
    if (!enabled) return;
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8766);
    _server!.listen((request) async {
      if (request.uri.path == '/performed') {
        _completed = int.parse(request.uri.queryParameters['id']!);
      }
      if (request.uri.path == '/finish') _acknowledged = true;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({'finished': _finished, 'touch': _pending}),
      );
      await request.response.close();
    });
  }

  Future<void> tap(WidgetTester tester, Offset point) =>
      _perform(tester, point, Duration.zero);

  Future<void> hold(WidgetTester tester, Offset point, Duration duration) =>
      _perform(tester, point, duration);

  Future<void> _perform(
    WidgetTester tester,
    Offset point,
    Duration duration,
  ) async {
    if (!enabled) {
      if (duration == Duration.zero) {
        await tester.tapAt(point);
      } else {
        final gesture = await tester.startGesture(point);
        await tester.pump(duration);
        await gesture.up();
      }
      return;
    }
    final id = ++_nextId;
    _pending = {
      'id': id,
      'x': point.dx,
      'y': point.dy,
      'duration': duration.inMilliseconds / 1000,
    };
    final deadline = DateTime.now().add(const Duration(seconds: 90));
    while (_completed < id && DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    _pending = null;
    expect(_completed, id, reason: '原生输入未到达；使用 tool/test_ios_native_touch.sh');
  }

  Future<void> close(WidgetTester tester) async {
    if (_server == null) return;
    _finished = true;
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!_acknowledged && DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await _server!.close(force: true);
  }
}
