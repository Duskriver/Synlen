import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'app_database.dart';

part 'providers.g.dart';

/// AppDatabase provider（keepAlive：数据库生命周期与 App 一致）。
/// 用 [AppDatabase] 的 QueryExecutor 注入点，测试时可通过
/// `appDatabaseProvider.overrideWithValue(AppDatabase.forTesting(NativeDatabase.memory()))` 替换。
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  return AppDatabase();
}
