---
id: EVD-assistant-stream-reset-2026-08-30
layer: evidence
title: Assistant 流 attempt reset 与重放 2026-08-30
status: partial
owner: agent
upstream:
  - IMP-flutter-client
covers:
  - FX-059
  - FX-090
updated_at: 2026-08-30
observed_commit: 8d4f6dd4da31f10fade15776042641e282531187
---

# Assistant 流 attempt reset 与重放 2026-08-30

## 范围与环境

在 Flutter `task/agent-reliability` 工作树验证 Assistant repository 与 notifier 对多次模型
attempt 的客户端契约：`token(streamId=old)`、`response_reset(old)`、`token(streamId=new)`、
`done`。同时覆盖跨 SSE chunk 的解析、缺失 `streamId` 的 reset 拒绝、reset 后旧流迟到 token
屏蔽、未 reset 的不同 stream 屏蔽，以及旧网关无 streamId token 的兼容路径。

## 命令与结果

```text
dart format lib/features/assistant/data/assistant_models.dart \
  lib/features/assistant/application/assistant_notifier.dart \
  test/features/assistant/data/assistant_repository_test.dart \
  test/features/assistant/application/assistant_notifier_test.dart
# Formatted 4 files

flutter test \
  test/features/assistant/data/assistant_repository_test.dart \
  test/features/assistant/application/assistant_notifier_test.dart \
  test/features/assistant/application/assistant_agent_test.dart
# 35 tests passed

make test
# 337 tests passed; 4 Python tool tests passed

make analyze
# No issues found

make test-coverage
# 337 tests passed; handwritten lines 5797/7430 (78.0%, gate 70%)

make knowledge-check
# 35 formal docs; 47 requirements; 78 local links; passed
```

## 条款证据

| 条款 | 观察 |
| --- | --- |
| `FX-059` | repository 识别 `response_reset`，reset 缺失非空 `streamId` 时将帧视为无效事件；未知 type 仍跳过 |
| `FX-090` | notifier 只追加 active stream；匹配 reset 清空临时正文并 retire 旧 stream；新 stream 首 token 成为 active；旧流迟到 token 与未 reset 的并行 stream 被忽略 |
| `FX-090` | source/tool 等结构状态在 reset 时保留，最终正文只包含获胜 attempt；旧式无 streamId token 在尚未建立新式流时继续工作 |

## 未证明范围

本证据没有启动真实网关、外部 provider、浏览器或真机；因此仍为 `partial`，不证明 nginx/SSE 代理、后端
lease fencing、provider retry/fallback 或生产环境的真实流重放。根仓专用
`just e2e-agent-reset` gate 在三仓整合后再执行。
