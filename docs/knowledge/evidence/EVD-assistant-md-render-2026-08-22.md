---
id: EVD-assistant-md-render-2026-08-22
layer: evidence
title: Assistant 回答 Markdown 渲染 2026-08-22
status: superseded
result: passed
owner: agent
upstream:
  - IMP-flutter-client
covers:
  - FX-050
scope:
  - static
  - unit
commands:
  - flutter test
  - make knowledge-check
observed_commit: 5b2babbabcacdf9c968fae9b17987da245c5d976
updated_at: 2026-08-22
---

# Assistant 回答 Markdown 渲染 2026-08-22

## 范围与环境

Assistant 气泡展示层调整：assistant 回答正文改用 `gpt_markdown 1.1.8`
渲染（加粗、斜体、删除线、标题、有序/无序列表、代码块、表格、链接、引用、
LaTeX 等），沿用 Forui 主题排版与前景色；用户消息仍以纯文本原样显示，避免
用户输入被当作 Markdown 解释。既有引用/证据行剥离（见
EVD-assistant-evidence-strip-2026-08-22）在渲染前执行，剥离后的干净文本再进
Markdown 管道。SSE 契约、notifier 状态、repository 与流式行为均未改动。

依赖核对：Forui 0.24.2 组件索引（forui.dev/docs/llms.txt）无 Markdown 组件，
Flutter SDK 无内置渲染器，故新增 UI 依赖 `gpt_markdown`（专为 LLM 对话输出设
计，支持 web，无 url_launcher 等重传递依赖；代码块配色随 Material 亮暗主题自
适应）。工作树 `.worktree/task-assistant-md-render`。

## 命令与结果

```bash
flutter analyze
# 无 error（20 条存量 info/warning，与主检出逐条一致）
flutter test
# 172 个测试全部通过（新增 1 个）；
# assistant_page_test 新增「renders markdown structure in assistant reply only」：
# 断言回答中 **加粗** 生成 w600+ 权重的 TextSpan、列表项进入 RichText，
# 用户消息 'plain **not bold**' 仍是纯 Text 且页面仅有一个 GptMarkdown
make knowledge-check
# knowledge-check: OK (21 formal documents, 25 requirements, 59 local links)
```

## 条款证据

| 条款 | 观察 |
| --- | --- |
| `FX-050` | token 事件聚合文本的展示方式升级为 Markdown 渲染；消费 token/source/done/error 事件的流程、取消与断流保留部分文本的行为不变，测试覆盖流式完成后的结构化渲染 |

## 未证明范围

- 未连接真实网关人工核对流式中间帧：未闭合的 ``` 代码围栏或未成对标记在流式
  过程中可能短暂按字面显示，done 帧后收敛。
- 链接点击未接外跳（`onLinkTap` 未处理，需 url_launcher 或应用内 webview 决策），
  链接当前仅样式可见、不可点。
- LaTeX 渲染质量与长表格在窄气泡内的横向滚动表现未做真实环境验证。
