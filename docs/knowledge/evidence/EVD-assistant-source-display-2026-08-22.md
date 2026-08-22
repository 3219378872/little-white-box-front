---
id: EVD-assistant-source-display-2026-08-22
layer: evidence
title: Assistant 引用标记隐藏与来源 ID 展示 2026-08-22
status: verified
owner: agent
upstream:
  - IMP-flutter-client
covers:
  - FX-051
updated_at: 2026-08-22
observed_commit: c359c573027fd865cf64a968f47364d168f3ce70
---

# Assistant 引用标记隐藏与来源 ID 展示 2026-08-22

## 范围与环境

Assistant 气泡展示层调整：assistant 回答文本中的 `[type:id]` 内联引用标记不再显示（用户消息
原样保留），可跳转来源按钮同时显示标题与 `sourceType:sourceId`（无标题时仅显示后者）。纯展示层
改动，不触碰 SSE 契约、notifier 状态与 repository。工作树 `.worktree/task-assistant-source-display`，
任务提交 `c359c573027fd865cf64a968f47364d168f3ce70`。

标记来源对照：工作区 `little-white-box-content-community` 的 assistant 工具结果会向模型输出
`SOURCE [post:<id>]`（`app/assistant/rpc/internal/tool/registry.go`），模型将其复制进回答文本；
前端此前原样渲染该标记并与结构化来源按钮重复。

## 命令与结果

```bash
flutter analyze
# 无 error（20 条存量 info）
flutter test
# 172 个测试全部通过；assistant_page_test 扩展两条断言：
# 含 [post:7] 标记的回答只显示清理后文本，且按钮出现 post:7 标签；
# 无标题来源按钮仅显示 post:9
make knowledge-check
# knowledge-check: OK (18 formal documents, 25 requirements, 55 local links)
```

## 条款证据

| 条款 | 观察 |
| --- | --- |
| `FX-051` | 可点击来源仍只接受已验证帖子并跳转 `/post/<id>`；按钮标签新增 `sourceType:sourceId` 使帖子 ID 在界面上可见，回答正文中的内联引用标记由 `stripCitationMarkers` 隐藏，不把未知标记当作可点击证据 |

## 未证明范围

- 未连接真实网关做流式回答的人工核对；展示行为由 Widget 测试与 Mock 数据路径覆盖。
- 剥离正则只匹配 `[字母开头:数字]` 形态；后端若引入其它标记格式需要同步扩展。
- `DIV-006` 记录的 excerpt 与来源已变化状态缺口保持不变。
