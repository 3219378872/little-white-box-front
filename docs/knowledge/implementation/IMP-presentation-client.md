---
id: IMP-presentation-client
layer: implementation
title: 客户端展示系统实现映射
status: active
owner: agent
code_paths:
- lib/core/theme
- lib/core/widgets
- lib/core/router/app_router.dart
- test/helpers/forui_test_builder.dart
- tools/heybox_visual_check.mjs
- tools/heybox_android_check.py
- tools/redesign_compare_capture.mjs
updated_at: 2026-09-26
---

# 客户端展示系统实现映射

共享主题、控件和响应式导航位于 `lib/core`；各 feature presentation 消费同一主题。Heybox 迁移脚本
覆盖 Web 和 Android Mock 路径，但现有截图与报告只保存在 `/tmp`，因此 EVD 为 `active/partial`，不能
单独支撑当前通过结论。没有正式双人类语义评审，也没有实体设备/iOS 或真实服务视觉闭环。

2026-09-26 的 `task/ui-redesign` 按人类当次明确选择实施界面重构：设计 token（间距、圆角、布局宽度）、
品牌强调色（亮 `#2563EB` / 暗 `#60A5FA`）、桌面侧栏 <1280 折叠为 72px、≥1280 的 680 列 + 288 右栏
（发布、Agent 入口、基于已加载推荐流近似统计的热门标签，无新接口）、Feed 图片 1/2/3+ 规则、详情页
操作收敛到 `…` 菜单与作者行关注、搜索最近记录与高亮、Agent 澄清题 chip 化。其中强调色、卡片圆角 12、
图片圆角 8、680 列与热门标签右栏偏离 FQ-009 的 Heybox 黑白灰、圆角 4/≤8、单列 720 与“不新增热点”约束；
规格与设计未改，偏离只在下表登记；验证与改造前后对比见
[EVD-ui-redesign-2026-09-26](../evidence/EVD-ui-redesign-2026-09-26.md)。

| requirement | design | state | evidence or gap |
| --- | --- | --- | --- |
| FQ-004 | DES-presentation-client | aligned | EVD-ui-redesign-2026-09-26 |
| FQ-005 | DES-presentation-client | unknown | gap: current native-platform evidence is temporary and does not cover physical devices or iOS |
| FQ-009 | DES-presentation-client | diverged | gap: 2026-09-26 ui-redesign keeps a blue accent, card radius 12, image radius 8, a 680px feed column and a client-side trending-tags rail, contrary to the Heybox monochrome, radius 4/<=8, 720px single column and no-hotspot rules; needs a human decision to amend FQ-009/DES or revert |
