---
id: EVD-assistant-strict-reset-2026-09-01
layer: evidence
title: Assistant 严格丢弃 reset attempt 正文 2026-09-01
status: partial
owner: agent
upstream:
  - IMP-flutter-client
covers:
  - FX-059
  - FX-090
updated_at: 2026-09-01
observed_commit: 47062ba91e1f07ed6923320389d5877be53e1578
---

# Assistant 严格丢弃 reset attempt 正文 2026-09-01

## 范围与环境

在 Flutter `task/agent-audit-fixes` 工作树验证人类选择的严格 reset 语义：匹配 active stream 的
`response_reset` 清空该 run 临时正文并 retire stream，不把失败 attempt 提升为独立气泡或历史快照；
新 attempt 仍复用同一个 run 气泡，工具步骤和结构化来源卡保留。

## 命令与结果

```text
flutter test test/features/assistant
# 98 tests passed

make analyze
# No issues found

make test
# 398 tests passed

make knowledge-check
# knowledge-check: OK (39 formal documents, 48 requirements, 83 local links)
```

## 条款证据

| 条款 | 观察 |
| --- | --- |
| `FX-059` | repository 继续校验 reset 的非空 `streamId`、SSE seq 与未知事件兼容；reset 不伪造终态 |
| `FX-090` | `token(old)`、`response_reset(old)`、`token(new)`、`done` 后只有一个 `run-{id}` assistant 气泡，正文只含新 stream 获胜答案 |
| `FX-090` | 同 stream 重复 reset 幂等；reset 后迟到旧 token 与 reset 前未获选的其它 stream 均不能恢复失败正文 |
| `FX-090` | reset 只更新正文和 active stream 状态，run 气泡内来源卡、工具步骤及其 callId 状态保持不变 |

## 未证明范围

本页记录 Flutter repository/notifier 与全仓静态/测试门禁；尚未计入三仓合并后的真实 `:3002` Agent
reset fixture、Assistant 黑盒套件或全量 E2E，也未用浏览器/真机直接驱动 Flutter notifier。因此证据
保持 `partial`，根栈结果应在对应提交合并后另行报告。
