# Agent Note: 工具链固定在已验证的 Flutter 生态组合

Status: implemented

## Problem

Flutter 的测试依赖、代码生成器与 Android 插件共同约束可用版本。曾经 Flutter 3.44 的测试依赖限制 analyzer 12，阻止 Riverpod 与 Drift 生成器升级；原有 Gradle 8.14 也无法使用 Android Studio 的 Java 25。分别追逐单项最新版本会造成依赖不可解和本地、CI 构建漂移。

## Decision

- 本地与 CI 固定 Flutter 3.47.8 stable、Dart 3.13.7；`pubspec.yaml` 声明相同最低版本，`pubspec.lock` 记录整套解析结果。生成器使用 analyzer 13 可解的 Riverpod 4.0.9 与 Drift 2.35.2，不用 `dependency_overrides` 绕过 SDK 约束。
- Android 使用 Flutter 支持的 Gradle 9.3.1、AGP 9.1.1 与 Kotlin 2.4.0；daemon JVM 固定 Java 25，本机复用 Android Studio JBR，CI 安装同主版本 JDK。源码字节码目标继续为 Java 17，JDK 路径不入库。
- 所有 Android 模块使用 AGP 内置 Kotlin；应用与本地 Navigator 移除 `kotlin-android`，序列化和 Parcelize 插件在宿主统一锁定 Kotlin 2.4.0。图片压缩等第三方插件沿用已兼容内置 Kotlin 的官方版本，不维护额外 pub 缓存补丁。
- `android.builtInKotlin=true` 明确选择内置编译器；`android.newDsl=false` 保留至 Flutter 自身支持新 DSL。Flutter 3.47.8 的 `FlutterPlugin.addFlutterTasks` 仍向 `AbstractAppExtension` 强转，启用新 DSL 会构建失败。Readium 本地补丁内核保持现有版本，工具链升级不改变阅读契约。
- Node 24 LTS 由 `.nvmrc` 固定，本地 NVM 与 CI 读取同一文件；Web 工具使用 npm 锁文件。
- 所有 GitHub Actions 固定到 commit SHA，由 Dependabot 提更新 PR（见[依赖审计](2026-09-09-dependency-audit-and-dependabot.md)）。升级同批更新环境文档、workflow 与生成物，验证全量 Flutter 测试、Web 测试、Android 原生测试及 APK 构建；本轮升级仅验证 Android。

## Alternatives considered

**分别跟随每项工具的最新版本**：AGP 最新版本要求比 Flutter 已知支持范围更高的 Gradle；未经组合验证直接升级会扩大不兼容范围。

**继续单独维护 JDK 21**：旧 Gradle 需要它，但新构建链已支持 Android Studio JBR 25，继续保留会增加本地与 CI 的版本分歧。

**用 `dependency_overrides` 强拉最新依赖**：绕过 SDK 的传递依赖约束，可能破坏测试和代码生成。

**直接删除两个兼容开关**：Flutter 迁移器会重新添加默认的 `false`，而新 DSL 的阻碍位于 Flutter 构建插件本身；单独升级第三方插件不能解决。

## Consequences

- 升级前先核对 SDK、生成器与原生插件的兼容范围；环境操作以[开发文档](../../../../docs/development.md#环境)为准。
- Java 构建运行时与应用字节码目标分别管理；Android Studio 更新到其他 Java 主版本时，必须重新验证并同步 daemon 配置和 CI。
- Dependabot 的解析环境可能忽略 SDK 钉版；[lock 漂移门禁](2026-09-19-lock-drift-gate.md)继续校验锁文件可复现性。
