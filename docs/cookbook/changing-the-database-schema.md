# 改数据库 schema

给 drift 表加表、加列或改列时走这套步骤。数据库定义在 `lib/src/core/database/app_database.dart`。结构变更必须提供保留用户数据的向前迁移；受支持版本见 [core](../subsystems/core.md#流程)。

## 步骤

1. 改 `app_database.dart` 里的表定义（`ShelfBooks`、`BookManifests`、`WordExplanations` 等）。
2. 把 `schemaVersion` 加 1，并明确本次支持的起始版本。迁移放在事务内，失败回滚数据、结构与版本号，禁止自动删库。
3. 在 `migration.onUpgrade` 为受支持版本实现升级动作。新增列必须提供默认值或允许为空；改列类型使用可验证的数据转换，不静默丢弃旧值。
4. 重新生成 drift 产物：

   ```sh
   dart run build_runner build --delete-conflicting-outputs
   ```

5. 在 `test/database/migration_test.dart` 补测试：新库可创建并往返受影响字段；以旧 SQL 结构写入样本、设置旧 `user_version`，再打开 `AppDatabase` 验证保留数据、新结构读写、重复打开与失败回滚。
6. 更新受影响的 [subsystems 页](../subsystems/README.md)与 [glossary](../glossary.md)（表名或列语义变了的话），并在同一次改动里加一篇 [Agent Note](../../.agents/notes/README.md)。

## 验证

1. `dart run build_runner build --delete-conflicting-outputs` 无冲突输出。
2. `flutter analyze` 零 error 零 warning。
3. `flutter test test/database/migration_test.dart` 全绿。
4. `dart run tool/doc_gates.dart` 通过。
5. 真机或模拟器验证新安装；支持升级时，再用升级前的库确认书架与进度完整保留。

## 约束

- 不写降级分支；迁移按版本前进，避免依赖执行顺序不明的隐式默认值。
- 开发库重置不等于用户数据迁移；发布前需重新确认适用范围，不能沿用“无用户”的假设。
- 旧章节坐标保留来源格式，只能近似恢复；收到原生有效定位后才写完整 Locator。

## Dev Note

None.
