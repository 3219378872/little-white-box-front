---
id: IMP-topic
layer: implementation
title: 主题实现映射
status: unknown
owner: agent
upstream:
  - DES-topic
tracks:
  - FX-001
code_paths:
  - lib/features/topic
evidence:
  - EVD-topic-YYYY-MM-DD
updated_at: YYYY-MM-DD
---

# 主题实现映射

## 代码入口

## 对齐状态

非 retired IMP 恰好保留一个下列表头，且下一行必须是合法 Markdown 分隔行。每个 `tracks` 条款只在
该表的连续数据行中出现一次；代码块、HTML comment 或表外的示例行没有权威性。

| requirement | design | state | evidence or gap |
| --- | --- | --- | --- |
| FX-001 | DES-topic | unknown | gap: current evidence has not been collected |

## 偏离登记

每项偏离写明条款、当前事实、影响和收敛条件。

`upstream`、`tracks`、`code_paths` 和 `evidence` 的每个列表项必须非空白且不得重复。
