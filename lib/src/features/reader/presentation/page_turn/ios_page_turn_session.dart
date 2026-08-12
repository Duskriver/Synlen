import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:synlen/src/core/services/app_logger.dart';

class IOSPageTurnSession {
  static const MethodChannel _nativePageTurnChannel = MethodChannel(
    'synlen/reader_page_turn',
  );

  int _currentToken = 0;
  bool _isAnimating = false;

  Future<void> _prepareIOSPageTurn() async {
    if (!Platform.isIOS) return;
    try {
      await _nativePageTurnChannel.invokeMethod<void>('preparePageTurn');
    } on MissingPluginException {
      // no-op for configurations without iOS native channel
    } catch (e) {
      appLogger.e('preparePageTurn failed: $e');
    }
  }

  Future<void> _animateIOSPageTurn(bool isNext, bool isVertical) async {
    if (!Platform.isIOS) return;
    try {
      final token = ++_currentToken;
      _isAnimating = true;
      await _nativePageTurnChannel.invokeMethod<void>('animatePageTurn', {
        'isNext': isNext,
        'isVertical': isVertical,
      });
      if (token == _currentToken) {
        _isAnimating = false;
        return;
      }
    } on MissingPluginException {
      // no-op for configurations without iOS native channel
    } catch (e) {
      appLogger.e('animatePageTurn failed: $e');
    }
  }

  Future<void> perform({
    required bool needAnimation,
    required bool isNext,
    required bool isVertical,
    required Future<void> Function(bool) onPerformPageTurn,
  }) async {
    if (!needAnimation) {
      await onPerformPageTurn(isNext);
      return;
    }

    await _prepareIOSPageTurn();
    await onPerformPageTurn(isNext);
    unawaited(_animateIOSPageTurn(isNext, isVertical));
  }

  Widget buildAnimatedContainer(BuildContext context, Widget child) {
    return child;
  }

  bool get isAnimating => _isAnimating;
}
