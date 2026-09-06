---
id: EVD-assistant-stream-render-2026-08-31
layer: evidence
title: Assistant 流式揭示渲染 2026-08-31
status: superseded
result: partial
owner: agent
upstream:
  - IMP-flutter-client
covers:
  - FX-094
  - FX-050
scope:
  - static
  - unit
commands:
  - make analyze
  - make test
  - make knowledge-check
observed_commit: b3818765cafaf4d6426f594f161cd367ea7a04c6
updated_at: 2026-08-31
---

# Assistant 流式揭示渲染 2026-08-31

## 范围与环境

前端 worktree `task/assistant-stream-render`。验证展示层字素揭示（FX-094）：presentation-only
display buffer、线性 `lockedGps` 追赶、`classifyMount` 重放、`response_reset` 淡出、双层
`GptMarkdown`、钉住底部滚动。不覆盖真实网关 SSE 代理或 `:3002` 手测（当时未作为本证据门）。

## 命令与结果

```text
make analyze
# No issues found! (ran in 3.7s)

make test
# 375 tests passed

make knowledge-check
# knowledge-check: OK (36 formal documents, 48 requirements, 79 local links)
```

## 条款证据

- `FX-094`：`streaming_reveal_test` 锁定 16ms 循环线性排空、空挂载后 live 大块不 `replaySnap`、
  剥离非前缀不 reset；`streaming_markdown_test` 覆盖加粗解析、reset 淡出、`disableAnimations`
  首帧全文、mount 重放、语义单节点。
- `FX-050`：`assistant_page_test` 仍渲染虚拟线程 Markdown 回答与来源卡。

本证据不把揭示测试写成 FX-090 协议覆盖。Notifier 事件机未改。

## 未证明范围

未在真实网关 / `:3002` CanvasKit 手测 200ms 批次插值、2KiB 代码块追赶、上翻不再被拽回。
`just e2e` 的 Assistant pytest 看不见 Flutter 揭示动画。

## 历史提交映射

frontmatter 原记录 `27197709a11eccdfe016ffa7e9d0c825ed363617`；主线重放后的等价提交为 `b3818765cafaf4d6426f594f161cd367ea7a04c6`。
迁移时以 `git range-diff` 核对，差异仅为提交内自引用 SHA/知识说明。
