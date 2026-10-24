import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/core/file_handling/native_file_picker.dart';
import 'package:synlen/src/core/file_handling/platform_path.dart';
import 'package:synlen/src/core/file_handling/unified_import_service.dart';

class _DisplayNamePicker extends NativeFilePicker {
  _DisplayNamePicker(this.name);
  final String? name;
  final queried = <String>[];

  @override
  Future<String?> resolveDisplayName(String uri) async {
    queried.add(uri);
    return name;
  }
}

void main() {
  const android = AndroidUriPath(
    'content://com.android.providers.downloads.documents/document/1000000018',
  );
  test('数字 SAF ID 向原生查询显示名，并保留真实扩展名', () async {
    final picker = _DisplayNamePicker('  阅读字体.otf  ');
    final service = UnifiedImportService(picker: picker);
    expect(await service.resolveFileName(android), '阅读字体.otf');
    expect(picker.queried, [android.uri]);
  });

  for (final missing in [null, '', '  ']) {
    test('显示名不可用时沿用路径名：$missing', () async {
      final service = UnifiedImportService(picker: _DisplayNamePicker(missing));
      expect(await service.resolveFileName(android), android.name);
    });
  }

  test('本地文件不查询 SAF，保持原始文件名', () async {
    final picker = _DisplayNamePicker('错误名称.ttf');
    final service = UnifiedImportService(picker: picker);
    expect(
      await service.resolveFileName(const IOSFilePath('/source/字体.ttf')),
      '字体.ttf',
    );
    expect(picker.queried, isEmpty);
  });
}
