---
id: EVD-assistant-agent-mode-2026-08-26
layer: evidence
title: Assistant Agent 模式前端闭环 2026-08-26
status: superseded
result: passed
owner: agent
upstream:
  - IMP-flutter-client
covers:
  - FX-052
  - FX-053
  - FX-054
  - FX-055
  - FX-056
  - FX-057
  - FX-058
scope:
  - static
  - unit
commands:
  - make analyze
  - make test
observed_commit: 45e767cec3c4f512c770043bec8029e3403a7564
updated_at: 2026-08-29
---

# Assistant Agent 模式前端闭环 2026-08-26

本证据已被 [EVD-assistant-hermes-2026-08-29](EVD-assistant-hermes-2026-08-29.md) 替代。原条款
描述的 enhanced_search/agent 模式开关与 `/assistant/chat` 同步流已从规格中删除；保留本页仅作
历史观察，不再证明当前 FX-052～058 语义。

## 范围与环境

在 `task/assistant-agent-mode` 工作树实现 Agent 模式客户端：SDK 经
`tools/sync_gateway_sdk.py --api <后端 task 工作树 gateway.api>` 再生成
（AssistantChatReq 增 mode/attachments，事件增 tool_call/confirm_required，
新增 consent 与 tool confirm API）；模式切换、授权披露对话框、附件选择上传、
工具进度行与一次性确认卡片；mock router 覆盖新端点与 agent 模式 SSE 序列。

## 命令与结果

在前端 `task/assistant-agent-mode` 工作树：

```text
make analyze        # No issues found!
make test           # +283: All tests passed!（含 assistant_agent_test 新增用例）
```

关键自动化观察：

- 模式缺省 `enhanced_search`，请求体带 `mode` 字段（repository 测试断言）。
- agent 发送携带 attachments 并在发送后清空 pending（notifier 测试）。
- tool_call/confirm_required 事件构建步骤行；确认回调恰好一次且卡片置为
  已确认/已拒绝；done 后 running 步骤收敛（notifier 测试断言状态序列）。
- AGENT_NOT_AUTHORIZED 错误置授权标记供页面重新触发授权流程。

## 条款证据

| 条款 | 观察 |
| --- | --- |
| FX-052 | 模式控件渲染于输入区上方，切换不清空输入与会话（notifier 状态独立保存）。 |
| FX-053 | 切入 Agent 先查授权（mock GET consent）；未授权弹能力说明对话框，同意才 POST 授权并切模式。 |
| FX-054 | AGENT_NOT_AUTHORIZED 结构化错误触发授权对话框重开（notifier 标记 + 页面 listen）。 |
| FX-055 | 图片经 ImagePicker 选择、10 MiB 校验、复用 uploadImageMultipart 上传，缩略可移除，随消息提交。 |
| FX-056 | TOOL_CALL 渲染进度行（图标+摘要+执行中），CONFIRM_REQUIRED 渲染含摘要的确认卡片。 |
| FX-057 | 确认卡片操作后转不可交互并显示结果；done/error 后等待中的卡片按超时取消呈现。 |
| FX-058 | web 来源以地球图标徽章区别于帖子来源，不作为帖子证据打开；预算错误走既有终止事件呈现。 |

## 待补证据

真实网关联调（consent 往返、agent SSE 全链路、删除确认回环）与真机图片上传，
待根仓联调环境跑通后补充升级为 verified。
