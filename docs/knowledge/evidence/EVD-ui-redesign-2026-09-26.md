---
id: EVD-ui-redesign-2026-09-26
layer: evidence
title: 前端界面重构验证与改造前后对比
status: active
result: passed
owner: agent
scope:
- static
- unit
- browser
commands:
- make format-check analyze
- flutter test --no-pub --coverage --reporter expanded
- python3 tools/lcov_summary.py coverage/lcov.info --min 70
- make tools-test KNOWLEDGE_PYTHON=/home/dev/projects/little/little-white-box-front/.venv-knowledge/bin/python
- PATH=/tmp/little-quality-tools-nsA9h9/bin:$PATH make sdk-check BACKEND_API=/home/dev/projects/little/little-white-box-content-community/app/gateway/gateway.api
- flutter build web --no-pub --release -t lib/main.dart
- PLAYWRIGHT_MODULE=/home/dev/.local/lib/node_modules/playwright/index.mjs BROWSER_BASE_URL=http://127.0.0.1:43012 BROWSER_OUTPUT_DIR=/tmp/opencode/redesign/after node tools/redesign_compare_capture.mjs
artifacts:
- docs/knowledge/evidence/assets/ui-redesign-2026-09-26/validation-summary.json
- docs/knowledge/evidence/assets/ui-redesign-2026-09-26/desktop-light-feed.jpg
- docs/knowledge/evidence/assets/ui-redesign-2026-09-26/desktop-dark-feed.jpg
- docs/knowledge/evidence/assets/ui-redesign-2026-09-26/desktop-light-post.jpg
- docs/knowledge/evidence/assets/ui-redesign-2026-09-26/mobile-light-feed.jpg
- docs/knowledge/evidence/assets/ui-redesign-2026-09-26/mobile-light-post.jpg
- docs/knowledge/evidence/assets/ui-redesign-2026-09-26/mobile-dark-search.jpg
- docs/knowledge/evidence/assets/ui-redesign-2026-09-26/mobile-light-agent-questions.jpg
observed_commit: 58fa6a24f4c75c58e987331711b4ea49dc4aa34c
updated_at: 2026-10-06
coverage:
- requirements:
  - FX-001
  - FX-002
  - FX-010
  - FX-070
  - FQ-001
  - FQ-002
  - FQ-003
  - FQ-006
  - FQ-008
  paths:
  - lib/app.dart
  - lib/main.dart
  - lib/main_mock.dart
  - lib/core/api
  - lib/core/auth
  - lib/core/router
  - lib/core/state
  - lib/mock
  - lib/sdk
  - vendor/sdk_source
  - tools
  - Makefile
  - pubspec.yaml
  - pubspec.lock
  - analysis_options.yaml
  - android/settings.gradle.kts
  - test
  - lib
  - web
- requirements:
  - FX-020
  - FX-021
  - FX-022
  - FX-030
  - FX-031
  - FX-032
  - FX-060
  - FX-061
  - FX-062
  paths:
  - lib/features/feed
  - lib/features/search
  - lib/features/post
  - lib/features/comment
  - lib/features/profile
  - lib/features/behavior
  - lib
  - test
  - tools
  - vendor/sdk_source
  - Makefile
  - pubspec.yaml
  - pubspec.lock
  - analysis_options.yaml
  - web
  - lib/features/interaction
- requirements:
  - FX-041
  paths:
  - lib/features/message
  - test/features/message
  - lib
  - test
  - tools
  - vendor/sdk_source
  - Makefile
  - pubspec.yaml
  - pubspec.lock
  - analysis_options.yaml
  - web
- requirements:
  - FX-050
  - FX-051
  - FX-091
  - FX-092
  paths:
  - lib/features/assistant
  - test/features/assistant
  - lib
  - test
  - tools
  - vendor/sdk_source
  - Makefile
  - pubspec.yaml
  - pubspec.lock
  - analysis_options.yaml
  - web
- requirements:
  - FQ-004
  paths:
  - lib/core/theme
  - lib/core/widgets
  - lib/core/router/app_router.dart
  - test/helpers/forui_test_builder.dart
  - tools/heybox_visual_check.mjs
  - tools/heybox_android_check.py
  - tools/redesign_compare_capture.mjs
  - lib
  - test
  - tools
  - vendor/sdk_source
  - Makefile
  - pubspec.yaml
  - pubspec.lock
  - analysis_options.yaml
  - web
---

# 前端界面重构验证与改造前后对比

> 2026-10-06：Watch 退役，`FX-082`、`FX-083`、`FX-086` 已从规格删除，本页覆盖组随之移除这些条款；原观察结果不变。

观察提交 `58fa6a2`（基线 `34280c0`），Flutter 3.47.2 / Forui 0.26.0，SDK 对照后端 `09df815` 的
`gateway.api`。实施映射见 [IMP-presentation-client](../implementation/IMP-presentation-client.md)，
社区、Assistant、消息与平台条款回链各自 IMP。未修改后端、SDK、数据契约或规格/设计文档。

## 结果

| 检查 | 结果 |
| --- | --- |
| 格式与静态分析 | `make format-check analyze` 通过，No issues found |
| 自动测试 | 618 passed；覆盖率 8619/10264 行（84.0%），门槛 70% |
| 维护工具 | `make tools-test` 52 passed |
| SDK 漂移 | `make sdk-check` 无差异 |
| Web release | `lib/main.dart` 构建通过 |
| 浏览器对比 | Chromium 151.0.7922.34，改造前后各 7 场景，0 pageerror，无水平溢出 |

新增/调整的回归覆盖：图片 1/2/3+ 几何与单图高度上限、强调色与次要文字对比度（WCAG 相对亮度 >4.5）、
桌面侧栏 <1280 折叠、Feed 列加右栏宽度、详情页 `…` 菜单内的追踪命令、作者关注往返、空评论
“来抢沙发”聚焦、评论排序选中语义与重复点击不重取、搜索键盘提交、最近搜索与清空、高亮解析、
热门标签排序/去重/单帖过滤。数字汇总在 `validation-summary.json`。

## 改造前后对比

改造前由基线 `34280c0` 的 Mock Web 构建截取，改造后由 `58fa6a2` 截取；桌面图纵向叠放保持原分辨率，
移动图左右并排。

| 场景 | 对比图 |
| --- | --- |
| 桌面亮色信息流 | [desktop-light-feed](assets/ui-redesign-2026-09-26/desktop-light-feed.jpg) |
| 桌面暗色信息流 | [desktop-dark-feed](assets/ui-redesign-2026-09-26/desktop-dark-feed.jpg) |
| 桌面详情 | [desktop-light-post](assets/ui-redesign-2026-09-26/desktop-light-post.jpg) |
| 移动信息流 | [mobile-light-feed](assets/ui-redesign-2026-09-26/mobile-light-feed.jpg) |
| 移动详情（0 评论） | [mobile-light-post](assets/ui-redesign-2026-09-26/mobile-light-post.jpg) |
| 移动暗色搜索结果 | [mobile-dark-search](assets/ui-redesign-2026-09-26/mobile-dark-search.jpg) |
| 移动 Agent 澄清题 | [mobile-light-agent-questions](assets/ui-redesign-2026-09-26/mobile-light-agent-questions.jpg) |

## 验证边界

- 截图只证明 Mock 路径下的布局，不证明真实接口；本次未在 `:3002` 联调栈、Android、iOS 或实体设备上验证。
- 热门标签是对已加载推荐流的客户端近似统计（至少 2 帖才展示），不是服务端热度。
- 强调色、卡片圆角 12、图片圆角 8、680 列与热门标签右栏按人类当次选择实施，偏离 FQ-009；
  本页不为 FQ-009 提供 aligned 支撑，偏离登记在 IMP-presentation-client。
- 未做辅助技术实测与专家无障碍评审；语义断言仅限 Widget 测试。
