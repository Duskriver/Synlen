# ota_update 本地分支

本目录基于 [ota_update 7.1.0](https://pub.dev/packages/ota_update/versions/7.1.0)，保留原始 [MIT 许可证](LICENSE)、README 和变更记录。上游归档地址为 `https://pub.dev/api/archives/ota_update-7.1.0.tar.gz`，SHA-256 为 `1f4c7c3c4f306729a6c00b84435096ce2d8b28439013f7237173acc699b2abc8`。

保留 `lib/`、`android/`、`LICENSE`、`README.md`、`CHANGELOG.md`、`analysis_options.yaml` 和 `pubspec.yaml`；省略示例、独立 Gradle wrapper 和构建缓存。插件仍只提供 Android 实现，Dart 接口与上游一致。

## 本地修补

取消回执等待所属下载的文件流关闭、摘要校验退出，并在安装交接前复核取消标记。活动任务的身份保护事件流、进度和请求引用，旧任务未退出时不接受重试。已经启动的系统安装器不在取消范围内。决策理由与应用状态契约见[取消与终态所有权](../../.agents/notes/implemented/bug-fix/2026-09-21-ota-cancellation-ownership.md)。

[差异补丁](SYNlen.patch)包含原生实现和回归测试。重建时校验归档摘要、解压并保留上述文件，删除 `android/gradle/`、`android/gradlew`、`android/gradlew.bat`，再在包目录执行 `patch -p1 < SYNlen.patch`。本说明与补丁自身不参与源码重放。

在仓库根目录执行 `flutter pub get` 与 `bash tool/test_readium_android.sh`，使用 JDK 21 运行真实插件的 Robolectric 回归。测试用可控网络回调和校验闩锁验证并发顺序；安装交接后的系统界面仍需设备验收。

## Dev Note

None.
