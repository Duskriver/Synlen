import 'dart:io';

import 'package:flutter_readium/flutter_readium.dart';

/// 会话需要的原生能力；测试用内存实现验证打开、重排与关闭的顺序。
abstract interface class ReadiumGateway {
  Future<Publication> open(String path, EPUBPreferences preferences);
  Future<void> close();
  Future<void> go(Locator locator, {required bool animated});
  Future<void> turnPage(bool forward, {required bool animated});
  Future<String> resource(String href);
}

class NativeReadiumGateway implements ReadiumGateway {
  NativeReadiumGateway(this._readium);
  final FlutterReadium _readium;

  @override
  Future<Publication> open(String path, EPUBPreferences preferences) async {
    _readium.setDefaultPreferences(preferences);
    await _readium.setJavaScriptInjections([
      const InjectionAsset(assetPath: 'assets/reader/readium_learning.js'),
    ]);
    return _readium.openPublication(
      Platform.isIOS ? path : Uri.file(path).toString(),
    );
  }

  @override
  Future<void> close() => _readium.closePublication();

  @override
  Future<void> go(Locator locator, {required bool animated}) async {
    await _readium.goToLocator(locator, animated: animated);
  }

  @override
  Future<void> turnPage(bool forward, {required bool animated}) async {
    if (forward) {
      await _readium.goForward(animated: animated);
    } else {
      await _readium.goBackward(animated: animated);
    }
  }

  @override
  Future<String> resource(String href) => _readium.getResourceUrl(href);
}
