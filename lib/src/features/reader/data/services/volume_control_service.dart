import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:synlen/src/core/services/app_logger.dart';

class VolumeControlService {
  static const MethodChannel _methodChannel = MethodChannel(
    'synlen/volume_control',
  );
  static const EventChannel _eventChannel = EventChannel(
    'synlen/volume_events',
  );

  static Future<void> enableInterception() async {
    if (!Platform.isAndroid) return;
    try {
      await _methodChannel.invokeMethod('enableInterception');
    } on PlatformException catch (e) {
      appLogger.w('Volume interception enable failed: ${e.message}');
    }
  }

  static Future<void> disableInterception() async {
    if (!Platform.isAndroid) return;
    try {
      await _methodChannel.invokeMethod('disableInterception');
    } on PlatformException catch (e) {
      appLogger.w('Volume interception disable failed: ${e.message}');
    }
  }

  static Stream<String> get volumeKeyEvents {
    if (!Platform.isAndroid) return const Stream.empty();

    return _eventChannel.receiveBroadcastStream().map(
      (event) => event as String,
    );
  }
}
