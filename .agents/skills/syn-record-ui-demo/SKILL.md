---
name: syn-record-ui-demo
description: 为改变用户可见 UI 行为的 PR 录制演示 GIF 时使用——模拟器真实运行、状态驱动录制、ffmpeg 确定性编码、孤儿 assets 分支发布。当用户要求"录个演示 / demo GIF"或 UI 行为 PR 需要证据时触发。
---

# UI 演示录制（GIF）

> 每个改变用户可见 GUI 行为的 PR **必须**附用本技能录制的演示 GIF（开发流程 §5 评审要求）。
> GIF 是证据链的一部分：使用该 PR 分支的真实构建、真实数据路径（开发环境数据可以，mock 截图拼接不可以）。

## 1. 搭建

- 干净 worktree，记录确切 commit；在该树上构建并运行 app。
- 每个 PR 独立启动；一个 storyboard 一次证据运行，**绝不拼接不同运行的帧**。

## 2. 录制

- 选 3–6 个能讲完整故事的状态（如：书架空 → 导入中 → 阅读中 → 学习详情）。
- iOS：`xcrun simctl list` 拿 udid，`xcrun simctl io <udid> recordVideo --codec h264 <file>.mp4`。
- Android：`adb exec-out screenrecord --output-format=h264 - > <file>.mp4`（单段 ≤3 分钟，超时分段但必须同一次运行）。
- 产物落 gitignore 路径 `.demo-recordings/`（本仓库已忽略）。
- 录下一段前等待**具体 UI 条件**（控件出现 / 可点 / 状态就绪），不用固定延时；不捕获 API key 等敏感内容。

## 3. 编码 GIF

依赖 `ffmpeg` / `ffprobe`：

```bash
ffmpeg -i in.mp4 -vf "fps=8,scale=480:-1:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse" out.gif
```

文件过大先减宽度，再降帧率或颜色数；目标 ≤5 MB（利于 raw 嵌入）。

## 4. 验证产物

- 读 `ffprobe` 摘要确认时长 / 尺寸 / 大小；**直接查看编码后的 GIF**（而非源帧）：过渡清晰、末状态停留足够久、无敏感内容。
- 确认文件只在 `.demo-recordings/` 下。

## 5. 发布到 assets 分支（仅当需要嵌入 PR 时）

- GIF 存专用孤儿分支 `assets`（无父提交、只含媒体），**绝不提交到 PR 自身分支**；在浅 scratch clone 中操作，推送前校验 checksum。
- 只追加新提交，永不删除 / 重写 / 强推 `assets` 分支。
- 嵌入前核对 PR head commit 与录制时一致，用 `?raw=true` 的 raw blob URL 写入 PR 正文。

## 6. 如实报告

- 模拟器 / ffmpeg 不可用时**报告限制**，不得用静态截图拼接冒充演示。
- 录制条件（commit、设备、数据来源）在 PR 中如实声明。
