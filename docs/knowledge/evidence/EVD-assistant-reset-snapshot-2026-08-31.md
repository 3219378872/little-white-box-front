---
id: EVD-assistant-reset-snapshot-2026-08-31
layer: evidence
title: Assistant reset 拆出已提交正文 2026-08-31
status: partial
owner: agent
upstream:
  - IMP-flutter-client
covers:
  - FX-090
updated_at: 2026-08-31
observed_commit: 366e287cb9b3ebde1b4aaa9936379dade28cbb6a
---

# Assistant reset 拆出已提交正文 2026-08-31

## 范围与环境

在 Flutter `task/assistant-reset-snapshot` 工作树验证：`response_reset` 清空 run 临时正文前，若该
stream 已有非空正文，则拆成 `run-{id}-{streamId}` 已提交气泡；工具行与来源卡留在 run 气泡；同
stream 重复 reset 不重复拆分。未覆盖真实 `:3002` 手测与后端 `present_sources` 联调。

## 命令与结果

```text
dart format lib/features/assistant/application/assistant_notifier.dart \
  test/features/assistant/application/assistant_notifier_test.dart
# Formatted 2 files (0 changed)

flutter test test/features/assistant/application/assistant_notifier_test.dart
# 11 tests passed

make analyze
# No issues found

flutter test test/features/assistant/
# 88 tests passed

make knowledge-check
# 37 formal docs; 48 requirements; 80 local links; passed
```

## 条款证据

| 条款 | 观察 |
| --- | --- |
| `FX-090` | 匹配 reset 仍清空 run 临时正文并 retire stream；非空正文提升为独立已提交气泡，新 stream 只追加到 run 气泡；来源卡留在 run 气泡；迟到旧 stream token 仍被忽略 |

## 未证明范围

未用浏览器打开 `:3002` 复现「李鸣威」类 present_sources 会话；未证明历史 reload 与 live 气泡在后端
可见落库之后完全同构。因此本证据为 `partial`。
