---
id: IMP-presentation-client
layer: implementation
title: 客户端展示系统实现映射
status: unknown
owner: agent
upstream:
  - DES-presentation-client
tracks:
  - FQ-004
  - FQ-005
  - FQ-009
code_paths:
  - lib/core/theme
  - lib/core/widgets
  - lib/core/router/app_router.dart
  - test/helpers/forui_test_builder.dart
  - tools/heybox_visual_check.mjs
  - tools/heybox_android_check.py
evidence:
  - EVD-knowledge-graph-refactor-2026-09-06
  - EVD-assistant-research-2026-09-05
  - EVD-desktop-nav-semantics-2026-09-05
  - EVD-heybox-presentation-2026-09-06
updated_at: 2026-09-06
---

# 客户端展示系统实现映射

共享主题、控件和响应式导航位于 `lib/core`；各 feature presentation 消费同一主题。Heybox 迁移脚本
覆盖 Web 和 Android Mock 路径，但现有截图与报告只保存在 `/tmp`，因此 EVD 为 `active/partial`，不能
单独支撑当前通过结论。没有正式双人类语义评审，也没有实体设备/iOS 或真实服务视觉闭环。

| requirement | design | state | evidence or gap |
| --- | --- | --- | --- |
| FQ-004 | DES-presentation-client | aligned | EVD-knowledge-graph-refactor-2026-09-06 |
| FQ-005 | DES-presentation-client | unknown | gap: current native-platform evidence is temporary and does not cover physical devices or iOS |
| FQ-009 | DES-presentation-client | unknown | gap: visual artifacts exist only in temporary paths and no durable acceptance bundle or formal human review exists |
