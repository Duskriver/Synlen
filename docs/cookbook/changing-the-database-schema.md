# 改数据库 schema

给 drift 表加表、加列或改列时走这套步骤。数据库定义在 `lib/src/core/database/app_database.dart`，迁移不可回退，存量用户的库必须能原地升级。

## 步骤

1. 改 `app_database.dart` 里的表定义（`ShelfBooks`、`BookManifests`、`WordExplanations` 等）。
2. 把 `schemaVersion` 加 1。
3. 在 `migration.onUpgrade` 里为新版本加一个 `if (from < N)` 分支，用 migrator 的 `addColumn` / `createTable` / `alterTable` 描述升级动作。新列必须给默认值或允许为空，否则存量行无法升级。
4. 重新生成 drift 产物：

   ```sh
   dart run build_runner build --delete-conflicting-outputs
   ```

5. 在 `test/database/migration_test.dart` 里补一段迁移测试，模式是：用原生 SQL 按**旧版本结构**建库并写入存量数据、把 `user_version` 设为旧版本、用 `AppDatabase` 打开触发迁移、断言存量行的新列取值与迁移后能正常读写。v1 → v2（`format` 列）的现有测试就是模板。
6. 更新受影响的 [subsystems 页](../subsystems/README.md)与 [glossary](../glossary.md)（表名或列语义变了的话），并在同一次改动里加一篇 [Agent Note](../../.agents/notes/README.md)。

## 验证

1. `dart run build_runner build --delete-conflicting-outputs` 无冲突输出。
2. `flutter analyze` 零 error 零 warning。
3. `flutter test test/database/migration_test.dart` 全绿。
4. `dart run tool/doc_gates.dart` 通过（文档引用与术语同步）。
5. 真机或模拟器上跑一次：用升级前的库启动，确认书架与阅读进度都在。

## 约束

- 迁移只做向前兼容，不写降级分支。
- 每个 schema 版本一个 `from < N` 分支，不合并、不重排。
- 改列类型属于破坏性变更：新建列 + 拷贝数据 + 删旧列，分两个版本完成。

## Dev Note

None.
