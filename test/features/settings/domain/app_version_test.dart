import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/features/settings/domain/app_version.dart';

/// 版本比较与 split APK 构建号归一化的纯逻辑。
void main() {
  group('AppVersion.isNewerThan', () {
    test('major 更高判为新', () {
      expect(
        const AppVersion(2, 0, 0).isNewerThan(const AppVersion(1, 9, 9)),
        isTrue,
      );
    });

    test('minor / patch 更高判为新', () {
      expect(
        const AppVersion(1, 3, 0).isNewerThan(const AppVersion(1, 2, 9)),
        isTrue,
      );
      expect(
        const AppVersion(1, 2, 4).isNewerThan(const AppVersion(1, 2, 3)),
        isTrue,
      );
    });

    test('同语义版本比构建号', () {
      expect(
        const AppVersion(
          1,
          2,
          3,
          build: 11,
        ).isNewerThan(const AppVersion(1, 2, 3, build: 10)),
        isTrue,
      );
      expect(
        const AppVersion(
          1,
          2,
          3,
          build: 10,
        ).isNewerThan(const AppVersion(1, 2, 3, build: 11)),
        isFalse,
      );
    });

    test('完全相同不判新；语义版本更低时构建号再高也不判新', () {
      const v = AppVersion(1, 2, 3, build: 10);
      expect(v.isNewerThan(v), isFalse);
      expect(
        const AppVersion(
          1,
          2,
          2,
          build: 99,
        ).isNewerThan(const AppVersion(1, 2, 3, build: 1)),
        isFalse,
      );
    });
  });

  group('AppVersion.parse', () {
    test('解析语义化版本串', () {
      final v = AppVersion.parse('0.2.2', buildNumber: 7);
      expect((v.major, v.minor, v.patch, v.build), (0, 2, 2, 7));
    });

    test('缺段按 0 补；非数字段按 0 处理', () {
      final v = AppVersion.parse('1.2', buildNumber: 0);
      expect((v.major, v.minor, v.patch), (1, 2, 0));
    });

    test('split APK 构建号按 1000 取余归一化', () {
      // 构建 1 的 arm64 包实际构建号为 1001
      expect(AppVersion.parse('1.0.0', buildNumber: 1001).build, 1);
      expect(AppVersion.parse('1.0.0', buildNumber: 2010).build, 10);
    });
  });
}
