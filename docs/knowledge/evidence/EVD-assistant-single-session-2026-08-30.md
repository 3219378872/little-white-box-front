---
id: EVD-assistant-single-session-2026-08-30
layer: evidence
title: 去掉 Assistant 新会话入口 2026-08-30
status: superseded
result: passed
owner: agent
upstream:
  - IMP-flutter-client
covers:
  - FX-092
  - FX-091
scope:
  - static
  - unit
commands:
  - flutter test test/features/assistant
  - make knowledge-check
observed_commit: 23b53e6bb6821ad29c1a065ef65994fb357e3ef8
updated_at: 2026-08-30
---

# 去掉 Assistant 新会话入口 2026-08-30

## 范围与环境

前端 worktree `task/agent-single-session`。对齐后端永久前台 session：删除 `POST /assistant/sessions`
与页面「新会话」操作。未连真实网关，未做浏览器手工验证。

## 命令与结果

- `flutter test test/features/assistant`
- `make knowledge-check`

退出码 0。页面测试确认存在清除历史、不存在 `assistant-new-session`。

## 条款证据

| 条款 | 观察 |
| --- | --- |
| FX-092 | 无新会话按钮与 repository 方法；清历史仍保留 Memory/Watch |
| FX-091 | Stop 入口保留 |

## 未证明范围

未验证真实网关 30 分钟冷拼接或浏览器端历史列表。

## 历史提交映射

frontmatter 原记录 `ef993c444d2f2cc0c1c54da977e201951412176f`；主线重放后的等价提交为 `23b53e6bb6821ad29c1a065ef65994fb357e3ef8`。
迁移时以 `git range-diff` 核对，差异仅为提交内自引用 SHA/知识说明。
