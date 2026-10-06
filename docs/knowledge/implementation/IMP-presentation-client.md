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
- lib/core/router/app_routes.dart
- lib/core/shell/main_shell.dart
- lib/core/shell/auth_frame.dart
- test/helpers/forui_test_builder.dart
- tools/heybox_visual_check.mjs
- tools/heybox_android_check.py
- tools/redesign_compare_capture.mjs
updated_at: '2026-10-06'
---

# 客户端展示系统实现映射

共享主题、控件和响应式导航位于 `lib/core`；各 feature presentation 消费同一主题。Heybox 迁移脚本
覆盖 Web 和 Android Mock 路径，但现有截图与报告只保存在 `/tmp`，因此 EVD 为 `active/partial`，不能
单独支撑当前通过结论。没有正式双人类语义评审，也没有实体设备/iOS 或真实服务视觉闭环。

2026-09-26 的 `task/ui-redesign` 按人类当次明确选择实施界面重构：设计 token（间距、圆角、布局宽度）、
品牌强调色（亮 `#2563EB` / 暗 `#60A5FA`）、桌面侧栏 <1280 折叠为 72px、≥1280 的 680 列 + 288 右栏
（发布、Agent 入口、基于已加载推荐流近似统计的热门标签，无新接口）、Feed 图片 1/2/3+ 规则、详情页
操作收敛到 `…` 菜单与作者行关注、搜索最近记录与高亮、Agent 澄清题 chip 化。其中强调色、卡片圆角 12、
图片圆角 8、680 列与热门标签右栏起初偏离 FQ-009；2026-09-27 人类批准修订 FQ-009 并同步 DES 后恢复对齐。
改造前后对比见 [EVD-ui-redesign-2026-09-26](../evidence/EVD-ui-redesign-2026-09-26.md)，修订后全页面验收见
[EVD-fq009-visual-2026-09-27](../evidence/EVD-fq009-visual-2026-09-27.md)。

2026-10-04 修复两处展示问题。其一，直接打开页面时徽标只显示前几个字（如「回扫」只剩「回」）：
`RenderParagraph` 计算固有宽度用的独立 `TextPainter` 不随 `systemFontsDidChange` 失效，`FBadge` 内部的
`IntrinsicWidth` 因而保留中文回退字体加载前的宽度。`lib/core/widgets/app_badge.dart` 的
`SystemFontsRefresh` 在系统字体变化后以新 key 重建子树，全部 `FBadge` 改用 `AppBadge`，Agent 引用按钮的
`IntrinsicWidth` 同样包裹。其二，`FAlert` 标题沿用 `display.sm`，在本主题中为 20 号；`app_theme.dart` 将
提示标题统一降为 `body.sm`。Widget 测试 `remeasures the label after system fonts change` 与
`alert titles use body text size inside cards` 覆盖这两处，浏览器对比见
[EVD-badge-alert-fix-2026-10-04](../evidence/EVD-badge-alert-fix-2026-10-04.md)。

| requirement | design | state | evidence or gap |
| --- | --- | --- | --- |
| FQ-004 | DES-presentation-client | unknown | gap: OpenAPI SDK 与工具链迁移，待新提交上的对应验收证据。 |
| FQ-005 | DES-presentation-client | unknown | gap: current native-platform evidence is temporary and does not cover physical devices or iOS |
| FQ-009 | DES-presentation-client | unknown | gap: OpenAPI SDK 与工具链迁移，待新提交上的对应验收证据。 |
