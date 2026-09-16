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

    test('构建号取原值，四位数不被截断', () {
      // v1.0.0 的构建号按 MAJOR*10000+MINOR*100+PATCH 派生为 10000；
      // 取余归一化会把它截成 0，于是已是最新的用户会被反复提示更新。
      expect(AppVersion.parse('1.0.0', buildNumber: 10000).build, 10000);
      expect(AppVersion.parse('0.3.0', buildNumber: 300).build, 300);
    });
  });
}
