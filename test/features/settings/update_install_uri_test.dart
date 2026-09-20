import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

void main() {
  test('ota_update 的 FileProvider 仅暴露插件下载目录，权限不包含静默安装', () {
    final manifest = XmlDocument.parse(
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
    );
    final provider = manifest
        .findAllElements('provider')
        .singleWhere(
          (element) =>
              element.getAttribute('android:name') ==
              'sk.fourq.otaupdate.OtaUpdateFileProvider',
        );
    expect(
      provider.getAttribute('android:authorities'),
      r'${applicationId}.ota_update_provider',
    );
    expect(provider.getAttribute('android:exported'), 'false');
    expect(provider.getAttribute('android:grantUriPermissions'), 'true');
    expect(
      provider
          .findElements('meta-data')
          .single
          .getAttribute('android:resource'),
      '@xml/ota_update_paths',
    );
    final paths = XmlDocument.parse(
      File(
        'android/app/src/main/res/xml/ota_update_paths.xml',
      ).readAsStringSync(),
    );
    final mapping = paths.rootElement.childElements.single;
    expect(mapping.name.local, 'files-path');
    expect(mapping.getAttribute('path'), 'ota_update/');
    final permissions = manifest.findAllElements('uses-permission');
    for (final removed in ['INSTALL_PACKAGES', 'WRITE_EXTERNAL_STORAGE']) {
      expect(
        permissions
            .singleWhere(
              (element) =>
                  element.getAttribute('android:name') ==
                  'android.permission.$removed',
            )
            .getAttribute('tools:node'),
        'remove',
      );
    }
    expect(
      permissions.any(
        (element) =>
            element.getAttribute('android:name') ==
            'android.permission.REQUEST_INSTALL_PACKAGES',
      ),
      isTrue,
    );
  });
}
