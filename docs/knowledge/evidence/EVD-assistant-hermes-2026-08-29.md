---
id: EVD-assistant-hermes-2026-08-29
layer: evidence
title: Hermes Assistant 虚拟线程客户端 2026-08-29
status: partial
owner: agent
upstream:
  - IMP-flutter-client
covers:
  - FX-050
  - FX-051
  - FX-052
  - FX-053
  - FX-054
  - FX-055
  - FX-056
  - FX-057
  - FX-058
  - FX-059
  - FX-080
  - FX-081
  - FX-082
  - FX-083
  - FX-084
  - FX-085
  - FX-086
  - FX-087
  - FX-088
  - FX-089
  - FX-090
  - FX-091
  - FX-092
  - FX-093
updated_at: 2026-08-29
observed_commit: 291097faf360b4bac3a8d7875d7c69d7b863011c
---

# Hermes Assistant 虚拟线程客户端 2026-08-29

## 范围与环境

在 `task/hermes-agent-client` 工作树将客户端切到 Hermes 风格异步 Assistant：消息页固定虚拟
线程、consent、`POST /assistant/messages` disposition、run SSE 续流、MEMORY/USER、Watch 任务
CRUD、来源只信 `source_card`。SDK 由 `tools/sync_gateway_sdk.py` 对后端 task 工作树
`gateway.api` 重新生成。

本轮不包含真实网关联调或真机图片上传。

## 命令与结果

在前端 `task/hermes-agent-client` 工作树实际执行：

```text
make knowledge-check  # OK (32 formal documents, 47 requirements, 73 local links)
make analyze          # No issues found!
make test             # +316: All tests passed!
```

未跑真实网关、浏览器或真机选图。

## 条款证据

| 条款 | 观察 |
| --- | --- |
| `FX-050`/`FX-052` | 路由删除 `_AppDestination.assistant`；`/messages/assistant*` 与旧路径重定向；桌面置顶「小白盒 Agent」 |
| `FX-051`/`FX-084` | 仅 `source_card` 可点击；Markdown 中的 `[post:id]` 不产生来源 |
| `FX-053`/`FX-054`/`FX-080` | 首次发送前 consent；版本偏低只读；`AGENT_NOT_AUTHORIZED` 再授权 |
| `FX-055` | 发送栏保留图片附件入口 |
| `FX-056`/`FX-057` | `tool_call`/`tool_result`/`confirm_required`；`POST .../confirm` |
| `FX-058`/`FX-089`/`FX-091` | 忙碌仍可发送；Stop 才 cancel；disposition 四种取值 |
| `FX-059`/`FX-090` | 未知 type 跳过；`Last-Event-ID`/`afterSeq` 续流 |
| `FX-081`/`FX-085` | MEMORY/USER、容量、undo；无 layer/score/suppressed |
| `FX-082`/`FX-083`/`FX-088`/`FX-093` | Watch 无 hits；未读合并；并行拉取与轮询；thread/read |
| `FX-086` | 帖子盯梢未授权引导 `/messages/assistant` |
| `FX-087` | 推荐来源卡反馈 |
| `FX-092` | 新会话与清历史不删除记忆/Watch |

## 未证明范围

真实网关 SSE 代理、CORS、真机选图上传、生产授权披露文案和 Watch 主动消息时延不在本证据内。
