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

# 三仓 fast-forward 后在根编排仓执行
just e2e-agent-reset
# 1 passed；fixture 截断后的 response_reset、新 streamId、SSE replay 与 provider 恢复通过

just e2e deploy/dev/e2e/test_assistant.py
# 14 passed, 1 skipped

just e2e
# 116 passed, 1 skipped
```

## 条款证据

| 条款 | 观察 |
| --- | --- |
| `FX-059` | repository 识别 `response_reset`，reset 缺失非空 `streamId` 时将帧视为无效事件；未知 type 仍跳过 |
| `FX-090` | notifier 只追加 active stream；匹配 reset 清空临时正文并 retire 旧 stream；新 stream 首 token 成为 active；旧流迟到 token 与未 reset 的并行 stream 被忽略 |
| `FX-090` | source/tool 等结构状态在 reset 时保留，最终正文只包含获胜 attempt；旧式无 streamId token 在尚未建立新式流时继续工作 |

## 未证明范围

根仓确定性 gate 已在合并后的真实 nginx/Gateway/Assistant 栈证明 provider 首流截断后的 retry/reset/replay，
但其消费端是 pytest SSE 客户端，并未用浏览器或真机驱动 Flutter notifier；也未调用外部 live provider、
执行 production profile/迁移或观察生产流量。因此本证据仍为 `partial`。
