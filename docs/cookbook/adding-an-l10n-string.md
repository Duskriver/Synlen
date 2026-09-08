# 加一条用户可见文案

给按钮、提示、错误消息加文案时走这套步骤。文案的唯一来源是 ARB：`lib/l10n/app_en.arb` 是模板，`lib/l10n/app_zh.arb` 是中文，两者同批更新。

## 步骤

1. 确认它真的用户可见：屏幕文字、无障碍标签、错误提示都走 ARB；日志、断言、内部异常消息留在代码里。
2. 在 `lib/l10n/app_en.arb` 加条目，key 用 camelCase 语义名，紧跟的 `@key` 写 `description`：

   ```json
   "deleteBooksConfirm": "Delete selected books permanently?",
   "@deleteBooksConfirm": { "description": "删除书籍确认对话框正文" }
   ```

3. 在 `lib/l10n/app_zh.arb` 加同名 key 与 `@key`，位置与英文条目对齐，`description` 用中文。
4. 需要参数时用占位符，类型写在模板的 `placeholders` 里，生成的方法就有对应形参：

   ```json
   "selected": "{count} selected",
   "@selected": {
     "description": "选择计数标签",
     "placeholders": { "count": { "type": "int" } }
   }
   ```

5. 复数用 ICU 语法，例如 `cleanCacheSuccessWithCount` 的 `{count, plural, =1{file} other{files}}`；中文侧没有复数形式，直接写 `{count}`。
6. 重新生成：`flutter gen-l10n`。`flutter pub get` 同样会触发，因为 `pubspec.yaml` 里 `generate: true`。生成物 `lib/l10n/app_localizations.dart`、`lib/l10n/app_localizations_en.dart`、`lib/l10n/app_localizations_zh.dart` 提交入库、不手改。
7. 使用：`AppLocalizations.of(context)!.key`，带参数时 `l10n.selected(count)`。
8. 错误码到文案的映射放展示层：`domain` 只定义错误码，`application` 把异常转成状态字段，展示层用 `switch` 映射，参考 `lib/src/features/learning/presentation/widgets/learning_detail_dialog_view.dart` 的 `resolveLearningErrorText`。
9. 不在 presentation 里硬编码用户可见字面量。`analysis_options.yaml` 只开了 `avoid_print`，没有硬编码字符串的 lint，靠评审与搜索兜底。

## 验证

1. `flutter gen-l10n` 无报错。
2. `rg -n '"<newKey>"' lib/l10n/app_en.arb lib/l10n/app_zh.arb` 两个文件各命中一次。
3. `flutter analyze` 零 error 零 warning，新 getter 能解析。
4. 下面这条命令输出为空，说明没有把中文直接写进 `Text(...)`：

   ```sh
   rg -n --pcre2 "Text\(\s*['\"][^'\"]*[一-龥]" lib/src/features --glob "*.dart"
   ```

5. `git status --short lib/l10n` 里 ARB 与生成物出现在同一次改动中。
6. `flutter run -d <device-id>` 打开受影响页面，确认文案与占位符替换正确。

## 约束

- 两个 ARB 的 key 集合并非逐字对齐：`app_zh.arb` 里有 `language`、`theme` 这类只有中文侧使用的条目。同批更新指同一次改动补齐两边，不是自动校验。
- 生成物 `lib/l10n/app_localizations*.dart` 不手改，改了也会被下一次生成覆盖。

## Dev Note

实测（Flutter 3.44.9，本机）：`flutter analyze` 不会重新生成 `app_localizations*.dart`，`flutter gen-l10n` 与 `flutter pub get` 会写文件。
