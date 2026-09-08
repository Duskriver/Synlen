# Agent Note: 文档门禁只校验源码路径

Status: implemented

## Problem

CI 的 docs job 在干净检出上失败，本地却通过：`docs/cookbook/changing-reader-web-assets.md` 引用 `web_assets/controller.js/node_modules/.bin/esbuild`，该路径只有跑过 `npm ci` 才存在。门禁把"文档里反引号包起来的仓库路径必须存在"当成源码事实，但这条断言只在装了依赖的开发机上成立——本地的 `node_modules` 掩盖了 CI 的失败。

## Decision

路径检查跳过生成或依赖目录（`node_modules`、`build`、`.dart_tool`）下的路径，与文档收集阶段已有的跳过规则保持一致；源码路径仍然必须存在。

## Alternatives considered

**改文档，不写这条路径** —— 放弃：构建脚本确实调用该 esbuild 二进制，读者需要知道位置，删掉事实是掩盖问题。

**在 CI 的 docs job 里先跑 `npm ci`** —— 放弃：为绕过一条检查而给纯文档任务装上整个前端工具链，成本与收益不成比例。

**让检查容忍所有不存在的路径** —— 放弃：那等于不检查，悬空引用会重新出现。

## Consequences

- 门禁断言的范围明确为"源码路径"；生成物与依赖目录的引用不受校验。
- 本地验证不能替代 CI：装了依赖的机器会掩盖这类失败，改门禁后要看一次 CI 结果。
