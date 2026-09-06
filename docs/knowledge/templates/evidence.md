---
id: EVD-topic-YYYY-MM-DD
layer: evidence
title: 主题证据 YYYY-MM-DD
status: active
result: partial
owner: agent
upstream:
  - IMP-topic
covers:
  - FX-001
scope:
  - unit
commands:
  - make test
observed_commit: 0000000000000000000000000000000000000000
updated_at: YYYY-MM-DD
---

# 主题证据

## 范围与环境

记录日期、提交、工具版本和工作树状态。

## 命令与结果

只记录实际执行的命令、退出码和关键结果。`upstream`、`covers`、`scope`、`commands` 以及存在时的
`external_upstream`，每个列表项必须非空白且不得重复。

## 条款证据

把 `covers` 条款映射到代码、测试、日志或人工观察。

## 未证明范围

明确本证据不能推出的结论。

active passed 证据的 `observed_commit` 必须是完整祖先提交；该提交之后任一上游 IMP `code_paths` 下的
已提交、未暂存、已暂存或未跟踪变更都会使证据失效。只修改 IMP/EVD 知识页不会使代码证据失效。
