---
id: EVD-badge-alert-fix-2026-10-04
layer: evidence
title: 徽标首屏截断与提示标题字号修复验证
status: active
result: partial
owner: agent
scope:
- static
- unit
- browser
commands:
- make format-check analyze
- make test-coverage KNOWLEDGE_PYTHON=/home/dev/projects/little/little-white-box-front/.venv-knowledge/bin/python
- make knowledge-check KNOWLEDGE_PYTHON=/home/dev/projects/little/little-white-box-front/.venv-knowledge/bin/python
- make build-web
- python3 /home/dev/projects/little/deploy/dev/serve_release.py 3010 build/web
- /tmp/little-media-tools/bin/python /tmp/claude-1000/-home-dev-projects-little/7e83a249-36f6-4c26-86b1-7fe5c2e1dbc6/scratchpad/verify.py /tmp/claude-1000/-home-dev-projects-little/7e83a249-36f6-4c26-86b1-7fe5c2e1dbc6/scratchpad/verify
artifacts:
- docs/knowledge/evidence/assets/badge-alert-fix-2026-10-04/browser-summary.json
- docs/knowledge/evidence/assets/badge-alert-fix-2026-10-04/before-badges-desktop.jpg
- docs/knowledge/evidence/assets/badge-alert-fix-2026-10-04/after-badges-desktop.jpg
- docs/knowledge/evidence/assets/badge-alert-fix-2026-10-04/before-review-task-desktop.jpg
- docs/knowledge/evidence/assets/badge-alert-fix-2026-10-04/after-review-task-desktop.jpg
- docs/knowledge/evidence/assets/badge-alert-fix-2026-10-04/after-review-task-mobile.jpg
- docs/knowledge/evidence/assets/badge-alert-fix-2026-10-04/after-ad-detail-desktop.jpg
observed_commit: eb1eaa6e1ac58401c24a57f4074e1afb8df5f590
updated_at: '2026-10-04'
coverage:
- requirements:
  - FQ-009
  - FQ-010
  paths:
  - lib/core/widgets/app_badge.dart
  - lib/core/theme/app_theme.dart
  - lib/features/review/presentation
  - lib/features/ads/presentation
---

# 徽标首屏截断与提示标题字号修复验证

观察前端提交 `eb1eaa6`；修复前画面来自 `fd6ae91` 的同一 Mock 构建。实现说明见
[IMP-presentation-client](../implementation/IMP-presentation-client.md) 与
[IMP-sponsored-ads-client](../implementation/IMP-sponsored-ads-client.md)。

| 检查 | 结果 |
| --- | --- |
| 格式与静态分析 | 格式不变；分析零问题 |
| 单元与 Widget 测试 | 738 passed，11118/13021 行（85.4%）覆盖率 |
| 知识校验 | 71 个文档、66 条条款通过 |
| 真实浏览器（Mock 构建） | 桌面 1440 首次打开五类审核任务与广告详情、移动 390 回扫任务；徽标完整，提示标题 14 号 |

修复前，在新浏览器上下文直接打开 `/review/tasks/:id` 时，用途徽标只显示前几个字（首次审核→「首次」、
质检→「质」、回扫→「回」），机审证据中的「占位」只显示「占」；把视口改为 1441 或 390 后仍然截断，先进入
工作台首页再跳转则正常。原因是 `RenderParagraph` 计算固有宽度用的独立 `TextPainter` 不随系统字体变化
失效，`FBadge` 的 `IntrinsicWidth` 保留中文回退字体加载前的宽度。修复后五类任务徽标与「占位」均完整。
提示框标题原为 20 号并换行，修复后为 14 号。

浏览器脚本在每个页面新建上下文、等待 8 秒后截图，脚本与原始截图位于会话临时目录，持久摘要与裁剪图
见 artifacts。只覆盖亮色 Mock 下的审核任务页与广告详情页；未覆盖暗色、真实后端、其他使用徽标的页面
（会话列表、记忆、推荐流广告卡片）的浏览器回归，也未运行 Android/iOS 设备，因此结果为 partial，
FQ-009、FQ-010 保持 unknown。
