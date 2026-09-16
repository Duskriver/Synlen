# Agent Note: 只发 arm64 单 ABI 包

Status: implemented

## Problem

首版发布的产物里，universal APK 是 83.7 MB：它把三套 ABI 的原生库打进一个包（实测 arm64-v8a 25.6 MB、armeabi-v7a 24.2 MB、x86_64 26.8 MB，合计 76.6 MB）。而发布约束要求 `androidApkUrl` 必须指向 universal 包，于是**每次应用内更新，用户要下 83.7 MB，实际只用到其中约 25 MB**。

真机只有 arm64 与 armeabi-v7a 两种架构，x86_64 只有模拟器用得上。体积大头是每套 ABI 各一份的 Flutter 引擎（`libflutter.so` 8–12 MB）与 AOT 产物（`libapp.so` 12–14 MB），不是业务代码——本仓库自己的 Rust 部分只有 0.8 MB。所以压缩体积的杠杆在 ABI 数量，不在代码。

## Decision

- Android 只构建 arm64 单 ABI 包：APK 加 `--target-platform android-arm64`；产物名从 `<tag>-universal-release.apk` 改为 `<tag>-arm64-release.apk`，`tool/upload_release.sh` 的定位、上传键与清单 URL 同步改名。
- 删除 CI 里的 `Build Split APKs` 步骤与脚本里的 split 上传循环：只有一个 ABI 时 split 不再产生额外产物。
- `AppVersion.parse` 去掉 `buildNumber % 1000` 归一化。归一化是为 split 构建的 `abiCode * 1000 + build` 前缀偏移准备的（Flutter Gradle 里该 override 严格嵌套在 `shouldProjectSplitPerAbi` 判断内），不再产出 split 后它只会造成伤害：构建号规则是 `MAJOR*10000+MINOR*100+PATCH`，v1.0.0 起就是 10000，取余会截成 0，而清单里的构建号是原值，比较结果失真会让已是最新的用户被反复提示更新。

## Alternatives considered

**清单里增加按 ABI 的直链，客户端用 `Abi.current()` 选择** —— 放弃：这是三 ABI 时代的最优解，但只发 arm64 后没有可选项，多一套协议字段与客户端分支换不到任何收益。

**保留 arm64 + armeabi-v7a，只去掉 x86_64** —— 放弃：包体约 57 MB，仍是单 ABI 的两倍；arm64 已是真机的绝对主流，为极少数 32 位设备付这个代价不值。

**保留 split 与 universal 并存，清单继续指向 universal** —— 放弃：这正是 83.7 MB 下载量的来源，把兼容性成本转嫁给了每个用户。

## Consequences

- 32 位真机与 x86_64 模拟器不再能安装。将来若要支持，需同时恢复多 ABI 构建与清单侧的 ABI 选择逻辑，并注意 split 的构建号前缀偏移会随之回来。
- 已安装 v0.3.0 split 包（versionCode 带 `2 * 1000` 前缀，即 2300）的设备**无法**用新的单包（301）覆盖安装——Android 拒绝 versionCode 回退，必须先卸载。v0.3.0 未对外发布，实际只影响本机测试安装。
- 构建号与 versionCode 从此同口径（`MAJOR*10000+MINOR*100+PATCH`），清单与本地的比较不再经过任何变换。
- 发布门禁与 iOS 的关系见[Gitee ARM64 分发](2026-09-17-release-distribution-via-gitee.md)。
